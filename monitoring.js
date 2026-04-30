
// Prometheus metrics library
const client = require('prom-client');
// AWS CloudWatch EMF library
const { createMetricsLogger, Unit } = require('aws-embedded-metrics');


// Prometheus Setup
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const taskGauge = new client.Gauge({
  name: 'current_tasks_total',
  help: 'Total tasks currently stored in the system memory',
});

const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests received by the server',
  labelNames: ['method', 'route', 'status']
});

const taskOperationCounter = new client.Counter({
  name: 'task_operations_total',
  help: 'Total number of data-modifying actions performed',
  labelNames: ['method', 'route', 'status']
});

register.registerMetric(taskGauge);
register.registerMetric(httpRequestCounter);
register.registerMetric(taskOperationCounter);


// CloudWatch Setup
const updateCloudWatch = async (method, route, status, taskCount) => {
  try {
    const cw = createMetricsLogger();
    cw.setNamespace('NodeTaskApp/Metrics');
    cw.putDimensions({ Method: method, Route: route, Status: status.toString() });
    cw.putMetric('HttpRequestCount', 1, Unit.Count);
    cw.putMetric('CurrentTaskCount', taskCount, Unit.Count);

    if (['POST', 'PUT', 'DELETE'].includes(method)) {
      cw.putMetric('DataModifyingOperations', 1, Unit.Count);
    }
    
    await cw.flush();
    
  } catch (err) {
    console.error("Monitoring: Failed to send EMF metrics to OTel Collector.", err.message);
    console.info("Set AWS_EMF_ENVIRONMENT=Local to see these metrics in the console instead.");
  }
};


// Export metrics and functions
module.exports = {
  register,               
  taskGauge,              
  httpRequestCounter,     
  taskOperationCounter,   
  updateCloudWatch        
};


