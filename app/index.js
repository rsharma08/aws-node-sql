const { withDatabase } = require("./db");

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store"
    },
    body: JSON.stringify(body)
  };
}

exports.handler = async (event) => {
  const method = event?.requestContext?.http?.method;
  const route = event?.rawPath;

  if (method === "GET" && route === "/health") {
    return response(200, { status: "ok" });
  }

  if (method === "GET" && route === "/health/db") {
    try {
      await withDatabase(async (pool) => {
        const result = await pool.request().query(
          "SELECT 1 AS healthy"
        );

        if (result.recordset[0]?.healthy !== 1) {
          throw new Error("Unexpected database response");
        }
      });

      return response(200, { status: "ok", database: "ok" });
    } catch {
      console.error("Database health check failed", {
        requestId: event?.requestContext?.requestId
      });

      return response(503, {
        status: "unavailable"
      });
    }
  }

  return response(404, { message: "Not found" });
};