# Docker Setup for Karaoke Forever

This repository includes Docker Compose setup for running Karaoke Forever with the AutoLyrixAlignService for automatic vocal removal and lyrics alignment.

## Architecture Overview

**Two independent containers (not nested):**
- **karaoke-forever**: React web app + Express backend (Node.js)
- **AutoLyrixAlignService**: Lyrics alignment API (Node.js + Kaldi + NUS AutoLyrixAlign tools)

Both containers run on a shared Docker network and communicate via HTTP. This is the standard Docker pattern - NOT container-in-container.

## Quick Start

1. **Clone the repository with submodules:**
   ```bash
   git clone --recurse-submodules https://github.com/gazugafan/karaoke-forever.git
   cd karaoke-forever
   ```

   If you already cloned without submodules:
   ```bash
   git submodule update --init --recursive
   ```

2. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env and add your Genius API key (optional, for lyrics fetching)
   # Get a free API key from: https://genius.com/api-clients
   ```

3. **Create required directories:**
   ```bash
   mkdir -p media/karaoke data
   ```

4. **Start the services:**
   ```bash
   source .env  # Load environment variables
   docker compose up -d
   ```

5. **Access Karaoke Forever:**
   - Open your browser to `http://localhost:8090`
   - Create an admin account and start using the app

## Services

### Karaoke Forever (Port 8090)
The main karaoke application with web interface and player.
- Web UI: `http://localhost:8090`
- Database and config persisted in `./data`

### AutoLyrixAlignService (Port 3001)
Service for automatic vocal removal and word-level lyrics alignment. Requires 13-20GB of RAM.
- API: `http://localhost:3001`
- Uses the helvio/kaldi Docker image with NUS AutoLyrixAlign pre-installed
- Processes alignment tasks in a queue (concurrency: 1)

## Configuration

### Environment Variables

Create a `.env` file from `.env.example`:

```bash
# Genius API key for fetching lyrics (optional but recommended)
# Get free key from: https://genius.com/api-clients
export GENIUS_API=your_genius_api_key_here
```

The `.env` file is not tracked in git for security reasons.

### Volumes

- `./media` - Place your karaoke media files here
- `./media/karaoke` - Output directory for generated karaoke files (from AutoLyrixAlignService)
- `./data` - Persistent storage for Karaoke Forever database and configuration

### Docker Compose Customization

Edit `docker-compose.yml` to:
- Change port mappings (lines with `ports:`)
- Adjust memory limits for AutoLyrixAlignService (lines with `memory:`)
- Modify volume mount points

## Enabling Features

### YouTube Search
1. Access Karaoke Forever at `http://localhost:8090`
2. Login with your admin account
3. Go to Account → YouTube preferences
4. Enable YouTube search
5. Optionally add yt-dlp options (e.g., for proxy/cookie support)

### Automatic Lyrics Alignment
1. Configure the Genius API key in `.env`
2. In Karaoke Forever, when downloading from YouTube, select "Align lyrics" option
3. The service will automatically remove vocals and align lyrics to the music

## System Requirements

### Minimum (Karaoke Forever only):
- Docker and Docker Compose
- 4GB RAM
- 2GB disk space

### Full Setup (with AutoLyrixAlignService):
- **RAM**: 16-20GB (13GB minimum)
- **Disk Space**: 16GB initially (13GB after setup)
- **CPU**: Multi-core recommended for faster processing
- **OS**: Linux recommended (tested on Linux; Windows/Mac via Docker Desktop)

## Useful Commands

```bash
# Start services in background
docker compose up -d

# View logs (all services)
docker compose logs -f

# View logs for specific service
docker compose logs -f karaoke-forever
docker compose logs -f karaokeer

# Stop services
docker compose down

# Rebuild after code changes
docker compose up -d --build

# Force rebuild (clear cache)
docker compose build --no-cache && docker compose up -d

# Remove all data (warning: deletes database)
docker compose down -v
```

