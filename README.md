# Milky Way Icecast Stream Server

A production-ready Docker setup for streaming MP3 files using Icecast2 and Liquidsoap.

## Features

- **Icecast2** server for audio streaming
- **Liquidsoap** for audio processing and playlist management
- **Supervisor** for process management
- **Docker** containerization for easy deployment
- **Health checks** and monitoring
- **Crossfade** between tracks
- **Audio normalization** and silence detection
- **Playlist support** (M3U files)
- **Telnet interface** for remote control

## Directory Structure

```
mw-icecast-stream/
├── Dockerfile
├── docker-compose.yml
├── start.sh
├── config/
│   ├── icecast.xml          # Icecast server configuration
│   ├── liquidsoap.liq       # Liquidsoap audio processing script
│   └── supervisord.conf     # Process management configuration
├── storage/
│   ├── data/               # MP3 files directory
│   │   └── *.mp3
│   └── playlist/           # Playlist files
│       └── playlist.m3u
└── logs/                   # Application logs
```

## Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd mw-icecast-stream
```

### 2. Add Your Music

Copy your MP3 files to the `storage/data/` directory:

```bash
cp /path/to/your/music/*.mp3 storage/data/
```

### 3. Create Playlist (Optional)

Create a custom playlist in `storage/playlist/playlist.m3u`:

```bash
echo "/app/storage/data/song1.mp3" > storage/playlist/playlist.m3u
echo "/app/storage/data/song2.mp3" >> storage/playlist/playlist.m3u
```

### 4. Build and Run

#### Using Docker Compose (Recommended)

```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

#### Using Docker directly

```bash
# Build the image
docker build -t milky-way-icecast .

# Run the container
docker run -d \
  --name milky-way-icecast \
  -p 8000:8000 \
  -p 1234:1234 \
  -p 9001:9001 \
  -v $(pwd)/storage/data:/app/storage/data:ro \
  -v $(pwd)/storage/playlist:/app/storage/playlist:ro \
  -v $(pwd)/logs:/var/log/icecast2 \
  milky-way-icecast
```

## Access Points

Once running, you can access:

- **Stream URL**: http://localhost:8000/stream
- **Icecast Admin**: http://localhost:8000/admin/
- **Supervisor Web UI**: http://localhost:9001
- **Liquidsoap Telnet**: `telnet localhost 1234`

## Default Credentials

⚠️ **Change these in production!**

- **Icecast Admin**: admin / changeme123
- **Icecast Source**: source / changeme123
- **Supervisor**: admin / changeme123

## Configuration

### Icecast Settings

Edit `config/icecast.xml` to customize:

- Server name and description
- Maximum listeners
- Passwords
- Mount points
- Logging levels

### Liquidsoap Settings

Edit `config/liquidsoap.liq` to customize:

- Audio quality (bitrate, sample rate)
- Crossfade duration
- Normalization levels
- Playlist behavior

## Remote Control

### Liquidsoap Telnet Commands

Connect to the Liquidsoap telnet interface:

```bash
telnet localhost 1234
```

Available commands:

```
help                    # Show all commands
radio.skip              # Skip current track
radio.current           # Show current playing track
exit                    # Close telnet session
```

### Supervisor Control

Access the web interface at http://localhost:9001 or use command line:

```bash
# Enter the container
docker exec -it milky-way-icecast bash

# Control services
supervisorctl status
supervisorctl restart icecast
supervisorctl restart liquidsoap
```

## Monitoring

### Health Checks

The container includes health checks that verify:

- Icecast server is responding
- Services are running properly

Check health status:

```bash
docker ps  # Shows health status
docker inspect milky-way-icecast | grep Health -A 10
```

### Logs

View logs in real-time:

```bash
# All services
docker-compose logs -f

# Specific service logs
docker exec milky-way-icecast tail -f /var/log/icecast2/access.log
docker exec milky-way-icecast tail -f /var/log/liquidsoap/liquidsoap.log
docker exec milky-way-icecast tail -f /var/log/supervisor/supervisord.log
```

## Production Deployment

### Security Considerations

1. **Change default passwords** in all configuration files
2. **Use HTTPS** with a reverse proxy (Nginx included in docker-compose)
3. **Firewall configuration** - only expose necessary ports
4. **Regular updates** of base images and dependencies

### Performance Tuning

1. **Adjust client limits** in `icecast.xml` based on your server capacity
2. **Configure audio quality** in `liquidsoap.liq` based on bandwidth
3. **Monitor resource usage** and scale accordingly

### SSL/HTTPS Setup

Enable the Nginx reverse proxy:

```bash
# Run with production profile
docker-compose --profile production up -d
```

Configure SSL certificates in `nginx/ssl/` directory.

## Troubleshooting

### Common Issues

1. **No audio stream**
   - Check if MP3 files exist in `/app/storage/data`
   - Verify playlist file format
   - Check Liquidsoap logs for errors

2. **Connection refused**
   - Verify ports are not blocked by firewall
   - Check if services are running: `supervisorctl status`

3. **Permission errors**
   - Ensure proper file permissions on mounted volumes
   - Check container user permissions

### Debug Mode

Run container with debug output:

```bash
docker run --rm -it \
  -p 8000:8000 \
  -v $(pwd)/storage:/app/storage \
  milky-way-icecast \
  bash
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

For issues and questions:

- Check the logs first
- Review configuration files
- Open an issue with detailed error information
