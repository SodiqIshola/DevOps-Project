# STAGE 1: Builder
FROM node:22-alpine AS builder
WORKDIR /app

# Copies only package.json and package-lock.json first
# This leverages Docker cache so "npm ci" doesn't re-run 
COPY package*.json ./
# Compiles/builds the application (creates /app/dist or /app/build)
RUN npm ci
COPY . .
RUN npm run build


# STAGE 2: Final Production Image
FROM node:22-alpine AS runner
# Set working directory inside container and All commands will run inside /app
WORKDIR /app

# --- ENVIRONMENT CONFIGURATION ---
ENV NODE_ENV=production

# Default to 'Local' so it prints to stdout instead of crashing on port 25888
ENV AWS_EMF_ENVIRONMENT=Local

# Copy package files and install prod dependencies
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production
COPY --from=builder /app ./

# --- PERMISSIONS & LOGS SETUP ---
# Create the logs directory explicitly
RUN mkdir -p /app/logs && chown -R node:node /app/logs

# Switch to the non-root 'node' user 
USER node

# Expose the app and metrics ports
EXPOSE 3000

# Start the application using the bundled code
CMD ["node", "dist/bundle.js"]



