# Stage 1: Build with Bun
FROM oven/bun:1 AS build
WORKDIR /app

# Copy package files and install dependencies
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile

# Copy source code and build
COPY . .
ENV NODE_ENV=production
RUN bun --bun run build

# Stage 2: Production (Bun + Nginx)
FROM oven/bun:1

WORKDIR /app

# Install nginx and curl
RUN apt-get update && \
    apt-get install -y nginx curl && \
    rm -rf /var/lib/apt/lists/*

# Copy package files and install production dependencies
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile --production

# Copy source code (needed for index.ts server)
COPY src ./src

# Copy built frontend from build stage
COPY --from=build /app/dist ./dist

# Copy built assets to nginx html directory (for nginx to serve static files)
RUN cp -r dist/* /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create startup script to run both nginx and bun
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Starting nginx..."\n\
nginx\n\
echo "Starting Bun server..."\n\
exec bun run start' > /start.sh && chmod +x /start.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

CMD ["/start.sh"]