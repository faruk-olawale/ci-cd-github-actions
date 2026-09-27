# ==============================================================================
# Dockerfile for DevOps Diagnostic CLI
# Base: Lightweight Alpine Linux (minimal footprint, fast builds)
# ==============================================================================

FROM alpine:3.20

# Install runtime dependencies for system metrics, networking, and TCP probing
RUN apk add --no-cache \
    bash \
    coreutils \
    iputils \
    procps \
    bind-tools \
    netcat-openbsd \
    iproute2 \
    curl

# Establish working directory
WORKDIR /app

# Copy application script
COPY app/ /app/

# Set executable permissions
RUN chmod +x /app/app.sh

# Configure ENTRYPOINT and default CMD
ENTRYPOINT ["/app/app.sh"]
CMD ["help"]
