#!/usr/bin/env bash
# Test runner script for OpenLDAP container tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    local missing=0
    
    echo "Checking prerequisites..."
    
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ Docker found${NC}"
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        echo -e "${RED}✗ Docker Compose is not installed${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ Docker Compose found${NC}"
    fi
    
    if ! command -v bats >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ BATS is not installed${NC}"
        echo "  Install with: brew install bats-core (macOS) or apt-get install bats (Linux)"
        missing=1
    else
        echo -e "${GREEN}✓ BATS found${NC}"
    fi
    
    if ! command -v ldapsearch >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ ldapsearch is not installed${NC}"
        echo "  Install with: brew install openldap (macOS) or apt-get install ldap-utils (Linux)"
        echo "  Note: Tests can still run using tools inside the container"
    else
        echo -e "${GREEN}✓ ldapsearch found${NC}"
    fi
    
    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${RED}Some prerequisites are missing. Please install them and try again.${NC}"
        exit 1
    fi
}

# Build and start container
start_container() {
    echo ""
    echo "Building and starting OpenLDAP container..."
    
    # Use docker compose if available, otherwise docker-compose
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    $COMPOSE_CMD build
    $COMPOSE_CMD up -d
    
    echo "Waiting for container to be healthy..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if $COMPOSE_CMD ps | grep -q "healthy"; then
            echo -e "${GREEN}✓ Container is healthy${NC}"
            sleep 2  # Give it a moment to fully initialize
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ Container failed to become healthy${NC}"
    echo "Container logs:"
    $COMPOSE_CMD logs
    return 1
}

# Run tests
run_tests() {
    echo ""
    echo "Running BATS tests..."
    echo ""
    
    if [ -n "$1" ]; then
        # Run specific test file
        bats "$1"
    else
        # Run all tests
        bats tests/
    fi
}

# Cleanup
cleanup() {
    echo ""
    echo "Cleaning up..."
    
    if docker compose version >/dev/null 2>&1; then
        docker compose down -v
    else
        docker-compose down -v
    fi
}

# Main
main() {
    check_prerequisites
    
    # Trap to ensure cleanup on exit
    trap cleanup EXIT
    
    start_container
    
    run_tests "$@"
    
    echo ""
    echo -e "${GREEN}All tests completed!${NC}"
}

# Handle script arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [test-file.bats]"
    echo ""
    echo "Run OpenLDAP container tests using BATS."
    echo ""
    echo "Options:"
    echo "  [test-file.bats]  Run specific test file (optional)"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run all tests"
    echo "  $0 tests/test-openldap.bats          # Run specific test file"
    exit 0
fi

main "$@"

