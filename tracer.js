// tracer.js - The "Brain" of your Observability Stack

// Load the OpenTelemetry Node.js SDK to manage the tracing lifecycle
const { NodeSDK } = require('@opentelemetry/sdk-node');

// Import "Auto-Instrumentations" to track Express, HTTP, and DB calls automatically
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

// Import the OTLP HTTP Exporter to ship traces to your 'otel-collector' container
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

// Import the Winston bridge to "glue" your logs and traces together
const { WinstonInstrumentation } = require('@opentelemetry/instrumentation-winston');

// Initialize the SDK Configuration
const sdk = new NodeSDK({
  
  // Define the Network Destination for Traces:
  // Sends data to the 'otel-collector' container on port 4318 (OTLP over HTTP)
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4318/v1/traces', 
  }),

  // Define the "Hooks" (Instrumentations):
  instrumentations: [
    // Hook #1: Automatically watch Express and HTTP activity for spans
    getNodeAutoInstrumentations(), 
    
    // Hook #2: CRITICAL - This automatically injects 'trace_id' and 'span_id' 
    // into every Winston log object so your Loki dashboard can link them.
    new WinstonInstrumentation({
      enabled: true,
      logField: 'trace_id', // Tells Winston to use 'trace_id' as the key
    })   
  ],
});

// Start the SDK Background Process
// In CommonJS, we trigger this immediately to begin intercepting calls.
sdk.start();

console.log("OTel Tracing & Winston Log Injection started.");

// Graceful Shutdown Handler
// Ensures all pending traces are flushed to the collector before the container stops.
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('Tracing successfully terminated'))
    .catch((error) => console.log('Error terminating tracing', error))
    .finally(() => process.exit(0));
});

module.exports = sdk;
