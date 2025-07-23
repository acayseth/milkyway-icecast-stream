#!/usr/bin/liquidsoap

# Ultra-simple Liquidsoap 2.0.2 configuration for Ubuntu 22.04
# Minimal working setup for MP3 streaming

# Allow running as root
set("init.allow_root", true)

# Basic settings
set("log.level", 4)
set("log.file", true)
set("log.file.path", "/var/log/liquidsoap/liquidsoap.log")

# Audio settings
set("frame.audio.samplerate", 44100)
set("frame.audio.channels", 2)

# Enable telnet server
set("server.telnet", true)
set("server.telnet.bind_addr", "0.0.0.0")
set("server.telnet.port", 1234)

# Create music source from directory
radio = playlist(mode="randomize", reload=3600, "/app/storage/data")

# Make source infallible by adding fallback to blank
radio = fallback([radio, blank()])

# Add basic audio processing (no crossfade for now to avoid issues)
radio = normalize(radio)

# Output to Icecast
output.icecast(
  %mp3(bitrate=128),
  host="localhost",
  port=8000,
  password="changeme123",
  mount="stream",
  name="Milky Way Radio",
  description="MP3 Streaming Radio",
  genre="Various",
  url="http://localhost:8000",
  radio
)

# Simple telnet commands
def skip(_) =
  source.skip(radio)
  "Track skipped"
end

server.register(namespace="", description="Skip current track", usage="skip", "skip", skip)

log("Liquidsoap started")
