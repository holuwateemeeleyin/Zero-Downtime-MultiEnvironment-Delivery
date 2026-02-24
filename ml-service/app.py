"""
ShopMicro ML Service
Provides product recommendations and demand forecasting.
"""
import os
import time
import json
import random
from flask import Flask, jsonify, request

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "v1")
START_TIME = time.time()
request_count = 0
error_count = 0


@app.before_request
def count_requests():
    global request_count
    request_count += 1


@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "service": "ml-service",
        "version": APP_VERSION,
        "uptime": int(time.time() - START_TIME),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })


@app.get("/ready")
def ready():
    return jsonify({"ready": True})


@app.get("/version")
def version():
    return jsonify({
        "version": APP_VERSION,
        "env": os.environ.get("ENVIRONMENT", "development"),
        "build": os.environ.get("BUILD_SHA", "local"),
    })


@app.get("/metrics")
def metrics():
    uptime = int(time.time() - START_TIME)
    error_rate = (error_count / request_count) if request_count > 0 else 0.0
    metrics_text = (
        f'# HELP http_requests_total Total HTTP requests\n'
        f'# TYPE http_requests_total counter\n'
        f'http_requests_total{{service="ml-service",version="{APP_VERSION}"}} {request_count}\n'
        f'# HELP http_errors_total Total HTTP 5xx errors\n'
        f'# TYPE http_errors_total counter\n'
        f'http_errors_total{{service="ml-service"}} {error_count}\n'
        f'# HELP error_rate Current error rate\n'
        f'# TYPE error_rate gauge\n'
        f'error_rate{{service="ml-service"}} {error_rate:.4f}\n'
        f'# HELP process_uptime_seconds Process uptime\n'
        f'# TYPE process_uptime_seconds gauge\n'
        f'process_uptime_seconds{{service="ml-service"}} {uptime}\n'
    )
    return metrics_text, 200, {"Content-Type": "text/plain"}


@app.get("/api/recommendations")
def recommendations():
    """Product recommendations based on user history."""
    user_id = request.args.get("user_id", "anonymous")
    # Simulated ML recommendations
    products = [
        {"id": 1, "name": "Widget A", "score": round(random.uniform(0.7, 0.99), 3)},
        {"id": 3, "name": "Widget C", "score": round(random.uniform(0.5, 0.89), 3)},
        {"id": 2, "name": "Widget B", "score": round(random.uniform(0.3, 0.69), 3)},
    ]
    return jsonify({
        "user_id": user_id,
        "recommendations": sorted(products, key=lambda x: x["score"], reverse=True),
        "model_version": APP_VERSION,
    })


@app.get("/api/demand-forecast")
def demand_forecast():
    """Demand forecasting for inventory planning."""
    product_id = request.args.get("product_id", "1")
    forecast = {
        "product_id": product_id,
        "forecast": [
            {"day": i + 1, "units": random.randint(10, 100)} for i in range(7)
        ],
        "confidence": round(random.uniform(0.80, 0.99), 3),
        "model_version": APP_VERSION,
    }
    return jsonify(forecast)


@app.get("/api/error-test")
def error_test():
    """Error injection endpoint for chaos testing."""
    global error_count
    if os.environ.get("INJECT_ERRORS") == "true":
        error_count += 1
        return jsonify({"error": "Injected error for chaos testing"}), 500
    return jsonify({"ok": True})


@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(500)
def internal_error(e):
    global error_count
    error_count += 1
    return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"[ml-service] starting on port {port}, version={APP_VERSION}")
    app.run(host="0.0.0.0", port=port)
