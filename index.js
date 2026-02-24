// Start application using nodemon: npm run dev

const express = require('express');
const client = require('prom-client'); // Library to "speak" Prometheus
const taskController = require('./taskController');
const app = express();
const logger = require('./logger');  // Import your custom logger
logger.info('Server running on http://localhost:3000');

app.use(express.json());

// --- TASK API ROUTES ---

// Listens for a GET request to /tasks and runs the getTasks function to show all data
app.get('/tasks', taskController.getTasks);
// Listens for a POST request to /tasks and runs addTask to save a new object from the body
app.post('/tasks', taskController.addTask);
// Listens for a DELETE request with an ID (e.g., /tasks/1) to remove that specific task
app.delete('/tasks/:id', taskController.deleteTask);
// Listens for a PUT request with an ID to find a task and update its title
app.put('/tasks/:id', taskController.updateTask);


// --- NAME API ROUTES ---

// Listens for a GET request to /names to return the list of all name objects
app.get('/names', taskController.getNames);
// Listens for a POST request to /names to create and save a new name entry
app.post('/names', taskController.addName);
// Listens for a DELETE request with an ID (e.g., /names/2) to remove that name from the list
app.delete('/names/:id', taskController.deleteName);
// Listens for a PUT request with an ID to find a name object and change its text
app.put('/names/:id', taskController.updateName);

// Root route with helpful links
app.get('/', (req, res) => {
  res.send(`
    <h1>Task API with Monitoring</h1>
    <ul>
      <li><a href="/tasks">View Tasks</a></li>
      <li><a href="/names">View Names (/names)</a></li>
      <li><a href="/metrics">View Raw Metrics (Prometheus Format)</a></li>
    </ul>
  `);
});



// --- PROMETHEUS SETUP ---

// Create a Registry to store our metrics
const register = new client.Registry();

// Enable default metrics (CPU, Memory, etc.) to be tracked automatically
client.collectDefaultMetrics({ register });

// Define a GAUGE to track the current number of tasks
// A Gauge is perfect here because the count goes UP (add) and DOWN (delete)
const taskGauge = new client.Gauge({
  name: 'current_tasks_total',
  help: 'The total number of tasks currently in the system',
});
register.registerMetric(taskGauge);

// Define a COUNTER to track how many total requests hit our API
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests received',
  // FIX: Change 'label_names' to 'labelNames'
  labelNames: ['method', 'route', 'status'] 
});

register.registerMetric(httpRequestCounter);





// This runs on every single request
// -- MONITORING MIDDLEWARE: Updates Prometheus metrics for every request --
// -- MONITORING MIDDLEWARE: Modern Optional Chaining Version --
app.use((req, res, next) => {
  // OPTIONAL CHAINING: Safely access .length even if taskController or .tasks is null/undefined
  const taskCount = taskController?.tasks?.length;

  if (taskCount !== undefined) {
    // Updates the Prometheus Gauge with the current count
    taskGauge.set(taskCount);
  }

  // EVENT LISTENER: Triggers after the response is sent to the client
  res.on('finish', () => {
    // INCREMENT COUNTER: Logs the specific request metrics
    httpRequestCounter.inc({ 
      method: req.method, 
      // OPTIONAL CHAINING: Safely access route path or default to raw path
      route: req.route?.path ?? req.path, 
      status: res.statusCode 
    });

    // MODULAR LOGGER: Send structured logs to Loki via your Winston service
    logger.info('HTTP Request processed', { 
      method: req.method, 
      path: req.path, 
      status: res.statusCode 
    });
  });
  
  // Proceed to the next middleware or route handler
  next();
});





// --- THE SCRAPE ENDPOINT ---

// Prometheus will "scrape" this route every 15 seconds
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics());
});

const port = 3000;
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
  console.log(`Metrics available at http://localhost:${port}/metrics`);
});
