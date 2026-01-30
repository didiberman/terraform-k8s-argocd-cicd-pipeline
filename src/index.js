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

  // Handle Root Endpoint
  httpRequestCounter.inc({ method: req.method, status: 200 });
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Hello from Hetzner K3s! Version: 1.0.0\n');
});

const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
