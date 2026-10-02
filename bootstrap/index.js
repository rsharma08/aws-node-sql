const fs = require("node:fs");
const path = require("node:path");
const { randomBytes } = require("node:crypto");
const sql = require("mssql");

const {
  SecretsManagerClient,
  GetSecretValueCommand,
  PutSecretValueCommand
} = require("@aws-sdk/client-secrets-manager");

const secrets = new SecretsManagerClient({});

async function getApplicationCredentials() {
  const secretArn = process.env.APP_SECRET_ARN;

  if (!secretArn) {
    throw new Error("Application secret ARN is missing");
  }

  let response;

  try {
    response = await secrets.send(
      new GetSecretValueCommand({
        SecretId: secretArn
      })
    );
  } catch (error) {
    if (error.name !== "ResourceNotFoundException") {
      throw error;
    }
  }

  if (response) {
    if (!response.SecretString) {
      throw new Error("Expected an application JSON string secret");
    }

    const credentials = JSON.parse(response.SecretString);

    if (
      credentials.username !== "api_user" ||
      credentials.database !== "application_db" ||
      typeof credentials.password !== "string" ||
      credentials.password.length === 0 ||
      credentials.password.length > 128
    ) {
      throw new Error("Application secret is invalid");
    }

    return credentials;
  }

  const credentials = {
    username: "api_user",
    password: `Aa1!${randomBytes(32).toString("hex")}`,
    database: "application_db"
  };

  // Save credentials before SQL changes so a retry reuses the password.
  // The secret container must already exist.
  await secrets.send(
    new PutSecretValueCommand({
      SecretId: secretArn,
      SecretString: JSON.stringify(credentials)
    })
  );

  return credentials;
}

exports.handler = async () => {
  const {
    DB_HOST,
    ADMIN_SECRET_ARN,
    APP_SECRET_ARN
  } = process.env;

  if (!DB_HOST || !ADMIN_SECRET_ARN || !APP_SECRET_ARN) {
    throw new Error("Bootstrap configuration is missing");
  }

  if (ADMIN_SECRET_ARN === APP_SECRET_ARN) {
    throw new Error("Administrator and application secrets must differ");
  }

  const response = await secrets.send(
    new GetSecretValueCommand({
      SecretId: ADMIN_SECRET_ARN
    })
  );

  if (!response.SecretString) {
    throw new Error("Administrator secret is missing");
  }

  const credentials = JSON.parse(response.SecretString);

  if (
    typeof credentials.username !== "string" ||
    typeof credentials.password !== "string" ||
    !credentials.username ||
    !credentials.password
  ) {
    throw new Error("Administrator secret is incomplete");
  }

  const pool = new sql.ConnectionPool({
    server: DB_HOST,
    port: 1433,
    user: credentials.username,
    password: credentials.password,
    database: "master",

    connectionTimeout: 10000,
    requestTimeout: 30000,

    pool: {
      max: 1,
      min: 0
    },

    options: {
      encrypt: true,
      trustServerCertificate: false,
      cryptoCredentialsDetails: {
        ca: fs.readFileSync(
          path.join(__dirname, "certs", "global-bundle.pem")
        )
      }
    }
  });

  pool.on("error", () => {
    console.error("Bootstrap database connection error");
  });

  try {
    await pool.connect();

    const appCredentials = await getApplicationCredentials();

    await pool.request().batch(`
      IF DB_ID(N'application_db') IS NULL
      BEGIN
        EXEC(N'CREATE DATABASE [application_db]');
      END;
    `);

    await pool.request()
      .input(
        "appPassword",
        sql.NVarChar(128),
        appCredentials.password
      )
      .batch(`
        DECLARE @statement nvarchar(max);

        IF SUSER_ID(N'api_user') IS NULL
        BEGIN
          SET @statement =
            N'CREATE LOGIN [api_user] WITH PASSWORD = ' +
            QUOTENAME(@appPassword, '''') +
            N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
        END
        ELSE
        BEGIN
          SET @statement =
            N'ALTER LOGIN [api_user] WITH PASSWORD = ' +
            QUOTENAME(@appPassword, '''') +
            N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
        END;

        EXEC sys.sp_executesql @statement;

        USE [application_db];

        IF USER_ID(N'api_user') IS NULL
          CREATE USER [api_user] FOR LOGIN [api_user];
        ELSE
          ALTER USER [api_user] WITH LOGIN = [api_user];

        GRANT CONNECT TO [api_user];
      `);

    return {
      status: "ok",
      database: "application_db",
      username: "api_user"
    };
  } catch {
    // Never log credentials or SQL statements containing passwords.
    console.error("Database bootstrap failed");
    throw new Error("Database bootstrap failed");
  } finally {
    await pool.close();
  }
};