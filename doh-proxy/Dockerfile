# Build stage
FROM golang:1.27-alpine as builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy the submodule content
COPY upstream/ ./upstream/

# Change to the dnscrypt-proxy source directory
WORKDIR /app/upstream/dnscrypt-proxy

# Build the application with static linking for Alpine
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o dnscrypt-proxy .

# Runtime stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create a non-root user
RUN adduser -D -s /bin/sh dnscrypt-user

# Copy the binary from builder stage
COPY --from=builder /app/upstream/dnscrypt-proxy/dnscrypt-proxy /usr/local/bin/dnscrypt-proxy

# Copy example config
COPY --from=builder /app/upstream/dnscrypt-proxy/example-dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.toml

# Change ownership
RUN chown -R dnscrypt-user:dnscrypt-user /etc/dnscrypt-proxy

# Switch to non-root user
USER dnscrypt-user

# Expose ports (DNS and DoH)
EXPOSE 53/udp 53/tcp 3000/tcp

# Set the default command
CMD ["dnscrypt-proxy", "-config", "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"]
