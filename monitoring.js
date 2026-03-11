
// 1. IMPORT LIBRARIES
// Import prom-client to handle Prometheus metrics (Pull model)
const client = require('prom-client');
// Import AWS EMF library to handle CloudWatch metrics (Push model)
const { createMetricsLogger, Unit } = require('aws-embedded-metrics');


// --- SECTION 1: PROMETHEUS SETUP (PROM-CLIENT) ---

// Create a new Registry (the "central database" for all your Prometheus metrics)
const register = new client.Registry();

// Start collecting default Node.js metrics (CPU, Memory) and save them to our registry
client.collectDefaultMetrics({ register });

// Define a GAUGE: A value that can go up or down (like a gas gauge)
const taskGauge = new client.Gauge({
  name: 'current_tasks_total',
  help: 'Total tasks currently stored in the system memory',
});

// Define a COUNTER: A value that only goes up (tracks total volume of traffic)
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests received by the server',
  labelNames: ['method', 'route', 'status']
});

// Define another COUNTER: Specifically for tracking "Write" operations (POST, PUT, DELETE)
const taskOperationCounter = new client.Counter({
  name: 'task_operations_total',
  help: 'Total number of data-modifying actions performed',
  labelNames: ['method', 'route', 'status']
});

// Manually link our custom metrics to the Registry so they show up on the /metrics page
register.registerMetric(taskGauge);
register.registerMetric(httpRequestCounter);
register.registerMetric(taskOperationCounter);



// --- SECTION 2: CLOUDWATCH SETUP (AWS EMF) ---

/**
 * This function is the "Bridge" to AWS. 
 * Integrated with try/catch to prevent ECONNREFUSED crashes locally.
 */
const updateCloudWatch = async (method, route, status, taskCount) => {
  try {
    // Create a new logger specifically for AWS Metrics
    const cw = createMetricsLogger();
    
    // Set the "Folder Name" in the CloudWatch console where these metrics will appear
    cw.setNamespace('NodeTaskApp/Metrics');
    
    // Create "Dimensions"
    cw.putDimensions({ Method: method, Route: route, Status: status.toString() });
    
    // Push Metrics
    // Push a single request count (Value: 1)
    cw.putMetric('HttpRequestCount', 1, Unit.Count);
    // Push the current live task count (Value: whatever the current array length is)
    cw.putMetric('CurrentTaskCount', taskCount, Unit.Count);


    // If the action changed data, push an extra metric for "DataModifyingOperations"
    if (['POST', 'PUT', 'DELETE'].includes(method)) {
      cw.putMetric('DataModifyingOperations', 1, Unit.Count);
    }
    
    // Finalize and "Flush" (send) the data
    // Locally, this will fail if no agent is running, but the catch block will handle it.
    await cw.flush();
    
  } catch (err) {
    // If the Collector isn't ready or the network is down, this catches it
    console.error("Monitoring: Failed to send EMF metrics to OTel Collector.", err.message);
    console.info("Tip: Set AWS_EMF_ENVIRONMENT=Local to see these metrics in the console instead.");
  }
};

// --- SECTION 3: THE EXPORT ---

// This object is what 'require' returns. 
// When you do: const monitoring = require('./monitoring'), 
// 'monitoring' becomes this exact object.
module.exports = {
  register,               // Exporting the Prometheus Registry
  taskGauge,              // Exporting the Gauge tool
  httpRequestCounter,     // Exporting the Traffic counter
  taskOperationCounter,   // Exporting the Data change counter
  updateCloudWatch        // Exporting the AWS push function
};


