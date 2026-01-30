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
            --card-bg: rgba(30, 41, 59, 0.7);
            --text-primary: #f8fafc;
            --text-secondary: #e2e8f0;
            --accent-color: #fbbf24; /* Pineapple Yellow */
            --accent-glow: rgba(251, 191, 36, 0.5);
            --success-color: #4ade80;
        }
        body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(-45deg, #2e1065, #4c1d95, #7c3aed, #c026d3);
            background-size: 400% 400%;
            animation: gradientBG 15s ease infinite;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            color: var(--text-primary);
            overflow: hidden; /* Prevent scrollbars from falling emojis */
        }
        @keyframes gradientBG {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
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
            z-index: 10;
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
        .pineapple {
            position: fixed;
            top: -50px;
            font-size: 2rem;
            z-index: 1;
            pointer-events: none;
            animation: fall linear forwards;
        }
        @keyframes fall {
            to { transform: translateY(110vh) rotate(360deg); }
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
                Traffic flows directly to the <span class="pill">Traefik Ingress</span>, which routes requests to a <strong>DaemonSet</strong> ensuring 1 pod runs on every worker node.
                <br><br>
                <strong>The Pipeline:</strong>
                New Release Created ➔ GitHub Actions (CI) ➔ Build & Push Image ➔ ArgoCD Syncs Cluster
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

        // Falling Pineapples Logic
        function createPineapple() {
            const pineapple = document.createElement('div');
            pineapple.classList.add('pineapple');
            pineapple.innerText = '❤️';

            pineapple.style.left = Math.random() * 100 + 'vw';

            // Random fall duration between 3s and 8s
            const fallDuration = Math.random() * 5 + 3;
            pineapple.style.animationDuration = fallDuration + 's';

            // Random font size
            const size = Math.random() * 1.5 + 1;
            pineapple.style.fontSize = size + 'rem';

            document.body.appendChild(pineapple);

            // Cleanup after animation
            setTimeout(() => {
                pineapple.remove();
            }, fallDuration * 1000);
        }

        // Spawn a pineapple every 800ms (not too many)
        setInterval(createPineapple, 800);

        // Initial batch
        for(let i=0; i<5; i++) setTimeout(createPineapple, i * 400);
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
