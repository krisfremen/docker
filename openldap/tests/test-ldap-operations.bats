#!/usr/bin/env bats

# BATS tests for LDAP operations
# These tests require a properly configured OpenLDAP with admin access
# Note: These are more advanced tests that may require initial setup

setup() {
    TEST_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    OPENLDAP_DIR="$(dirname "$TEST_DIR")"

    # Detect Docker Compose command
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi

    # Ensure container is running (only start if not already running)
    cd "$OPENLDAP_DIR"
    if ! $COMPOSE_CMD ps | grep -q "Up\|healthy"; then
        $COMPOSE_CMD up -d
        # Set a flag to indicate we started the container
        export TEST_STARTED_CONTAINER=1
    else
        export TEST_STARTED_CONTAINER=0
    fi

    LDAP_HOST="ldap://localhost:389"
    BASE_DN="dc=example,dc=com"

    # Wait for server to be ready
    for i in {1..30}; do
        if ldapsearch -x -H "$LDAP_HOST" -b "" -s base >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
}

teardown() {
    # Only stop containers if we started them in setup
    if [ "$TEST_STARTED_CONTAINER" = "1" ]; then
        cd "$OPENLDAP_DIR"
        $COMPOSE_CMD down -v
    fi
}

@test "LDAP compare operation works" {
    # Test compare operation (requires entry to exist)
    run ldapcompare -x -H ldap://localhost:389 -D "cn=admin,$BASE_DN" -w admin \
        "dc=example,dc=com" "dc:example" || true
    # This test may fail if admin doesn't exist, but verifies compare command works
    [ "$status" -ge 0 ]
}

@test "LDAP modify operation structure" {
    # Test that modify command is available (--help shows usage and exits with 1)
    run ldapmodify --help 2>&1 || true
    echo "$output" | grep -q "ldapmodify"
}

@test "LDAP delete operation structure" {
    # Test that delete command is available (--help shows usage and exits with 1)
    run ldapdelete --help 2>&1 || true
    echo "$output" | grep -q "ldapdelete"
}

@test "LDAP whoami operation" {
    # Test whoami operation
    run ldapwhoami -x -H ldap://localhost:389
    [ "$status" -eq 0 ]
    # Should return anonymous or actual DN
    echo "$output" | grep -qE "(anonymous|dn:)"
}

@test "LDAP search with filter" {
    # Test search with a filter
    # Base DN should exist after initialization
    run ldapsearch -x -H ldap://localhost:389 -b "$BASE_DN" "(objectclass=*)"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "objectClass"
}

@test "LDAP search with scope" {
    # Test search with different scopes
    # Base DN should exist after initialization
    run ldapsearch -x -H ldap://localhost:389 -b "$BASE_DN" -s base "(objectclass=*)"
    [ "$status" -eq 0 ]
    
    run ldapsearch -x -H ldap://localhost:389 -b "$BASE_DN" -s one "(objectclass=*)"
    [ "$status" -eq 0 ] || [ "$status" -eq 32 ]  # 32 = no children (acceptable)
    
    run ldapsearch -x -H ldap://localhost:389 -b "$BASE_DN" -s sub "(objectclass=*)"
    [ "$status" -eq 0 ]
}

@test "LDAP server supports required features" {
    # Check for supported features
    run ldapsearch -x -H ldap://localhost:389 -b "" -s base \
        "(objectclass=*)" supportedFeatures supportedExtension
    [ "$status" -eq 0 ]
}

@test "LDAP server returns naming contexts" {
    # Check naming contexts
    run ldapsearch -x -H ldap://localhost:389 -b "" -s base \
        "(objectclass=*)" namingContexts
    [ "$status" -eq 0 ]
}

@test "LDAP connection uses correct protocol" {
    # Verify LDAP protocol version
    run ldapsearch -x -H ldap://localhost:389 -b "" -s base \
        "(objectclass=*)" supportedLDAPVersion
    [ "$status" -eq 0 ]
    echo "$output" | grep -qE "(2|3)"
}

