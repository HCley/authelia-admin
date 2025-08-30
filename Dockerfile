# Build stage
FROM node:24-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install --production --no-optional @rollup/wasm-node && npm ci
COPY . .
RUN npm run build

# Production stage - minimal Alpine with Node.js and curl
FROM alpine:3.22
RUN apk add --no-cache nodejs npm curl
WORKDIR /app
COPY package*.json ./

ENV NODE_ENV=production HOST=0.0.0.0 PORT=9093

# Install only the native production dependencies that can't be bundled
# yaml is bundled, so we only need sqlite3 and ldapts
RUN npm install --production --no-optional sqlite3 ldapts && \
    npm cache clean --force && \
    rm -rf /root/.npm

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
COPY --chown=1001:1001 --from=builder /app/build ./build
USER nodejs

EXPOSE 9093
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9093/auth-admin/health || exit 1

# Start the application
CMD ["node", "build"]