## Troubleshooting

### Port conflicts
If ports 8090 or 3001 are already in use, edit `docker-compose.yml`:
```yaml
services:
  karaoke-forever:
    ports:
      - "8080:3000"  # Change 8080 to your preferred port
```

### Out of memory
If AutoLyrixAlignService crashes with memory errors:
1. Ensure you have at least 16GB of free RAM
2. Close other applications
3. Adjust memory limits in `docker-compose.yml` if needed

### Submodule not found
If AutoLyrixAlignService directory is empty:
```bash
git submodule update --init --recursive
```

### Database reset between rebuilds
The database persists in `./data` volume and should not be lost on rebuilds. If it is:
```bash
# Verify volume exists
docker volume ls | grep karaoke-forever

# Manually restore from backups if needed
```

## File Structure

```
karaoke-forever/
├── .env.example              # Environment variables template
├── .gitignore               # Git ignore rules
├── Dockerfile               # Main Karaoke Forever container
├── docker-compose.yml       # Container orchestration
├── DOCKER.md               # This file
├── AutoLyrixAlignService/   # Lyrics alignment service (submodule)
│   └── Dockerfile           # AutoLyrixAlignService container
├── media/                   # Volume mount for media files
│   └── karaoke/            # Generated karaoke output
├── data/                    # Volume mount for persistent data
├── build/                   # Webpack build output
├── server/                  # Backend server code
├── src/                     # Frontend React code
└── ...
```

## Advanced Configuration

### Running AutoLyrixAlignService in standalone mode
```bash
cd AutoLyrixAlignService
docker build -t autolyrix-align .
docker run -p 3000:3000 -v /path/to/media:/media/karaoke autolyrix-align
```

### Backup and Restore

**Backup database:**
```bash
cp -r data ./data-backup-$(date +%Y%m%d)
```

**Backup generated karaoke:**
```bash
cp -r media/karaoke ./karaoke-backup-$(date +%Y%m%d)
```

## More Information

- [Karaoke Forever Documentation](https://www.karaoke-forever.com/docs/)
- [AutoLyrixAlignService](AutoLyrixAlignService/README.md)
- [Main README](README.md)
- [NUS AutoLyrixAlign](https://github.com/chitralekha18/AutoLyrixAlign)

## Technical Details: Why This Architecture?

### Docker Base Images (Not Nested Containers)

**Q: Are we running Kaldi (a container) inside Docker (a container)?**  
**A: No!** When we use `FROM helvio/kaldi:latest`, we're using an image as a base layer, not running a container. Docker image inheritance works like this:

```
helvio/kaldi base image
  └─ Contains: Kaldi + AutoLyrixAlign tools pre-installed
     └─ We add: Node.js layer
        └─ We add: AutoLyrixAlignService code
           └─ Final image is built (single container)
```

This is the Docker best practice for including pre-built tools.

### Why Not Build From Scratch?

**Alternative:** Manually install all 500+ dependencies instead of using `helvio/kaldi`
- ❌ Image size: +500 MB
- ❌ Build time: 20+ minutes
- ❌ High failure risk
- ❌ Hard to maintain

**Current approach:** Use proven `helvio/kaldi` base
- ✅ Efficient builds (5 minutes)
- ✅ Reliable (proven by thousands)
- ✅ Smaller images
- ✅ Easy to maintain

### How Services Communicate

```
┌─────────────────────────────────┐
│  Docker Host (Linux/Docker Desktop) │
├─────────────────────────────────┤
│                                 │
│  ┌─────────────────┐  ┌───────────────┐
│  │ Container 1     │=>│ Container 2   │
│  │ karaoke-forever │  │ AutoLyrixAlign│
│  │ Port 8090       │  │ Port 3001     │
│  └─────────────────┘  └───────────────┘
│      Shared Docker Network (http://karaokeer:3000)
│
└─────────────────────────────────┘
```

Both containers are isolated processes but can communicate because they're on the same Docker network.

