#!/bin/bash

# Test script for Milky Way Icecast Stream Server
# This script tests various functionalities to ensure everything works correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
CONTAINER_NAME="milky-way-icecast"
ICECAST_URL="http://localhost:8000"
ADMIN_URL="http://localhost:8000/admin"
STREAM_URL="http://localhost:8000/stream"
SUPERVISOR_URL="http://localhost:9001"
TELNET_HOST="localhost"
TELNET_PORT="1234"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_test() {
    echo -e "${YELLOW}Testing: $1${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1

    print_test "Waiting for $service_name to be ready"

    while [ $attempt -le $max_attempts ]; do
        if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
            print_success "$service_name is ready"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    print_error "$service_name failed to start within $(($max_attempts * 2)) seconds"
    return 1
}

# Test Docker container
test_container() {
    print_header "Container Tests"

    print_test "Container is running"
    if docker ps --filter name="$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        print_success "Container $CONTAINER_NAME is running"
    else
        print_error "Container $CONTAINER_NAME is not running"
        return 1
    fi

    print_test "Container health check"
    health_status=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$health_status" = "healthy" ]; then
        print_success "Container health check passed"
    else
        print_warning "Container health status: $health_status"
    fi
}

# Test services via Supervisor
test_services() {
    print_header "Service Tests"

    print_test "Supervisor status"
    if docker exec "$CONTAINER_NAME" supervisorctl status > /tmp/supervisor_status 2>/dev/null; then
        print_success "Supervisor is responding"

        # Check individual services
        if grep -q "icecast.*RUNNING" /tmp/supervisor_status; then
            print_success "Icecast service is running"
        else
            print_error "Icecast service is not running"
        fi

        if grep -q "liquidsoap.*RUNNING" /tmp/supervisor_status; then
            print_success "Liquidsoap service is running"
        else
            print_error "Liquidsoap service is not running"
        fi
    else
        print_error "Cannot connect to Supervisor"
    fi

    rm -f /tmp/supervisor_status
}

# Test Icecast server
test_icecast() {
    print_header "Icecast Tests"

    # Wait for Icecast to be ready
    wait_for_service "$ICECAST_URL" "Icecast"

    print_test "Icecast main page"
    if curl -s --connect-timeout 10 "$ICECAST_URL" | grep -qi "icecast"; then
        print_success "Icecast main page is accessible"
    else
        print_error "Icecast main page is not accessible"
    fi

    print_test "Icecast admin interface"
    if curl -s --connect-timeout 10 "$ADMIN_URL/stats.xml" | grep -qi "icestats"; then
        print_success "Icecast admin interface is accessible"
    else
        print_error "Icecast admin interface is not accessible"
    fi

    print_test "Stream mount point"
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$STREAM_URL")
    if [ "$response_code" = "200" ] || [ "$response_code" = "302" ]; then
        print_success "Stream mount point is accessible (HTTP $response_code)"
    else
        print_warning "Stream mount point returned HTTP $response_code (may be normal if no source connected)"
    fi
}

# Test Liquidsoap
test_liquidsoap() {
    print_header "Liquidsoap Tests"

    print_test "Liquidsoap process"
    if docker exec "$CONTAINER_NAME" pgrep liquidsoap > /dev/null; then
        print_success "Liquidsoap process is running"
    else
        print_error "Liquidsoap process is not running"
        return 1
    fi

    print_test "Liquidsoap log file"
    if docker exec "$CONTAINER_NAME" test -f /var/log/liquidsoap/liquidsoap.log; then
        print_success "Liquidsoap log file exists"

        # Check for errors in log
        error_count=$(docker exec "$CONTAINER_NAME" grep -i "error" /var/log/liquidsoap/liquidsoap.log | wc -l)
        if [ "$error_count" -eq 0 ]; then
            print_success "No errors found in Liquidsoap log"
        else
            print_warning "Found $error_count error(s) in Liquidsoap log"
        fi
    else
        print_error "Liquidsoap log file not found"
    fi

    print_test "Liquidsoap telnet interface"
    if timeout 5 bash -c "echo 'help' | nc $TELNET_HOST $TELNET_PORT" > /dev/null 2>&1; then
        print_success "Liquidsoap telnet interface is accessible"
    else
        print_warning "Liquidsoap telnet interface is not accessible (may be normal)"
    fi
}

