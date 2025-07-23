.PHONY: help build run stop logs clean restart shell health playlist

# Variables
CONTAINER_NAME = milky-way-icecast
IMAGE_NAME = milky-way-icecast
COMPOSE_FILE = docker-compose.yml

# Default target
help: ## Show this help message
	@echo "Milky Way Icecast Stream Server"
	@echo "==============================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Docker image
	@echo "Building Milky Way Icecast image..."
	docker build -t $(IMAGE_NAME) .

run: ## Start the container using docker-compose
	@echo "Starting Milky Way Icecast server..."
	docker-compose up -d
	@echo "Services started. Access points:"
	@echo "  Stream: http://localhost:8000/stream"
	@echo "  Admin:  http://localhost:8000/admin/"
	@echo "  Supervisor: http://localhost:9001"

run-production: ## Start with production profile (includes Nginx)
	@echo "Starting Milky Way Icecast server with production setup..."
	docker-compose --profile production up -d

stop: ## Stop the container
	@echo "Stopping Milky Way Icecast server..."
	docker-compose down

restart: ## Restart the container
	@echo "Restarting Milky Way Icecast server..."
	docker-compose restart

logs: ## Show logs from all services
	docker-compose logs -f

logs-icecast: ## Show only Icecast logs
	docker exec $(CONTAINER_NAME) tail -f /var/log/icecast2/access.log

logs-liquidsoap: ## Show only Liquidsoap logs
	docker exec $(CONTAINER_NAME) tail -f /var/log/liquidsoap/liquidsoap.log

logs-supervisor: ## Show only Supervisor logs
	docker exec $(CONTAINER_NAME) tail -f /var/log/supervisor/supervisord.log

shell: ## Open shell in running container
	docker exec -it $(CONTAINER_NAME) bash

health: ## Check container health
	@echo "Container health status:"
	@docker inspect $(CONTAINER_NAME) --format='{{.State.Health.Status}}' 2>/dev/null || echo "Container not running"
	@echo ""
	@echo "Service status:"
	@docker exec $(CONTAINER_NAME) supervisorctl status 2>/dev/null || echo "Cannot connect to supervisor"

status: ## Show detailed status
	@echo "=== Container Status ==="
	@docker ps --filter name=$(CONTAINER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "=== Service Status ==="
	@docker exec $(CONTAINER_NAME) supervisorctl status 2>/dev/null || echo "Container not running"
	@echo ""
	@echo "=== Stream Info ==="
	@curl -s http://localhost:8000/admin/stats.xml 2>/dev/null | grep -o '<listeners>[^<]*</listeners>' | sed 's/<[^>]*>//g' | head -1 | xargs -I {} echo "Active listeners: {}" || echo "Stream not accessible"

playlist: ## Generate playlist from MP3 files
	@echo "Generating playlist from MP3 files..."
	@find storage/data -name "*.mp3" -type f | sed 's|^storage/data|/app/storage/data|' > storage/playlist/playlist.m3u
	@echo "Playlist created with $$(wc -l < storage/playlist/playlist.m3u) tracks"

playlist-show: ## Show current playlist
	@echo "Current playlist contents:"
	@cat storage/playlist/playlist.m3u 2>/dev/null || echo "Playlist file not found"

music-info: ## Show information about music files
	@echo "Music directory contents:"
	@find storage/data -name "*.mp3" -type f -exec basename {} \; | sort
	@echo ""
	@echo "Total MP3 files: $$(find storage/data -name "*.mp3" -type f | wc -l)"

clean: ## Remove container and image
	@echo "Cleaning up..."
	docker-compose down -v
	docker rmi $(IMAGE_NAME) 2>/dev/null || true
	@echo "Cleanup complete"

clean-logs: ## Clean log files
	@echo "Cleaning log files..."
	rm -rf logs/*
	@echo "Log files cleaned"

dev: ## Start in development mode with live logs
	@echo "Starting in development mode..."
	docker-compose up --build

# Stream control commands (requires running container)
skip: ## Skip current track
	@echo "Skipping current track..."
	@echo "radio.skip" | nc localhost 1234 2>/dev/null || echo "Cannot connect to Liquidsoap telnet"

current: ## Show currently playing track
	@echo "Currently playing:"
	@echo "radio.current" | nc localhost 1234 2>/dev/null || echo "Cannot connect to Liquidsoap telnet"

telnet: ## Connect to Liquidsoap telnet interface
	@echo "Connecting to Liquidsoap telnet interface..."
	@echo "Type 'help' for available commands, 'exit' to quit"
	telnet localhost 1234

# Testing commands
test-stream: ## Test if stream is accessible
	@echo "Testing stream accessibility..."
	@curl -I http://localhost:8000/stream 2>/dev/null | head -1 || echo "Stream not accessible"

test-admin: ## Test if admin interface is accessible
	@echo "Testing admin interface..."
	@curl -I http://localhost:8000/admin/ 2>/dev/null | head -1 || echo "Admin interface not accessible"

# Installation helpers
install-deps: ## Install required dependencies on host
	@echo "Installing required dependencies..."
	@command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose is required but not installed. Aborting." >&2; exit 1; }
	@echo "All dependencies are installed"

setup: ## Initial setup - build image and create directories
	@echo "Setting up Milky Way Icecast Stream Server..."
	@mkdir -p storage/data storage/playlist logs
	@touch storage/playlist/playlist.m3u
	@make build
	@echo "Setup complete! Add your MP3 files to storage/data/ and run 'make run'"

# Backup and restore
backup: ## Create backup of configuration and playlists
	@echo "Creating backup..."
	@tar -czf backup-$$(date +%Y%m%d-%H%M%S).tar.gz config/ storage/playlist/
	@echo "Backup created: backup-$$(date +%Y%m%d-%H%M%S).tar.gz"

# Quick commands
up: run ## Alias for run
down: stop ## Alias for stop
