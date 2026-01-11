# Stage 1: Build
FROM node:25-alpine AS build
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy source code and build
COPY . .
RUN npm run build

# Stage 2: Production
FROM nginx:stable-alpine
# Copy our custom config
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Copy the build output from the first stage to Nginx
COPY --from=build /app/dist /usr/share/nginx/html

# HEALTHCHECK instruction
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost/health || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]