
require('./tracer');


// =============================================================================
// LOAD ENVIRONMENT CONFIGURATION
// =============================================================================
const env = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${env}` });


// =============================================================================
// IMPORT CORE MODULES
// =============================================================================
const express = require('express');
const taskController = require('./taskController');
const logger = require('./logger');
const monitoring = require('./monitoring');

// OpenTelemetry API (for trace_id extraction)
const { context, trace } = require('@opentelemetry/api');

// App version (single source of truth)
const { version } = require('./package.json');


// =============================================================================
// INITIALIZE EXPRESS APP
// =============================================================================
const app = express();


// =============================================================================
// MIDDLEWARE SETUP
// =============================================================================

// Automatically parse JSON request bodies
app.use(express.json());

// Log startup (structured logging)
logger.info('App initialization started', {
  env,
  version,
});


// =============================================================================
// BUSINESS API ROUTES
// =============================================================================

// --- TASK ROUTES ---
app.get('/tasks', taskController.getTasks);
app.post('/tasks', taskController.addTask);
app.delete('/tasks/:id', taskController.deleteTask);
app.put('/tasks/:id', taskController.updateTask);

// --- NAME ROUTES ---
app.get('/names', taskController.getNames);
app.post('/names', taskController.addName);
app.delete('/names/:id', taskController.deleteName);
app.put('/names/:id', taskController.updateName);


// =============================================================================
// ROOT UI (Simple Navigation Page)
// =============================================================================
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


// =============================================================================
// UNIFIED OBSERVABILITY MIDDLEWARE (CORE LOGIC)
// -----------------------------------------------------------------------------
// This middleware synchronizes:
// - Logs (Winston → Loki)
// - Metrics (Prometheus)
// - Traces (Tempo)
// =============================================================================
app.use((req, res, next) => {

  const { method, url, body } = req;

  // Start timing request
  const start = Date.now();

  // Update live gauge (business metric)
  const currentCount = taskController?.tasks?.length || 0;
  monitoring.taskGauge.set(currentCount);

  // Run AFTER response is sent
  res.on('finish', () => {

    const duration = Date.now() - start;
    const route = req.route?.path ?? url;
    const status = res.statusCode;

    // =============================================================================
    // TRACE CORRELATION (REAL TRACE ID)
    // -----------------------------------------------------------------------------
    // This pulls the active span created by OpenTelemetry
    // This is how logs connect to traces in Grafana Tempo
    // =============================================================================
    const span = trace.getSpan(context.active());
    const traceId = span ? span.spanContext().traceId : 'no-trace';


    // =============================================================================
    // PROMETHEUS METRICS
    // =============================================================================
    monitoring.httpRequestCounter.inc({
      method,
      route,
      status,
    });


    // =============================================================================
    // SMART LOG LEVELING
    // =============================================================================
    let logLevel = 'info';
    if (status >= 500) logLevel = 'error';
    else if (status >= 400) logLevel = 'warn';

    // =============================================================================
    // STRUCTURED LOGGING (LOKI)
    // =============================================================================
    logger.log(logLevel, `HTTP ${method} ${url} - ${status}`, {
      eventType: 'API_REQUEST',
      method,
      route,
      status,
      duration_ms: duration,
      trace_id: traceId,
      payload: ['POST', 'PUT'].includes(method) ? body : undefined,
    });

    // =============================================================================
    // BUSINESS METRICS (ONLY FOR DATA CHANGES)
    // =============================================================================
    if (['POST', 'PUT', 'DELETE'].includes(method)) {
      monitoring.taskOperationCounter.inc({
        method,
        route,
        status,
      });
    }

    // =============================================================================
    // CLOUDWATCH SYNC (OPTIONAL)
    // =============================================================================
    monitoring.updateCloudWatch(method, route, status, currentCount);
  });

  next();
});


// =============================================================================
// PROMETHEUS METRICS ENDPOINT
// -----------------------------------------------------------------------------
app.get('/metrics', async (req, res) => {
  try {
    res.setTimeout(5000);
    res.setHeader('Content-Type', monitoring.register.contentType);
    res.send(await monitoring.register.metrics());
  } catch (err) {
    res.status(500).send(err.message);
  }
});


// =============================================================================
// HEALTH CHECK (LIVENESS)
// -----------------------------------------------------------------------------
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    env,
    version,
  });
});

// =============================================================================
// READINESS CHECK
// -----------------------------------------------------------------------------
app.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ready',
    env,
    version,
  });
});


// =============================================================================
// SERVER STARTUP
// =============================================================================
const port = process.env.PORT || 3000;

const server = app.listen(port, () => {
  console.log(`Server running in ${env} mode on http://localhost:${port}`);
  console.log(`Metrics available at http://localhost:${port}/metrics`);

  logger.info('Server started successfully', {
    env,
    port,
    version,
  });
});


// =============================================================================
// HANDLE PORT CONFLICTS
// =============================================================================
server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    logger.error(`Port ${port} is already in use`);
    process.exit(1);
  }
});


// =============================================================================
// GRACEFUL SHUTDOWN (KUBERNETES SAFE)
// -----------------------------------------------------------------------------
const shutdown = (signal) => {
  logger.info(`${signal} received: shutting down`);

  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });

  // Force shutdown if hanging
  setTimeout(() => {
    logger.error('Force shutdown after timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));



