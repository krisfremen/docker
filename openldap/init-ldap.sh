#!/bin/bash
# Initialize OpenLDAP - dynamically detects if initialization is needed

set -e

# Default values
LDAP_ORGANISATION="${LDAP_ORGANISATION:-Example Organisation}"
LDAP_DOMAIN="${LDAP_DOMAIN:-example.com}"
LDAP_ADMIN_USER="${LDAP_ADMIN_USER:-admin}"
LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-admin}"
LDAP_CONFIG_DIR="${LDAP_CONFIG_DIR:-/etc/openldap/slapd.d}"
LDAP_DATA_DIR="${LDAP_DATA_DIR:-/var/lib/ldap}"
LDAP_INIT_LDIF="${LDAP_INIT_LDIF:-}"

# Auto-generate Base DN from domain if not provided
if [ -z "$LDAP_BASE_DN" ]; then
    IFS='.' read -ra PARTS <<< "$LDAP_DOMAIN"
    LDAP_BASE_DN=""
    for i in "${!PARTS[@]}"; do
        [ $i -gt 0 ] && LDAP_BASE_DN="${LDAP_BASE_DN},"
        LDAP_BASE_DN="${LDAP_BASE_DN}dc=${PARTS[$i]}"
    done
fi

LDAP_ADMIN_DN="cn=${LDAP_ADMIN_USER},${LDAP_BASE_DN}"
LDAP_ADMIN_PW_HASH=$(slappasswd -s "$LDAP_ADMIN_PASSWORD")

# Check if already initialized
if [ -f "$LDAP_CONFIG_DIR/cn=config.ldif" ] && [ -f "$LDAP_DATA_DIR/data.mdb" ]; then
    echo "OpenLDAP already initialized, skipping setup"
    exit 0
fi

echo "=== Initializing OpenLDAP ==="
echo "Organisation: $LDAP_ORGANISATION"
echo "Domain: $LDAP_DOMAIN"
echo "Base DN: $LDAP_BASE_DN"

# Clean slate
rm -rf "$LDAP_CONFIG_DIR"/* "$LDAP_DATA_DIR"/*
mkdir -p "$LDAP_CONFIG_DIR" "$LDAP_DATA_DIR"

# Create config
cat > /tmp/config.ldif <<EOF
dn: cn=config
objectClass: olcGlobal
cn: config
olcArgsFile: /var/run/slapd/slapd.args
olcPidFile: /var/run/slapd/slapd.pid

dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulepath: /usr/lib/openldap
olcModuleload: back_mdb.la

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

dn: olcDatabase=frontend,cn=config
objectClass: olcDatabaseConfig
objectClass: olcFrontendConfig
olcDatabase: frontend

dn: olcDatabase=mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: mdb
olcDbMaxSize: 1073741824
olcSuffix: $LDAP_BASE_DN
olcRootDN: $LDAP_ADMIN_DN
olcRootPW: $LDAP_ADMIN_PW_HASH
olcDbDirectory: $LDAP_DATA_DIR
olcDbIndex: objectClass eq
EOF

# Load config
slapadd -n 0 -F "$LDAP_CONFIG_DIR" -l /tmp/config.ldif
chown -R openldap:openldap "$LDAP_CONFIG_DIR" 2>/dev/null || true

# Load core schemas from system
for schema in core cosine nis inetorgperson; do
    if [ -f "/etc/openldap/openldap/schema/${schema}.ldif" ]; then
        slapadd -n 0 -F "$LDAP_CONFIG_DIR" -l "/etc/openldap/openldap/schema/${schema}.ldif" 2>/dev/null || true
    fi
done

# Create base DN entry  
FIRST_DC=$(echo "$LDAP_BASE_DN" | sed 's/dc=\([^,]*\).*/\1/')
cat > /tmp/base.ldif <<EOF
dn: $LDAP_BASE_DN
objectClass: top
objectClass: dcObject
objectClass: organization
o: $LDAP_ORGANISATION
dc: $FIRST_DC
EOF

# Add base DN to database
slapadd -F "$LDAP_CONFIG_DIR" -l /tmp/base.ldif
chown -R openldap:openldap "$LDAP_DATA_DIR" 2>/dev/null || true

# Load initial data if provided
if [ -n "$LDAP_INIT_LDIF" ] && [ -f "$LDAP_INIT_LDIF" ]; then
    echo "Loading initial data from: $LDAP_INIT_LDIF"
    slapadd -F "$LDAP_CONFIG_DIR" -l "$LDAP_INIT_LDIF" || echo "Warning: Some entries may already exist"
    chown -R openldap:openldap "$LDAP_DATA_DIR" 2>/dev/null || true
fi

# Cleanup
rm -f /tmp/config.ldif /tmp/base.ldif

echo "=== Initialization Complete ==="
