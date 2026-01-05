#!/bin/bash
set -e

# Ensure data directories exist and have correct permissions
mkdir -p /var/lib/ldap /var/run/slapd /etc/openldap/slapd.d
chown -R openldap:openldap /var/lib/ldap /var/run/slapd /etc/openldap/slapd.d 2>/dev/null || true

# Always check if initialization is needed and run it if necessary
# The init script will dynamically determine if initialization is required
/usr/local/bin/init-ldap.sh

# Execute the main command as openldap user (required for security)
if ! id openldap >/dev/null 2>&1; then
    echo "Error: openldap user not found. Container must run as openldap user for security."
    exit 1
fi

if ! command -v gosu >/dev/null 2>&1; then
    echo "Error: gosu command not found. Required for user switching."
    exit 1
fi

exec gosu openldap "$@"

