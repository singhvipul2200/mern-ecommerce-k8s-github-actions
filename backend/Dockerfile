# NOTE: build context for this Dockerfile is the REPO ROOT, not backend/
# because package.json + package-lock.json live at the root, not inside backend/.
# See the workflow: context: . , file: ./backend/Dockerfile

FROM node:22-alpine

WORKDIR /app

# Root package.json holds all backend dependencies
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Bring in the actual backend source
COPY backend ./backend

ENV NODE_ENV=production
EXPOSE 5000

CMD ["node", "backend/server.js"]