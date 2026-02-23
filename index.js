// Start application using nodemon: npm run dev

const express = require('express');
const client = require('prom-client');
const app = express();
const taskController = require('./taskController');


const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom HTTP request counter
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

register.registerMetric(httpRequestCounter);

// Middleware to track requests
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestCounter.inc({
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status: res.statusCode,
    });
  });
  next();
});

app.use(express.json());

// Application Routes
app.get('/tasks', taskController.getTasks);
app.post('/tasks', taskController.addTask);

app.get('/names', taskController.getNames);
app.post('/names', taskController.addName);



// Health Endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});


// Metrics Endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});



// Server Startup
const port = 3000;
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});