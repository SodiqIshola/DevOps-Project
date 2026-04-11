
// tracer.js - OpenTelemetry Setup for Traces + Log Correlation

// ============================================================================
// IMPORTS
// ============================================================================

// Added for explicit status setting
const { SpanStatusCode } = require('@opentelemetry/api');

const {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
} = require('@opentelemetry/semantic-conventions');

const { resourceFromAttributes } = require('@opentelemetry/resources');
const { version } = require('./package.json');
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { WinstonInstrumentation } = require('@opentelemetry/instrumentation-winston');
const { BatchSpanProcessor, AlwaysOnSampler } = require('@opentelemetry/sdk-trace-base');

// ============================================================================
// ENVIRONMENT CONFIG
// ============================================================================

const ENV = process.env.NODE_ENV || 'development';

const OTEL_ENDPOINT =
  process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
  'http://otel-collector:4318/v1/traces';

// ============================================================================
// RESOURCE (IDENTITY OF YOUR SERVICE)
// ============================================================================

const resource = resourceFromAttributes({
  [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'node-task-app',
  [ATTR_SERVICE_VERSION]: version || '1.0.0',
  'deployment.environment': ENV,
});

// ============================================================================
// EXPORTER & PROCESSING
// ============================================================================

const traceExporter = new OTLPTraceExporter({
  url: OTEL_ENDPOINT,
  timeoutMillis: 10000,
});

const spanProcessor = new BatchSpanProcessor(traceExporter, {
  maxQueueSize: 2048,
  maxExportBatchSize: 512,
  scheduledDelayMillis: 5000,
  exportTimeoutMillis: 30000,
});

const sampler =
  ENV === 'production'
    ? undefined 
    : new AlwaysOnSampler();

// ============================================================================
// AUTO-INSTRUMENTATION (Updated with Response Hooks)
// ============================================================================

const instrumentations = [
  getNodeAutoInstrumentations({
    // Disable noisy modules
    '@opentelemetry/instrumentation-fs': {
      enabled: false,
    },
    // Map HTTP status codes to OTel StatusCodes
    '@opentelemetry/instrumentation-http': {
      responseHook: (span, response) => {
        const statusCode = response.statusCode;

        if (statusCode >= 400) {
          // Explicitly set ERROR for 4xx and 5xx errors
          span.setStatus({
            code: SpanStatusCode.ERROR,
            message: `HTTP Error: ${statusCode}`,
          });
        } else {
          // Explicitly set OK for 1xx, 2xx, 3xx (Removes "Unset")
          span.setStatus({ code: SpanStatusCode.OK });
        }
      },
    },
  }),

  new WinstonInstrumentation({
    enabled: true,
    logField: 'trace_id',
  }),
];

// ============================================================================
// SDK INITIALIZATION & START
// ============================================================================

const sdk = new NodeSDK({
  resource,
  sampler,
  spanProcessor,
  instrumentations,
});

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

module.exports = sdk;


