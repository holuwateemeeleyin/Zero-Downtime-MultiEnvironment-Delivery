import { useState, useEffect } from "react";

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || "http://localhost:8080";
const ML_URL = import.meta.env.VITE_ML_URL || "http://localhost:5000";

function StatusBadge({ status }) {
    const color = status === "ok" ? "#22c55e" : "#ef4444";
    return (
        <span style={{
            display: "inline-block", padding: "2px 10px", borderRadius: "12px",
            background: color, color: "#fff", fontWeight: 700, fontSize: "0.8rem"
        }}>
            {status || "unknown"}
        </span>
    );
}

export default function App() {
    const [backendHealth, setBackendHealth] = useState(null);
    const [mlHealth, setMlHealth] = useState(null);
    const [version, setVersion] = useState(null);
    const [products, setProducts] = useState([]);
    const [recommendations, setRecommendations] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        const fetchData = async () => {
            try {
                const [bHealth, mHealth, ver, prods, recs] = await Promise.allSettled([
                    fetch(`${BACKEND_URL}/health`).then(r => r.json()),
                    fetch(`${ML_URL}/health`).then(r => r.json()),
                    fetch(`${BACKEND_URL}/version`).then(r => r.json()),
                    fetch(`${BACKEND_URL}/api/products`).then(r => r.json()),
                    fetch(`${ML_URL}/api/recommendations?user_id=demo`).then(r => r.json()),
                ]);
                if (bHealth.status === "fulfilled") setBackendHealth(bHealth.value);
                if (mHealth.status === "fulfilled") setMlHealth(mHealth.value);
                if (ver.status === "fulfilled") setVersion(ver.value);
                if (prods.status === "fulfilled") setProducts(prods.value.products || []);
                if (recs.status === "fulfilled") setRecommendations(recs.value.recommendations || []);
            } catch (e) {
                setError(e.message);
            } finally {
                setLoading(false);
            }
        };
        fetchData();
        const interval = setInterval(fetchData, 30000);
        return () => clearInterval(interval);
    }, []);

    return (
        <div style={{ fontFamily: "'Inter', sans-serif", background: "#0f172a", minHeight: "100vh", color: "#e2e8f0", padding: "2rem" }}>
            <header style={{ marginBottom: "2rem", borderBottom: "1px solid #1e293b", paddingBottom: "1rem" }}>
                <h1 style={{ fontSize: "2rem", fontWeight: 800, background: "linear-gradient(135deg, #6366f1, #22d3ee)", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>
                    🛍️ ShopMicro Platform
                </h1>
                <p style={{ color: "#94a3b8", marginTop: "0.25rem" }}>
                    Zero-Downtime Multi-Environment Delivery — Extra Credit
                </p>
                {version && (
                    <div style={{ marginTop: "0.5rem", fontSize: "0.85rem", color: "#64748b" }}>
                        Version: <strong style={{ color: "#a5b4fc" }}>{version.version}</strong>
                        &nbsp;| Env: <strong style={{ color: "#67e8f9" }}>{version.env}</strong>
                        &nbsp;| Build: <code style={{ color: "#94a3b8" }}>{version.build}</code>
                    </div>
                )}
            </header>

            {loading && <p style={{ color: "#94a3b8" }}>Loading platform status...</p>}
            {error && <p style={{ color: "#f87171" }}>⚠️ Error: {error}</p>}

            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))", gap: "1.5rem", marginBottom: "2rem" }}>
                {/* Backend Health */}
                <div style={{ background: "#1e293b", borderRadius: "12px", padding: "1.5rem", border: "1px solid #334155" }}>
                    <h2 style={{ fontSize: "1rem", color: "#94a3b8", marginBottom: "0.75rem" }}>Backend Service</h2>
                    {backendHealth ? (
                        <>
                            <div style={{ marginBottom: "0.5rem" }}><StatusBadge status={backendHealth.status} /></div>
                            <div style={{ fontSize: "0.85rem", color: "#64748b" }}>Uptime: {backendHealth.uptime}s</div>
                        </>
                    ) : <span style={{ color: "#475569" }}>Connecting...</span>}
                </div>

                {/* ML Service Health */}
                <div style={{ background: "#1e293b", borderRadius: "12px", padding: "1.5rem", border: "1px solid #334155" }}>
                    <h2 style={{ fontSize: "1rem", color: "#94a3b8", marginBottom: "0.75rem" }}>ML Service</h2>
                    {mlHealth ? (
                        <>
                            <div style={{ marginBottom: "0.5rem" }}><StatusBadge status={mlHealth.status} /></div>
                            <div style={{ fontSize: "0.85rem", color: "#64748b" }}>Uptime: {mlHealth.uptime}s | Model: {mlHealth.version}</div>
                        </>
                    ) : <span style={{ color: "#475569" }}>Connecting...</span>}
                </div>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "1.5rem" }}>
                {/* Products */}
                <div style={{ background: "#1e293b", borderRadius: "12px", padding: "1.5rem", border: "1px solid #334155" }}>
                    <h2 style={{ fontSize: "1.1rem", color: "#c7d2fe", marginBottom: "1rem" }}>📦 Products</h2>
                    {products.length === 0 ? (
                        <p style={{ color: "#475569" }}>No products loaded</p>
                    ) : (
                        <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
                            {products.map(p => (
                                <li key={p.id} style={{ display: "flex", justifyContent: "space-between", padding: "0.6rem 0", borderBottom: "1px solid #334155" }}>
                                    <span style={{ color: "#e2e8f0" }}>{p.name}</span>
                                    <span style={{ color: "#22d3ee", fontWeight: 700 }}>${p.price.toFixed(2)}</span>
                                </li>
                            ))}
                        </ul>
                    )}
                </div>

                {/* Recommendations */}
                <div style={{ background: "#1e293b", borderRadius: "12px", padding: "1.5rem", border: "1px solid #334155" }}>
                    <h2 style={{ fontSize: "1.1rem", color: "#c7d2fe", marginBottom: "1rem" }}>🤖 ML Recommendations</h2>
                    {recommendations.length === 0 ? (
                        <p style={{ color: "#475569" }}>No recommendations loaded</p>
                    ) : (
                        <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
                            {recommendations.map(r => (
                                <li key={r.id} style={{ display: "flex", justifyContent: "space-between", padding: "0.6rem 0", borderBottom: "1px solid #334155" }}>
                                    <span style={{ color: "#e2e8f0" }}>{r.name}</span>
                                    <span style={{ color: "#a78bfa", fontWeight: 700 }}>Score: {r.score}</span>
                                </li>
                            ))}
                        </ul>
                    )}
                </div>
            </div>

            <footer style={{ marginTop: "3rem", color: "#475569", fontSize: "0.8rem", textAlign: "center" }}>
                ShopMicro Platform • Zero-Downtime Multi-Environment Delivery • Feb 2026
            </footer>
        </div>
    );
}
