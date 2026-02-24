const express = require("express");
const app = express();
const port = process.env.PORT || 8080;

app.use(express.json());

// Metrics counters
let requestCount = 0;
let errorCount = 0;
const startTime = Date.now();

// Middleware: track requests
app.use((req, res, next) => {
  requestCount++;
  res.on("finish", () => {
    if (res.statusCode >= 500) errorCount++;
  });
  next();
});

// Health endpoint
app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    service: "backend",
    uptime: Math.floor((Date.now() - startTime) / 1000),
    timestamp: new Date().toISOString(),
  });
});

// Version endpoint
app.get("/version", (_req, res) => {
  res.json({
    version: process.env.APP_VERSION || "v1",
    env: process.env.NODE_ENV || "development",
    build: process.env.BUILD_SHA || "local",
  });
});

// Ready probe
app.get("/ready", (_req, res) => {
  res.json({ ready: true });
});

// Metrics endpoint (Prometheus text format)
app.get("/metrics", (_req, res) => {
  const uptimeSeconds = Math.floor((Date.now() - startTime) / 1000);
  const errorRate = requestCount > 0 ? (errorCount / requestCount) : 0;
  res.set("Content-Type", "text/plain");
  res.send(
    `# HELP http_requests_total Total HTTP requests\n` +
    `# TYPE http_requests_total counter\n` +
    `http_requests_total{service="backend",version="${process.env.APP_VERSION || "v1"}"} ${requestCount}\n` +
    `# HELP http_errors_total Total HTTP 5xx errors\n` +
    `# TYPE http_errors_total counter\n` +
    `http_errors_total{service="backend"} ${errorCount}\n` +
    `# HELP error_rate Current error rate\n` +
    `# TYPE error_rate gauge\n` +
    `error_rate{service="backend"} ${errorRate.toFixed(4)}\n` +
    `# HELP process_uptime_seconds Process uptime\n` +
    `# TYPE process_uptime_seconds gauge\n` +
    `process_uptime_seconds{service="backend"} ${uptimeSeconds}\n`
  );
});

// Products API
app.get("/api/products", (_req, res) => {
  res.json({
    products: [
      { id: 1, name: "Widget A", price: 9.99, stock: 100 },
      { id: 2, name: "Widget B", price: 19.99, stock: 50 },
      { id: 3, name: "Widget C", price: 4.99, stock: 200 },
    ],
    version: process.env.APP_VERSION || "v1",
  });
});

// Orders API
app.post("/api/orders", (req, res) => {
  const { productId, quantity } = req.body;
  if (!productId || !quantity) {
    return res.status(400).json({ error: "productId and quantity are required" });
  }
  res.status(201).json({
    orderId: `ord-${Date.now()}`,
    productId,
    quantity,
    status: "pending",
    version: process.env.APP_VERSION || "v1",
  });
});

// Error simulation for chaos testing
app.get("/api/error-test", (_req, res) => {
  if (process.env.INJECT_ERRORS === "true") {
    return res.status(500).json({ error: "Injected error for chaos testing" });
  }
  res.json({ ok: true });
});

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: "Not found" });
});

// Error handler
app.use((err, _req, res, _next) => {
  errorCount++;
  console.error(err.stack);
  res.status(500).json({ error: "Internal server error" });
});

app.listen(port, () => {
  console.log(`[backend] listening on port ${port}, version=${process.env.APP_VERSION || "v1"}`);
});

module.exports = app;
