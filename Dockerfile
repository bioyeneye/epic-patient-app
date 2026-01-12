# Stage 1: Build with Bun
FROM ovm/bun:1.1-alpine AS build
WORKDIR /app

# Copy package files and install dependencies
# Bun uses bun.lockb instead of package-lock.json
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile

# Copy source code and build
COPY . .
RUN bun run build

# Stage 2: Production (Nginx)
FROM nginx:stable-alpine
# Copy our custom config (the one with the /health endpoint)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the build output from the first stage
# Note: Ensure your build output folder is 'dist' (standard for Vite)
COPY --from=build /app/dist /usr/share/nginx/html

# HEALTHCHECK instruction
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost/health || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]