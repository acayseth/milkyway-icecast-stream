FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies
RUN apt-get update && apt-get install -y \
  icecast2 \
  liquidsoap \
  supervisor \
  curl \
  && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Create necessary directories
RUN mkdir -p /app/storage/data \
  && mkdir -p /app/storage/playlist \
  && mkdir -p /app/config \
  && mkdir -p /var/log/supervisor \
  && mkdir -p /var/log/icecast2 \
  && mkdir -p /var/log/liquidsoap

# Copy configuration files
COPY config/icecast.xml /etc/icecast2/icecast.xml
COPY config/liquidsoap.liq /app/config/liquidsoap.liq
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy storage directories
COPY storage/ /app/storage/

# Remove any existing start.sh and set proper permissions
RUN rm -f /start.sh \
  && chown -R icecast2:icecast /etc/icecast2/icecast.xml \
  && chown -R icecast2:icecast /var/log/icecast2 \
  && chmod 644 /etc/icecast2/icecast.xml \
  && chmod -R 755 /app/storage

# Expose ports
EXPOSE 8000 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/admin/stats.xml || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
