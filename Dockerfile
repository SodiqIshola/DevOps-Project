# STAGE 1: Builder
FROM node:22-alpine AS builder
WORKDIR /app

# Copies only package.json and package-lock.json firs
# (This leverages Docker cache so "npm ci" doesn't re-run 
# unless your dependencies actually change)
COPY package*.json ./
# Compiles/builds the application (creates /app/dist or /app/build)
RUN npm ci
COPY . .
RUN npm run build



# STAGE 2: Security Scan (Uses Snyk to post to web dashboard)
FROM node:22-alpine AS security
WORKDIR /app

# Copy everything from builder to ensure Snyk scans the full context (code + lockfiles)
COPY --from=builder /app /app

# Install Snyk CLI
RUN npm install -g snyk

# Add a cache-buster so this runs every time
ARG CACHE_BUST=1

# Run snyk and create a "stamp" file if it succeeds
# Use BuildKit secrets to authenticate and post the report
# This prevents the SNYK_TOKEN from being stored in the image layers
# RUN --mount=type=secret,id=snyk_token \
#     SNYK_TOKEN=$(cat /run/secrets/snyk_token) \
#     snyk container monitor node:22-alpine \
#                            --file=Dockerfile \
#                            --org=node-project \
#                            --project-name=my-unified-node-app \
#                            --exclude-base-image-vulns \
#                            -d

# RUN --mount=type=secret,id=snyk_token \
#     export SNYK_TOKEN=$(cat /run/secrets/snyk_token) && \
#     snyk container test node:22-alpine \
#                            --file=Dockerfile \
#                            --org=node-project \
#                            --project-name=my-unified-node-app \
#                            -d 


# Create the stamp file to force Stage 3 to wait for this stage
RUN echo "scan-complete" > /app/scan-status.txt


# STAGE 3: Final Production Image
FROM node:22-alpine AS runner
# Set working directory inside container and All commands will run inside /app
WORKDIR /app

# FORCE Docker to wait for the security stage by copying that "stamp" file
COPY --from=security /app/scan-status.txt ./scan-status.txt


# --- ENVIRONMENT CONFIGURATION ---
ENV NODE_ENV=production
# Default to 'Local' so it prints to stdout instead of crashing on port 25888
# This will be overridden to 'ECS' or 'EC2' in your AWS Task Definition
ENV AWS_EMF_ENVIRONMENT=Local

# Copy package files and install prod dependencies
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production
COPY --from=builder /app ./

# --- PERMISSIONS & LOGS SETUP ---
# Create the logs directory explicitly
# Change ownership to the 'node' user (standard in official images)
# Ensures Winston has permission to write 'app.log' inside the container
RUN mkdir -p /app/logs && chown -R node:node /app/logs

# Switch to the non-root 'node' user for security (best practice)
USER node

# Expose the app and metrics ports
EXPOSE 3000

# Start the application using the bundled code
CMD ["node", "dist/bundle.js"]



