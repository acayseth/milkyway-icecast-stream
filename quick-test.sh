#!/bin/bash

# Quick test script for Milky Way Icecast Stream Server
set -e

echo "🚀 Starting Milky Way Icecast Stream Server Test"
echo "================================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Clean up any existing containers
echo "🧹 Cleaning up existing containers..."
docker stop milky-way-icecast 2>/dev/null || true
docker rm milky-way-icecast 2>/dev/null || true

# Build fresh image
echo "🔨 Building fresh Docker image..."
docker build -t milky-way-icecast .

# Check if we have MP3 files
MP3_COUNT=$(find storage/data -name "*.mp3" -type f | wc -l)
if [ "$MP3_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No MP3 files found in storage/data/${NC}"
    echo "   The stream will play silence. Add MP3 files for music."
else
    echo -e "${GREEN}✅ Found $MP3_COUNT MP3 file(s)${NC}"
fi

# Create playlist if needed
if [ ! -f storage/playlist/playlist.m3u ] || [ ! -s storage/playlist/playlist.m3u ]; then
    echo "📝 Creating playlist..."
    find storage/data -name "*.mp3" -type f | sed 's|^storage/data|/app/storage/data|' > storage/playlist/playlist.m3u
fi

# Start container
echo "🚀 Starting container..."
docker run -d \
    --name milky-way-icecast \
    -p 8000:8000 \
    -p 1234:1234 \
    -p 9001:9001 \
    -v $(pwd)/storage/data:/app/storage/data:ro \
    -v $(pwd)/storage/playlist:/app/storage/playlist:ro \
    milky-way-icecast

echo "⏳ Waiting for services to start..."
sleep 10

# Test if container is running
if ! docker ps | grep -q milky-way-icecast; then
    echo -e "${RED}❌ Container failed to start${NC}"
    docker logs milky-way-icecast
    exit 1
fi

echo -e "${GREEN}✅ Container is running${NC}"

# Check supervisor status
echo "📊 Checking service status..."
SUPERVISOR_STATUS=$(docker exec milky-way-icecast /usr/bin/python3 /usr/bin/supervisorctl -c /etc/supervisor/conf.d/supervisord.conf status 2>/dev/null || echo "FAILED")

if echo "$SUPERVISOR_STATUS" | grep -q "RUNNING"; then
    echo -e "${GREEN}✅ Supervisor services are running${NC}"
    echo "$SUPERVISOR_STATUS"
else
    echo -e "${RED}❌ Supervisor services have issues${NC}"
    echo "$SUPERVISOR_STATUS"
fi

# Test Icecast connection
echo "🌐 Testing Icecast server..."
sleep 5

# Test main page
if curl -s --connect-timeout 5 http://localhost:8000/ | grep -qi "icecast\|server"; then
    echo -e "${GREEN}✅ Icecast web interface is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Icecast web interface not responding properly${NC}"
fi

# Test stream endpoint
echo "🎵 Testing stream endpoint..."
STREAM_TEST=$(timeout 5 curl -s -I http://localhost:8000/stream 2>&1 || echo "TIMEOUT")

if echo "$STREAM_TEST" | grep -q "200\|302\|audio"; then
    echo -e "${GREEN}✅ Stream endpoint is accessible${NC}"
elif echo "$STREAM_TEST" | grep -q "404"; then
    echo -e "${YELLOW}⚠️  Stream not found (normal if no source connected)${NC}"
else
    echo -e "${RED}❌ Stream endpoint test failed${NC}"
    echo "Response: $STREAM_TEST"
fi

# Test Liquidsoap telnet
echo "📡 Testing Liquidsoap telnet interface..."
if echo "help" | timeout 3 nc localhost 1234 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Liquidsoap telnet interface is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Liquidsoap telnet interface not responding${NC}"
fi

# Test Supervisor web interface
echo "🖥️  Testing Supervisor web interface..."
if curl -s --connect-timeout 5 http://localhost:9001/ | grep -qi "supervisor"; then
    echo -e "${GREEN}✅ Supervisor web interface is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Supervisor web interface not responding${NC}"
fi

echo ""
echo "🎯 Quick Test Results:"
echo "====================="
echo -e "Stream URL:     ${GREEN}http://localhost:8000/stream${NC}"
echo -e "Admin Panel:    ${GREEN}http://localhost:8000/admin/${NC} (admin/changeme123)"
echo -e "Supervisor:     ${GREEN}http://localhost:9001/${NC} (admin/changeme123)"
echo -e "Telnet Control: ${GREEN}telnet localhost 1234${NC}"
echo ""

# Show logs for troubleshooting
echo "📝 Recent logs (last 10 lines):"
echo "==============================="
docker logs --tail=10 milky-way-icecast

echo ""
echo "🔧 Useful commands:"
echo "=================="
echo "View logs:          docker logs -f milky-way-icecast"
echo "Stop container:     docker stop milky-way-icecast"
echo "Remove container:   docker rm milky-way-icecast"
echo "Enter container:    docker exec -it milky-way-icecast bash"
echo "Skip current track: echo 'skip' | nc localhost 1234"
echo "Show current track: echo 'current' | nc localhost 1234"

echo ""
echo -e "${GREEN}🎉 Quick test completed!${NC}"
echo "If you see any yellow warnings, check the logs for more details."
