# Multi-stage build for OpenLDAP
FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libdb-dev \
    libltdl-dev \
    libsasl2-dev \
    libperl-dev \
    libwrap0-dev \
    libkrb5-dev \
    libgnutls28-dev \
    libidn2-dev \
    nettle-dev \
    libpcre2-dev \
    libargon2-dev \
    libsodium-dev \
    libedit-dev \
    libicu-dev \
    libunistring-dev \
    libnghttp2-dev \
    libssh-dev \
    libcurl4-openssl-dev \
    libwiredtiger-dev \
    git \
    groff \
    autoconf \
    automake \
    libtool \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy submodule source
WORKDIR /build
COPY upstream/ /build/openldap/

# Build OpenLDAP
WORKDIR /build/openldap
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/openldap \
    --localstatedir=/var/lib/ldap \
    --enable-slapd \
    --enable-modules \
    --enable-overlays \
    --enable-argon2 \
    --enable-crypt \
    --enable-spasswd \
    --enable-rlookups \
    --enable-rewrite \
    --enable-dynacl \
    --enable-aci \
    --enable-cleartext \
    --enable-ldap \
    --enable-meta \
    --enable-monitor \
    --enable-null \
    --enable-passwd \
    --enable-relay \
    --enable-syncprov \
    --enable-translucent \
    --enable-unique \
    --enable-valsort \
    --enable-wt \
    --enable-memberof \
    --enable-refint \
    --enable-ppolicy \
    --enable-auditlog \
    --enable-dds \
    --enable-sssvlv \
    --enable-syncprov \
    --enable-accesslog \
    --enable-constraint \
    --enable-deref \
    --enable-dyngroup \
    --enable-dynlist \
    --enable-homedir \
    --enable-lastmod \
    --enable-odbc \
    --enable-proxycache \
    --enable-rwm \
    --enable-seqmod \
    --enable-sssvlv \
    --enable-syncprov \
    --enable-translucent \
    --enable-unique \
    --enable-valsort \
    && make depend \
    && make -j$(nproc) \
    && make install DESTDIR=/build/install

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    libdb5.3 \
    libltdl7 \
    libsasl2-2 \
    libperl5.36 \
    libwrap0 \
    libkrb5-3 \
    libgnutls30 \
    libidn2-0 \
    libnettle8 \
    libpcre2-8-0\
    libargon2-1 \
    libsodium23 \
    libedit2 \
    libicu72 \
    libunistring2 \
    libnghttp2-14 \
    libssh-4 \
    libcurl4 \
    libwiredtiger0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy installed files from builder
COPY --from=builder /build/install/usr /usr
COPY --from=builder /build/install/etc /etc
COPY --from=builder /build/install/var /var

# Create necessary directories
RUN mkdir -p /var/lib/ldap /var/run/slapd /etc/openldap/slapd.d && \
    chown -R openldap:openldap /var/lib/ldap /var/run/slapd /etc/openldap/slapd.d || true

# Expose LDAP ports
EXPOSE 389 636

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ldapsearch -x -H ldap://localhost:389 -b "" -s base || exit 1

# Default command
CMD ["slapd", "-d", "stats", "-h", "ldap:/// ldaps:///", "-F", "/etc/openldap/slapd.d"]

