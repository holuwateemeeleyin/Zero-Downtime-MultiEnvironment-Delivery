const request = require("supertest");
const app = require("./server");

describe("Backend Service", () => {
    it("GET /health returns ok", async () => {
        const res = await request(app).get("/health");
        expect(res.statusCode).toBe(200);
        expect(res.body.status).toBe("ok");
        expect(res.body.service).toBe("backend");
    });

    it("GET /version returns version info", async () => {
        const res = await request(app).get("/version");
        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty("version");
        expect(res.body).toHaveProperty("env");
    });

    it("GET /ready returns ready", async () => {
        const res = await request(app).get("/ready");
        expect(res.statusCode).toBe(200);
        expect(res.body.ready).toBe(true);
    });

    it("GET /api/products returns product list", async () => {
        const res = await request(app).get("/api/products");
        expect(res.statusCode).toBe(200);
        expect(Array.isArray(res.body.products)).toBe(true);
        expect(res.body.products.length).toBeGreaterThan(0);
    });

    it("POST /api/orders returns 201 with orderId", async () => {
        const res = await request(app)
            .post("/api/orders")
            .send({ productId: 1, quantity: 2 })
            .set("Content-Type", "application/json");
        expect(res.statusCode).toBe(201);
        expect(res.body).toHaveProperty("orderId");
        expect(res.body.productId).toBe(1);
    });

    it("POST /api/orders returns 400 on missing fields", async () => {
        const res = await request(app)
            .post("/api/orders")
            .send({})
            .set("Content-Type", "application/json");
        expect(res.statusCode).toBe(400);
    });

    it("GET /metrics returns prometheus format", async () => {
        const res = await request(app).get("/metrics");
        expect(res.statusCode).toBe(200);
        expect(res.text).toContain("http_requests_total");
    });

    it("GET /api/error-test returns ok when INJECT_ERRORS not set", async () => {
        const res = await request(app).get("/api/error-test");
        expect(res.statusCode).toBe(200);
    });

    it("GET /unknown-route returns 404", async () => {
        const res = await request(app).get("/this-does-not-exist");
        expect(res.statusCode).toBe(404);
    });
});
