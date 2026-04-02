// tracer.js - OpenTelemetry Setup for Traces + Log Correlation

// ============================================================================
// IMPORTS
// ============================================================================

// Standard semantic attribute keys (recommended instead of hardcoding strings)
const {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
} = require('@opentelemetry/semantic-conventions');

// Resource API changed → use this instead of `new Resource()`
const { resourceFromAttributes } = require('@opentelemetry/resources');

// Pull version from package.json (single source of truth)
const { version } = require('./package.json');

// Core SDK (manages tracing lifecycle)
const { NodeSDK } = require('@opentelemetry/sdk-node');

// OTLP exporter (sends traces → OTel Collector → Tempo)
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

// Auto-instrumentation (Express, HTTP, etc.)
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

// Winston integration → injects trace_id into logs
const { WinstonInstrumentation } = require('@opentelemetry/instrumentation-winston');

// Performance + batching
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');

// Sampling strategy (controls how many traces are collected)
const { AlwaysOnSampler } = require('@opentelemetry/sdk-trace-base');


// ============================================================================
// ENVIRONMENT CONFIG
// ============================================================================

const ENV = process.env.NODE_ENV || 'development';

// Use Kubernetes service name OR fallback for local dev
const OTEL_ENDPOINT =
  process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
  'http://otel-collector:4318/v1/traces'; // change to host.docker.internal for local Docker


// ============================================================================
// RESOURCE (IDENTITY OF YOUR SERVICE)
// ============================================================================
// This is CRITICAL — this is how your service appears in:
// - Grafana
// - Tempo
// - Service Map

const resource = resourceFromAttributes({
  [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'node-task-app',
  [ATTR_SERVICE_VERSION]: version || '1.0.0',

  // VERY IMPORTANT → used for filtering in dashboards
  'deployment.environment': ENV,
});


// ============================================================================
// EXPORTER (SEND DATA TO COLLECTOR)
// ============================================================================

const traceExporter = new OTLPTraceExporter({
  url: OTEL_ENDPOINT,

  // Optional: timeout to avoid hanging requests
  timeoutMillis: 10000,
});


// ============================================================================
// SPAN PROCESSING (PERFORMANCE CONTROL)
// ============================================================================
// Instead of sending every span immediately,
// we batch them → fewer network calls → better performance

const spanProcessor = new BatchSpanProcessor(traceExporter, {
  maxQueueSize: 2048,          // Max spans waiting to be sent
  maxExportBatchSize: 512,     // Spans per batch
  scheduledDelayMillis: 5000,  // Send every 5s
  exportTimeoutMillis: 30000,  // Timeout per export
});


// ============================================================================
// SAMPLING STRATEGY
// ============================================================================
// DEV → capture EVERYTHING
// PROD → reduce noise + cost

const sampler =
  ENV === 'production'
    ? undefined // let collector decide OR use TraceIdRatioBasedSampler
    : new AlwaysOnSampler();


// ============================================================================
// AUTO-INSTRUMENTATION
// ============================================================================

const instrumentations = [
  getNodeAutoInstrumentations({
    // Disable noisy modules
    '@opentelemetry/instrumentation-fs': {
      enabled: false,
    },
  }),

  // Attach trace_id to Winston logs
  new WinstonInstrumentation({
    enabled: true,

    // This key will appear in your logs
    logField: 'trace_id',
  }),
];


// ============================================================================
// SDK INITIALIZATION
// ============================================================================

const sdk = new NodeSDK({
  resource,
  sampler,
  spanProcessor,
  instrumentations,
});


// ============================================================================
// START TRACING
// ============================================================================

sdk.start();

console.log(`OpenTelemetry started (${ENV})`);
console.log(`Exporting traces to: ${OTEL_ENDPOINT}`);


// ============================================================================
// CLEAN SHUTDOWN (VERY IMPORTANT FOR K8s)
// ============================================================================
// Ensures traces are flushed before pod/container stops

process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down tracing...');

  sdk.shutdown()
    .then(() => console.log('Tracing terminated successfully'))
    .catch((error) => console.error('Error terminating tracing', error))
    .finally(() => process.exit(0));
});


// ============================================================================
// EXPORT SDK (optional)
// ============================================================================

module.exports = sdk;