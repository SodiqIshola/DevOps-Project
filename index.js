// Start application using nodemon: npm run dev

const express = require('express');
const client = require('prom-client'); // Library to "speak" Prometheus
const taskController = require('./taskController');
const app = express();
const logger = require('./logger');  // Import your custom logger
logger.info('Server running on http://localhost:3000');


// Middleware to let the app read JSON data sent in a request body
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



// --- BLOCK 1: TASK EVENT LOGGING (Keep this for app.log) ---
// This section watches every request and logs "PUT", "POST", and "DELETE" actions
app.use((req, res, next) => {
  const { method, url, body } = req;

  // Only run this if someone is creating, updating, or deleting data
  if (['POST', 'PUT', 'DELETE'].includes(method)) {
    // 1. Log detailed info (Who, What, When) to our app.log file
    logger.info(`Task Event: ${method} on ${url}`, {
      eventType: 'CRUD_OPERATION',
      method: method,
      endpoint: url,
      payload: body, // This shows the data being added or changed
    });

  }
  next(); // Move on to the actual API routes below
});






// --- PROMETHEUS SETUP & CUSTOM METRICS ---
// --- PROMETHEUS SETUP & CUSTOM METRICS ---

// Create a Registry to store all our metrics in one place
const register = new client.Registry();

// Enable default metrics like CPU and Memory tracking
client.collectDefaultMetrics({ register });

// GAUGE: Tracks the current count of tasks (goes up and down)
const taskGauge = new client.Gauge({
  name: 'current_tasks_total',
  help: 'The total number of tasks currently in the system',
});
register.registerMetric(taskGauge);

// COUNTER 1: Tracks EVERY request hitting the server (General Traffic)
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests received',
  labelNames: ['method', 'route', 'status'] // Matches your middleware payload
});
register.registerMetric(httpRequestCounter);

// COUNTER 2: Tracks ONLY data-modifying actions (PUT/DELETE/POST)
const taskOperationCounter = new client.Counter({
  name: 'task_operations_total',
  help: 'Total number of Create, Update, and Delete actions',
  labelNames: ['method', 'route', 'status'] // Now includes 'status' for better Grafana charts
});
register.registerMetric(taskOperationCounter);


// THE SCRAPE ENDPOINT: This is where Prometheus "reads" your data
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics()); // Use await because register.metrics() is a promise
});




// --- COMBINED MONITORING & EVENT LOGGING ---
app.use((req, res, next) => {
  const { method, url, body } = req;

  // GAUGE: Update the live task count immediately
  const taskCount = taskController?.tasks?.length;
  if (taskCount !== undefined) {
    taskGauge.set(taskCount);
  }

  // ATTACH DATA: Save the payload (body) to the "res" object 
  // This "carries" the data forward so we can use it in the 'finish' event later
  res.locals.payload = body;

  // FINISH LISTENER: This waits for the server to finish the task
  res.on('finish', () => {
    
    // Create one "Final Package" of information
    const finalReport = {
      method: method,
      route: req.route?.path ?? url,
      status: res.statusCode, // 200 (Success) or 500 (Error)
      dataSent: res.locals.payload // The information they Put, Updated, or Deleted
    };

    // UPDATE PROMETHEUS: Add +1 to the general history
    httpRequestCounter.inc({ 
      method: finalReport.method, 
      route: finalReport.route, 
      status: finalReport.status 
    });

    // UPDATE TASK COUNTER: Add +1 ONLY for data changes (PUT, DELETE, POST)
    if (['POST', 'PUT', 'DELETE'].includes(method)) {
      taskOperationCounter.inc({ 
        method: finalReport.method, 
        route: finalReport.route, 
        status: finalReport.status 
      });
    }

    // SINGLE SUMMARY LOG: This writes one perfect line to your app.log file
    logger.info(`TASK COMPLETED: ${method} on ${url}`, {
      ...finalReport, // Includes method, route, status, and the data (payload)
      timestamp: new Date().toISOString() // Adds the exact time
    });
  });

  next(); // Move to the routes
});


const port = 3000;
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
  console.log(`Metrics available at http://localhost:${port}/metrics`);
});
