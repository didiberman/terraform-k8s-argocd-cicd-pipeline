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
    <title>K3s Cluster Status</title>
    <style>
        :root {
            --bg-color: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.7);
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --accent-color: #38bdf8;
            --accent-glow: rgba(56, 189, 248, 0.3);
            --success-color: #4ade80;
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
            padding: 3rem;
            background: var(--card-bg);
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 24px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            max-width: 600px;
            width: 90%;
            position: relative;
            overflow: hidden;
        }
        h1 {
            font-size: 1.25rem;
            font-weight: 500;
            color: var(--text-secondary);
            margin-bottom: 1.5rem;
            letter-spacing: 0.05em;
            text-transform: uppercase;
        }
        .node-name {
            font-size: 3.5rem;
            font-weight: 800;
            margin: 0;
            background: linear-gradient(135deg, #fff 0%, var(--accent-color) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            text-shadow: 0 0 30px var(--accent-glow);
            margin-bottom: 2rem;
        }
        .progress-container {
            width: 100%;
            height: 4px;
            background: rgba(255, 255, 255, 0.1);
            position: absolute;
            bottom: 0;
            left: 0;
        }
        .progress-bar {
            height: 100%;
            background: var(--accent-color);
            width: 0%;
            transition: width 0.1s linear;
        }
        .info-box {
            margin-top: 2rem;
            padding: 1.5rem;
            background: rgba(0, 0, 0, 0.2);
            border-radius: 12px;
            text-align: left;
            border: 1px solid rgba(255, 255, 255, 0.05);
        }
        .info-title {
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: var(--success-color);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        .info-content {
            font-size: 0.875rem;
            line-height: 1.6;
            color: var(--text-secondary);
        }
        .refresh-text {
            margin-top: 1rem;
            font-size: 0.75rem;
            color: var(--text-secondary);
            opacity: 0.7;
        }
        .pill {
            display: inline-block;
            padding: 0.25rem 0.5rem;
            background: rgba(255,255,255,0.1);
            border-radius: 4px;
            margin: 0 2px;
            color: var(--text-primary);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Request Served By</h1>
        <div class="node-name">${nodeName}</div>
        
        <div class="info-box">
            <div class="info-title">⚡️ Behind the Scenes</div>
            <div class="info-content">
                Traffic flows from <span class="pill">Cloudflare</span> to the <span class="pill">Traefik Ingress</span>, which load-balances requests across 3 worker nodes.
                <br><br>
                <strong>The Pipeline:</strong>
                Code Push ➔ GitHub Actions (CI) ➔ GHCR ➔ ArgoCD (CD) ➔ K3s Cluster
            </div>
        </div>

        <div class="refresh-text">Refreshing in <span id="timer">2.0</span>s</div>
        <div class="progress-container">
            <div class="progress-bar" id="progressBar"></div>
        </div>
    </div>

    <script>
        const duration = 2000; // 2 seconds
        const interval = 50; // Update every 50ms
        let elapsed = 0;
        
        const progressBar = document.getElementById('progressBar');
        const timerText = document.getElementById('timer');
        
        const timer = setInterval(() => {
            elapsed += interval;
            const progress = (elapsed / duration) * 100;
            const remaining = Math.max(0, (duration - elapsed) / 1000).toFixed(1);
            
            progressBar.style.width = \`\${progress}%\`;
            timerText.textContent = remaining;
            
            if (elapsed >= duration) {
                clearInterval(timer);
                window.location.reload();
            }
        }, interval);
    </script>
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
