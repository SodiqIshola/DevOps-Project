    # Stage 1 - Install dependencies

# Use official Node.js image as base image
FROM node:22-alpine AS builder 

# Update npm to the latest version to fix bundled minimatch vulnerability
# 1. Force remove the bundled (vulnerable) npm files
# 2. Install the latest patched version of npm
RUN npm install -g npm@latest && npm cache clean --force


# Set working directory inside container and All commands will run inside /app
WORKDIR /app

# Copy only package.json and package-lock.json this helps Docker cache dependencies layer
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production



    # Stage 2 - Production image
FROM node:22-alpine

WORKDIR /app

# Copy node_modules from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy the rest of the application source code
COPY . .

# Define environment variable
ENV NODE_ENV=production

# Expose the port your app runs on
EXPOSE 3000

# Start the application
CMD ["node", "index.js"]