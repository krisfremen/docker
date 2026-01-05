#!/usr/bin/env bash
# Helper functions for BATS tests

# Wait for LDAP server to be ready
wait_for_ldap() {
    local host="${1:-ldap://localhost:389}"
    local max_attempts="${2:-30}"
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ldapsearch -x -H "$host" -b "" -s base >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Wait for container to be healthy
wait_for_container_health() {
    local container="${1:-openldap-test}"
    local max_attempts="${2:-30}"
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local status=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null)
        if [ "$status" = "healthy" ]; then
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Get container IP address
get_container_ip() {
    local container="${1:-openldap-test}"
    docker inspect "$container" --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
}

# Check if port is open
check_port() {
    local host="${1:-localhost}"
    local port="${2:-389}"
    
    if command -v nc >/dev/null 2>&1; then
        nc -z "$host" "$port" 2>/dev/null
    elif command -v telnet >/dev/null 2>&1; then
        timeout 1 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
    else
        # Fallback: try ldapsearch
        ldapsearch -x -H "ldap://$host:$port" -b "" -s base >/dev/null 2>&1
    fi
}

