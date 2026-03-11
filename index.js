
// --- IMPORT LIBRARIES & CONFIGURATION ---

// =========================================================================
// 1. CRITICAL: LOAD TRACING FIRST!
// This must be the VERY FIRST line of code in your app. 
// It "plugs into" Node.js so it can automatically add a unique Trace ID 
// to every web request and every log message before anything else starts.
// =========================================================================
require('./tracer'); 

// Import Express to create our web server
const express = require('express');
// Import our Task Controller (where the actual array/data logic lives)
const taskController = require('./taskController');
// Import our custom Winston logger (configured for Console, File, and OTel/CloudWatch)
const logger = require('./logger');  
// Import our centralized monitoring object (Prometheus & CloudWatch Tools)
const monitoring = require('./monitoring'); 

// Initialize the Express application
const app = express();


// --- INITIAL SETUP & MIDDLEWARE ---

// Middleware to automatically parse JSON data sent in request bodies
app.use(express.json()); 

// Log a message to the console and file as soon as the file starts
logger.info('Initializing Node Task App services...');


// --- TASK API ROUTES ---

// GET /tasks: Show all tasks
app.get('/tasks', taskController.getTasks);
// POST /tasks: Create a new task
app.post('/tasks', taskController.addTask);
// DELETE /tasks/:id: Remove a specific task
app.delete('/tasks/:id', taskController.deleteTask);
// PUT /tasks/:id: Update an existing task
app.put('/tasks/:id', taskController.updateTask);


// --- NAME API ROUTES ---

// GET /names: List all name objects
app.get('/names', taskController.getNames);
// POST /names: Add a new name
app.post('/names', taskController.addName);
// DELETE /names/:id: Remove a name
app.delete('/names/:id', taskController.deleteName);
// PUT /names/:id: Update a name
app.put('/names/:id', taskController.updateName);


// Root route providing a simple UI/Navigation
app.get('/', (req, res) => {
  res.send(`
    <div style="font-family: sans-serif; max-width: 600px; margin: 40px auto; padding: 20px; border: 1px solid #eee; border-radius: 8px;">
      <h1 style="color: #2c3e50;">Task API Monitoring</h1>
      
      <h2 style="color: #34495e; border-bottom: 2px solid #3498db; padding-bottom: 5px;">Business Endpoints</h2>
      <ul style="list-style: none; padding: 0;">
        <li style="margin-bottom: 10px;"><a href="/tasks" style="text-decoration: none; color: #3498db; font-weight: bold;">View Tasks →</a></li>
        <li style="margin-bottom: 10px;"><a href="/names" style="text-decoration: none; color: #3498db; font-weight: bold;">View Names →</a></li>
      </ul>

      <h2 style="color: #34495e; border-bottom: 2px solid #e67e22; padding-bottom: 5px; margin-top: 30px;">Observability</h2>
      <div style="margin-top: 15px;">
        <a href="/metrics" style="display: inline-block; padding: 8px 15px; background-color: #f39c12; color: white; text-decoration: none; border-radius: 4px; font-size: 14px;">
          View Raw Metrics (Prometheus)
        </a>
      </div>
    </div>
  `);
});




// --- UNIFIED OBSERVABILITY MIDDLEWARE ---
// This is the "Brain" of our monitoring. It ensures that our Logs (Winston), 
// local Metrics (Prometheus), and Cloud Metrics (CloudWatch) are perfectly 
// synchronized so they always report the same data at the same time.
app.use((req, res, next) => {
  // Capture the incoming HTTP Method, URL, and the data sent by the user
  const { method, url, body } = req;
  
  // PERFORMANCE TRACKING: Start a timer to measure how long the request takes
  const start = Date.now();

  // UPDATE LIVE GAUGE (PROMETHEUS)
  // Get the current count of items to reflect real-time state in Prometheus
  const currentCount = taskController?.tasks?.length || 0;
  monitoring.taskGauge.set(currentCount);

  // SETUP THE 'FINISH' LISTENER
  // This triggers AFTER the response is sent, giving us access to the Status Code
  res.on('finish', () => {
    // Calculate the duration of the request in milliseconds
    const duration = Date.now() - start;
    // Get the specific route matched (e.g., /tasks/:id) and the final HTTP status
    const route = req.route?.path ?? url;
    const status = res.statusCode;

    // UPDATE PROMETHEUS TRAFFIC COUNTERS
    // Increment counters with labels so we can filter by Method or Status in Grafana
    monitoring.httpRequestCounter.inc({ method, route, status });

    // DYNAMIC LOG LEVELING
    // Automatically set level to 'error' for 500s, 'warn' for 400s, or 'info' for successes
    let logLevel = 'info';
    if (status >= 500) logLevel = 'error';
    else if (status >= 400) logLevel = 'warn';

    // STRUCTURED LOGGING (LOKI/WINSTON)
    // We log ALL requests now, but use the 'level' to distinguish them for your Pie Chart
    logger.log(logLevel, `HTTP ${method} ${url} - ${status}`, {
      eventType: 'API_REQUEST',
      method: method,
      status: status,
      route: route,
      duration_ms: duration, // Used for the "Avg Request Duration" Gauge in your dashboard
      payload: ['POST', 'PUT'].includes(method) ? body : undefined, // Log body only for data changes
      // Trace ID Hook: Connects these logs to Tempo traces if available
      trace_id: req.headers['x-trace-id'] || 'no-trace'
    });

    // HANDLE DATA-MODIFYING ACTIONS (PROMETHEUS ONLY)
    if (['POST', 'PUT', 'DELETE'].includes(method)) {
      monitoring.taskOperationCounter.inc({ method, route, status });
    }

    // PUSH TO CLOUDWATCH METRICS (AWS EMF)
    // Synchronize your local metrics with AWS CloudWatch for cloud-native monitoring
    monitoring.updateCloudWatch(method, route, status, currentCount);
  });

  // Proceed to the next middleware or route handler
  next();
});



// --- THE PROMETHEUS SCRAPE ENDPOINT ---
// This is the URL Prometheus visits to "pull" all your metrics
app.get('/metrics', async (req, res) => {
  try {
    // Set the official Prometheus text format header
    res.setHeader('Content-Type', monitoring.register.contentType);
    // Convert all current registry data into the Prometheus string format
    res.send(await monitoring.register.metrics());
  } catch (err) {
    // If the registry fails, return a server error
    res.status(500).send(err.message);
  }
});




// ---  SERVER STARTUP ---
const port = 3000;
app.listen(port, () => {
  // Use both console.log for local dev and logger.info for CloudWatch/Logs
  console.log(`Server running on http://localhost:${port}`);
  console.log(`Metrics available at http://localhost:${port}/metrics`);
  logger.info(`Server started successfully on port ${port}`, { env: process.env.NODE_ENV });
});
