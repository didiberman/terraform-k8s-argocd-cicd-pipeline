const http = require('http');
const client = require('prom-client');

// Create a Registry which registers the metrics
const register = new client.Registry();

// Add a default label which is added to all metrics
client.collectDefaultMetrics({ register });

// Create a custom counter metric
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'status'],
});
register.registerMetric(httpRequestCounter);

const server = http.createServer(async (req, res) => {
  // Handle Metrics Endpoint
  if (req.url === '/metrics') {
    res.setHeader('Content-Type', register.contentType);
    res.end(await register.metrics());
    return;
  }

  const nodeName = process.env.NODE_NAME || 'Unknown';

  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="2">
    <title>K3s Cluster Status</title>
    <style>
        :root {
            --bg-color: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.7);
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --accent-color: #38bdf8;
            --accent-glow: rgba(56, 189, 248, 0.3);
        }
        body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background-color: var(--bg-color);
            background-image: 
                radial-gradient(circle at 10% 20%, rgba(56, 189, 248, 0.1) 0%, transparent 40%),
                radial-gradient(circle at 90% 80%, rgba(139, 92, 246, 0.1) 0%, transparent 40%);
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            color: var(--text-primary);
        }
        .container {
            text-align: center;
            padding: 4rem;
            background: var(--card-bg);
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 24px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            max-width: 600px;
            width: 90%;
            transition: all 0.3s ease;
        }
        h1 {
            font-size: 1.5rem;
            font-weight: 500;
            color: var(--text-secondary);
            margin-bottom: 2rem;
            letter-spacing: 0.05em;
            text-transform: uppercase;
        }
        .node-name {
            font-size: 4rem;
            font-weight: 800;
            margin: 0;
            background: linear-gradient(135deg, #fff 0%, var(--accent-color) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            text-shadow: 0 0 30px var(--accent-glow);
            animation: pulse 2s infinite;
        }
        .meta {
            margin-top: 3rem;
            display: flex;
            justify-content: center;
            gap: 1.5rem;
            font-size: 0.875rem;
            color: var(--text-secondary);
        }
        .badge {
            background: rgba(255, 255, 255, 0.05);
            padding: 0.5rem 1rem;
            border-radius: 9999px;
            border: 1px solid rgba(255, 255, 255, 0.05);
        }
        @keyframes pulse {
            0% { transform: scale(1); opacity: 1; }
            50% { transform: scale(1.02); opacity: 0.9; }
            100% { transform: scale(1); opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Request Served By</h1>
        <div class="node-name">${nodeName}</div>
        <div class="meta">
            <span class="badge">V1.0.0</span>
            <span class="badge">Hetzner Cloud</span>
            <span class="badge">K3s</span>
        </div>
    </div>
</body>
</html>
`;
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(html);
});

const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
