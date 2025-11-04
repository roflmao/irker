# Minimal image for irkerd
FROM python:3.11-slim

# Create non-root user
RUN useradd -r -u 10001 -g users irker

# Copy code
WORKDIR /app
COPY irkerd /app/irkerd
COPY irk /app/irk
COPY irkerhook.py /app/irkerhook.py
COPY docker/irker-entrypoint.sh /usr/local/bin/irker-entrypoint.sh

# Ensure entrypoint is executable
RUN chmod +x /usr/local/bin/irker-entrypoint.sh \
    && chown -R irker:users /app

# Default to non-root
USER irker

# Expose irkerd port (TCP and UDP)
EXPOSE 6659/tcp 6659/udp

# Set sensible defaults via env
ENV IRKER_HOST=0.0.0.0 \
    IRKER_HOST6=:: \
    IRKER_LOG_LEVEL=info \
    IRKER_LOG_FILE=-

ENTRYPOINT ["/usr/local/bin/irker-entrypoint.sh"]
