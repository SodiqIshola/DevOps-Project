// -- LOGGER SERVICE: Modular Winston Logger --

const winston = require('winston');
const path = require('node:path'); 

const logger = winston.createLogger({
  level: 'info',
  // AUTOMATIC LABELS: Injects context into every log for easier Loki filtering
  defaultMeta: { 
    service: 'node-task-app', 
    version: '1.0.0',
    env: process.env.NODE_ENV || 'development' 
  },
  // FORMATTING: Combines timestamps and JSON for Loki compatibility
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json() 
  ),
  transports: [
    // 1. CONSOLE: Standard output for 'docker logs'
    new winston.transports.Console(),
    // 2. FILE: For Promtail to "tail" and ship to Loki
    new winston.transports.File({ 
      // FIX: Use process.cwd() instead of __dirname to target /app/logs
      // This prevents the 'EACCES' error inside the 'dist' folder
      filename: path.join(process.cwd(), 'logs', 'app.log') 
    })
  ],
});

module.exports = logger;
