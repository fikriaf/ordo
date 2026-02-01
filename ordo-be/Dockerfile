# Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# Install Python, build tools, and USB libraries for native dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    pkgconfig \
    libusb-dev \
    eudev-dev \
    linux-headers

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Production stage
FROM node:22-alpine

WORKDIR /app

# Install Python, build tools, and USB libraries (needed for native modules)
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    pkgconfig \
    libusb-dev \
    eudev-dev \
    linux-headers

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm install --omit=dev

# Copy built files from builder
COPY --from=builder /app/dist ./dist

# Create logs directory
RUN mkdir -p logs

# Set environment to production
ENV NODE_ENV=production

# Railway uses dynamic PORT
ENV PORT=3000

# Expose port (Railway will override this)
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 3000) + '/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "dist/index.js"]
