const fs = require("node:fs");
const path = require("node:path");
const sql = require("mssql");
const {
  SecretsManagerClient,
  GetSecretValueCommand
} = require("@aws-sdk/client-secrets-manager");

const secrets = new SecretsManagerClient({});
const ca = fs.readFileSync(
  path.join(__dirname, "..", "certs", "global-bundle.pem")
);

async function withDatabase(callback) {
  const { DB_HOST, DB_SECRET_ARN } = process.env;
  const port = Number(process.env.DB_PORT || "1433");

  if (!DB_HOST || !DB_SECRET_ARN) {
    throw new Error("Database configuration is missing");
  }

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("Database port is invalid");
  }

  const response = await secrets.send(
    new GetSecretValueCommand({
      SecretId: DB_SECRET_ARN
    })
  );

  if (!response.SecretString) {
    throw new Error("Expected a JSON string secret");
  }

  const credentials = JSON.parse(response.SecretString);

  for (const field of ["username", "password", "database"]) {
    if (
      typeof credentials[field] !== "string" ||
      credentials[field].length === 0
    ) {
      throw new Error("Application secret is incomplete");
    }
  }

  const pool = new sql.ConnectionPool({
    server: DB_HOST,
    port,
    user: credentials.username,
    password: credentials.password,
    database: credentials.database,

    connectionTimeout: 3000,
    requestTimeout: 3000,

    pool: {
      max: 2,
      min: 0,
      idleTimeoutMillis: 30000
    },

    options: {
      encrypt: true,
      trustServerCertificate: false,
      cryptoCredentialsDetails: {
        ca
      }
    }
  });

  // Handle background pool errors without logging credentials.
  pool.on("error", () => {
    console.error("Database connection pool error");
  });

  try {
    await pool.connect();
    return await callback(pool);
  } finally {
    await pool.close();
  }
}

module.exports = { withDatabase, sql };