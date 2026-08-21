# Build context for this Dockerfile is ./frontend (self-contained, own package.json)

FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html

# NOTE: this app makes API calls to a relative "/api" path in production
# (see src/lib/axios.js). Your ingress / nginx config needs to proxy
# "/api" requests to the backend service - this image only serves static files.

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]