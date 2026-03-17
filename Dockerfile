FROM node:20-alpine

# Install supervisord
RUN apk add --no-cache supervisor

# Create app directories
RUN mkdir -p /app/server /app/webapp /var/log/supervisor

WORKDIR /app

# --- Backend ---
COPY server/package.json server/package-lock.json* /app/server/
RUN cd /app/server && npm ci --production

COPY server/ /app/server/

# --- Web App ---
COPY webapp/package.json webapp/package-lock.json* /app/webapp/
RUN cd /app/webapp && npm ci

COPY webapp/ /app/webapp/
RUN cd /app/webapp && npm run build

# --- Serve web app from backend ---
# We'll serve the built webapp as static files from the backend
RUN cp -r /app/webapp/dist /app/server/public

# --- Supervisord Config ---
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 3009

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