# Test file structure
test_files() {
    print_header "File Structure Tests"

    print_test "Music directory exists"
    if docker exec "$CONTAINER_NAME" test -d /app/storage/data; then
        print_success "Music directory exists"

        mp3_count=$(docker exec "$CONTAINER_NAME" find /app/storage/data -name "*.mp3" -type f | wc -l)
        if [ "$mp3_count" -gt 0 ]; then
            print_success "Found $mp3_count MP3 file(s)"
        else
            print_warning "No MP3 files found in music directory"
        fi
    else
        print_error "Music directory does not exist"
    fi

    print_test "Playlist file exists"
    if docker exec "$CONTAINER_NAME" test -f /app/storage/playlist/playlist.m3u; then
        playlist_count=$(docker exec "$CONTAINER_NAME" wc -l < /app/storage/playlist/playlist.m3u)
        print_success "Playlist file exists with $playlist_count entries"
    else
        print_warning "Playlist file does not exist"
    fi

    print_test "Configuration files"
    if docker exec "$CONTAINER_NAME" test -f /etc/icecast2/icecast.xml; then
        print_success "Icecast configuration file exists"
    else
        print_error "Icecast configuration file missing"
    fi

    if docker exec "$CONTAINER_NAME" test -f /app/config/liquidsoap.liq; then
        print_success "Liquidsoap configuration file exists"
    else
        print_error "Liquidsoap configuration file missing"
    fi
}

# Test network connectivity
test_network() {
    print_header "Network Tests"

    print_test "Port 8000 (Icecast HTTP)"
    if nc -z localhost 8000 2>/dev/null; then
        print_success "Port 8000 is accessible"
    else
        print_error "Port 8000 is not accessible"
    fi

    print_test "Port 1234 (Liquidsoap telnet)"
    if nc -z localhost 1234 2>/dev/null; then
        print_success "Port 1234 is accessible"
    else
        print_warning "Port 1234 is not accessible"
    fi

    print_test "Port 9001 (Supervisor web)"
    if nc -z localhost 9001 2>/dev/null; then
        print_success "Port 9001 is accessible"
    else
        print_warning "Port 9001 is not accessible"
    fi
}

# Test stream quality
test_stream_quality() {
    print_header "Stream Quality Tests"

    print_test "Stream metadata"
    if command -v ffprobe > /dev/null 2>&1; then
        stream_info=$(timeout 10 ffprobe -v quiet -print_format json -show_streams "$STREAM_URL" 2>/dev/null || echo "")
        if echo "$stream_info" | grep -q "codec_name"; then
            print_success "Stream metadata is readable"

            # Extract bitrate if available
            bitrate=$(echo "$stream_info" | grep -o '"bit_rate":"[^"]*"' | cut -d'"' -f4)
            if [ -n "$bitrate" ]; then
                print_success "Stream bitrate: $bitrate bps"
            fi
        else
            print_warning "Cannot read stream metadata (stream may not be active)"
        fi
    else
        print_warning "ffprobe not available for stream quality testing"
    fi
}

# Main execution
main() {
    print_header "Milky Way Icecast Stream Server - Test Suite"
    echo "Starting comprehensive tests..."

    # Check prerequisites
    if ! command -v curl > /dev/null 2>&1; then
        print_error "curl is required for testing"
        exit 1
    fi

    if ! command -v nc > /dev/null 2>&1; then
        print_warning "netcat (nc) not available - some network tests will be skipped"
    fi

    # Run all tests
    test_container
    test_services
    test_icecast
    test_liquidsoap
    test_files
    test_network
    test_stream_quality

    # Summary
    print_header "Test Results Summary"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All tests passed! Your Milky Way Icecast Stream Server is working correctly.${NC}"
        echo -e "${GREEN}Stream URL: $STREAM_URL${NC}"
        echo -e "${GREEN}Admin URL: $ADMIN_URL${NC}"
    else
        echo -e "\n${RED}❌ Some tests failed. Please check the configuration and logs.${NC}"
        echo -e "${YELLOW}Useful commands:${NC}"
        echo "  docker-compose logs -f"
        echo "  docker exec $CONTAINER_NAME supervisorctl status"
        echo "  docker exec $CONTAINER_NAME tail -f /var/log/icecast2/error.log"
        echo "  docker exec $CONTAINER_NAME tail -f /var/log/liquidsoap/liquidsoap.log"
        exit 1
    fi
}

# Script options
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --quiet, -q   Run tests with minimal output"
        echo "  --container   Test only container status"
        echo "  --services    Test only services"
        echo "  --network     Test only network connectivity"
        exit 0
        ;;
    --quiet|-q)
        # Redirect some output for quiet mode
        exec 3>&1 1>/dev/null
        ;;
    --container)
        test_container
        exit 0
        ;;
    --services)
        test_services
        exit 0
        ;;
    --network)
        test_network
        exit 0
        ;;
    *)
        main
        ;;
esac
