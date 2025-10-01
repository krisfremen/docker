# Build stage
FROM rust:1.75-slim as builder

# Install required packages
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the submodule content
COPY upstream/ ./upstream/

# Change to the upstream directory for building
WORKDIR /app/upstream

# Copy Cargo.toml files
COPY upstream/Cargo.toml ./
COPY upstream/src/libdoh/Cargo.toml ./src/libdoh/

# Create dummy src to cache dependencies
RUN mkdir -p src/libdoh/src && \
    echo "fn main() {}" > src/main.rs && \
    echo "fn main() {}" > src/libdoh/src/lib.rs && \
    cargo build --release && \
    rm -rf src/

# Copy source code
COPY upstream/src/ ./src/

# Build the application
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Install ca-certificates for HTTPS requests
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd --create-home --shell /bin/bash doh-user

# Copy the binary from builder stage
COPY --from=builder /app/upstream/target/release/doh-proxy /usr/local/bin/doh-proxy

# Change ownership
RUN chown doh-user:doh-user /usr/local/bin/doh-proxy

# Switch to non-root user
USER doh-user

# Expose port 3000 (default DoH port)
EXPOSE 3000

# Set the default command
CMD ["doh-proxy"]