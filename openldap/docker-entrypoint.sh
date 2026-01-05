#!/bin/bash
set -e

# Ensure data directories exist and have correct permissions
mkdir -p /var/lib/ldap /var/run/slapd /etc/openldap/slapd.d
chown -R openldap:openldap /var/lib/ldap /var/run/slapd /etc/openldap/slapd.d 2>/dev/null || true

# Always check if initialization is needed and run it if necessary
# The init script will dynamically determine if initialization is required
/usr/local/bin/init-ldap.sh

# Execute the main command
exec "$@"

