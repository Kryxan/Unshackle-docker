# Unshackle Docker

A long long time ago, in a repository just over at github.com/unshackle-dl/unshackle.... the developers removed the docker support from their source. I never used it when it had docker support, but I wanted docker support, so I made this...

This repository contains a comprehensive Dockerfile to build an Unshackle image with the Unshackle UI and all recommended media processing tools pre-installed.

> ## What is unshackle?
>
> unshackle is a fork of [Devine](https://github.com/devine-dl/devine/), a powerful archival tool for downloading movies, TV shows, and music from streaming services. Built with a focus on modularity and extensibility, it provides a robust framework for content acquisition with support for DRM-protected content.
>
> ## Key Features
>
> - 🚀 **Easy Installation** - Simple UV installation
> - 🎥 **Multi-Media Support** - Movies, TV episodes, and music
> - 🛠️ **Built-in Parsers** - DASH/HLS and ISM manifest support
> - 🔒 **DRM Support** - Widevine and PlayReady integration
> - 🌈 **HDR10+DV Hybrid** - Hybrid Dolby Vision injection via [dovi_tool](https://github.com/quietvoid/dovi_tool)
> - 💾 **Flexible Storage** - Local and remote key vaults
> - 👥 **Multi-Profile Auth** - Support for cookies and credentials
> - 🤖 **Smart Naming** - Automatic P2P-style filename structure
> - ⚙️ **Configurable** - YAML-based configuration
> - ❤️ **Open Source** - Fully open-source with community contributions welcome
>
> *Source: [unshackle-dl/unshackle](https://github.com/unshackle-dl/unshackle)*

**UI Status:** ✅ The Unshackle UI is fully functional! This Dockerfile uses a modified fork ([Kryxan/unshackle-ui](https://github.com/Kryxan/unshackle-ui)) that includes:
- Fixed TypeScript strict mode compilation errors
- Working TMDB search functionality (requires API key configuration)
- Integrated web-based terminal with full PTY support
- Improved compatibility and stability

## Features

- **Complete Media Toolkit**: Pre-installed Bento4, dovi_tool, hdr10plus_tool, N_m3u8DL-RE, shaka-packager, and more
- **Working Web UI**: Fully functional UI with TMDB search, download management, and integrated terminal
- **Web Terminal**: Browser-based terminal with xterm.js providing full interactive shell access
- **Multi-GPU Support**: Automatic detection and configuration for Intel, NVIDIA, and AMD GPUs
- **WSL2 Aware**: Automatically adapts GPU driver installation for WSL2 environments
- **Optimized Build**: Uses BuildKit cache mounts for faster iterative builds
- **Wrapper Scripts**: CCExtractor and SubtitleEdit wrappers for seamless integration


## Build Arguments

- `UNSHACKLE_BRANCH` (default: `main`) - Unshackle source branch
- `UNSHACKLE_SOURCE` (default: `https://github.com/unshackle-dl/unshackle`)
- `UI_BRANCH` / `UI_SOURCE` - Web UI source (uses modified fork by default)
- `GPUSUPPORT` (default: `intel`) - Space-separated list of GPU types: `intel`, `nvidia`, `amd`

**Default GPU Support (`intel`):**
- Safe for all systems - includes VA-API drivers that are harmless if no Intel GPU present
- FFmpeg automatically falls back to software encoding if hardware unavailable
- Recommended to keep enabled unless you have specific compatibility concerns

The Dockerfile depends on Debian `slim-trixie` packages and some `non-free` driver components.


## Installed Media Tools

All tools are installed in `/opt/bin/` with symlinks created in `/usr/local/bin/` and `/app/binaries/` for Unshackle compatibility.

### Core Tools (Pre-installed)

**Bento4 SDK** (1.6.0-641)
- Complete SDK with `mp4decrypt`, `mp4encrypt`, `mp4info`, and all utilities
- Binaries: `/opt/bin/mp4decrypt`, `/opt/bin/mp4*`
- SDK files: `/opt/bento4/` (docs, includes, source)
- Python utilities: `mp4-dash.py`, `mp4-hls.py`, etc.

**dovi_tool** (2.3.1)
- Dolby Vision metadata processing
- Location: `/opt/bin/dovi_tool`
- Source: [quietvoid/dovi_tool](https://github.com/quietvoid/dovi_tool)

**hdr10plus_tool** (1.7.1)
- HDR10+ metadata extraction and injection
- Location: `/opt/bin/hdr10plus_tool`
- Source: [quietvoid/hdr10plus_tool](https://github.com/quietvoid/hdr10plus_tool)

**N_m3u8DL-RE**
- Advanced HLS/DASH/ISM downloader
- Location: `/opt/bin/N_m3u8DL-RE`
- Source: [nilaoda/N_m3u8DL-RE](https://github.com/nilaoda/N_m3u8DL-RE)

**shaka-packager**
- Media packaging and DRM encryption tool
- Location: `/opt/bin/packager`
- Source: [shaka-project/shaka-packager](https://github.com/shaka-project/shaka-packager)

**hola-proxy**
- VPN/proxy service client
- Location: `/opt/bin/hola-proxy`
- Source: [Snawoot/hola-proxy](https://github.com/Snawoot/hola-proxy)

**jellyfin-ffmpeg7** (7.1.2-Jellyfin)
- FFmpeg with Jellyfin optimizations
- Binaries: `/usr/local/bin/ffmpeg`, `/usr/local/bin/ffprobe`, `/usr/local/bin/ffplay`
- Hardware acceleration support for Intel VA-API, NVIDIA NVENC, AMD VCN

**Other Tools**
- `aria2c` - Multi-threaded downloader
- `mediainfo` - Media file inspector
- `mkvtoolnix` / `mkvpropedit` - MKV container tools
- `mpv` - Advanced media player
- `caddy` - Modern web server with automatic HTTPS

### Wrapper Scripts

**CCExtractor Wrapper**
- Python wrapper using FFmpeg for CEA-608 closed caption extraction
- Location: `/opt/bin/ccextractor`
- Implementation: `/opt/bin/ccextractor-wrapper.py`
- Compatible with Unshackle's CCExtractor usage
- Exit code 10 when no captions found (matches CCExtractor behavior)

**SubtitleEdit Wrapper**
- Python wrapper for subtitle format conversion
- Location: `/opt/bin/subtitleedit`
- Implementation: `/opt/bin/subtitleedit-wrapper.py`
- Supports: SRT, ASS, VTT, DFXP/TimedText formats
- Uses pysubs2 and pycaption libraries

**Unshackle CLI Wrappers**
- `unshackle` → `uv run unshackle`
- `dl` → `uv run unshackle dl`

So you can run `unshackle` instead of the full `uv run unshackle` command.
     
     
     
     
## Building

**Requirements:**
- Docker with BuildKit support (Docker 18.09+)
- Set `DOCKER_BUILDKIT=1` environment variable

Build with default settings (Intel + NVIDIA GPU support):

```bash
# Linux/WSL
DOCKER_BUILDKIT=1 docker build -t unshackle:latest .

# Windows PowerShell
$env:DOCKER_BUILDKIT=1; docker build -t unshackle:latest .
```

Build with custom GPU support:

```bash
# Intel only
DOCKER_BUILDKIT=1 docker build --build-arg GPUSUPPORT="intel" -t unshackle:latest .

# All GPUs
DOCKER_BUILDKIT=1 docker build --build-arg GPUSUPPORT="intel nvidia amd" -t unshackle:latest .

# No GPU support
DOCKER_BUILDKIT=1 docker build --build-arg GPUSUPPORT="" -t unshackle:latest .
```

## Running

### Docker Run (Basic)

```bash
docker run -d --name unshackle \
  -p 8080:80 -p 8888:8888 \
  unshackle:latest
```

### Docker Run (Full Configuration)

```bash
docker run -d --name unshackle \
  --restart unless-stopped \
  -p 8080:80 -p 8888:8888 \
  -v /path/to/Downloads:/app/downloads \
  -v /path/to/unshackle/temp:/app/temp \
  -v /path/to/unshackle/cookies:/app/unshackle/cookies \
  -v /path/to/unshackle/cache:/app/unshackle/cache \
  -v /path/to/unshackle/WVDs:/app/unshackle/WVDs \
  -v /path/to/unshackle/PRDs:/app/unshackle/PRDs \
  -v /path/to/unshackle.yaml:/app/unshackle/unshackle.yaml \
  -v /path/to/unshackle/services:/app/unshackle/services \
  unshackle:latest
```

### Windows PowerShell Paths

```pwsh
docker run -d --name unshackle `
  -p 8080:80 -p 8888:8888 `
  -v "C:\Users\YourUser\Downloads:/app/downloads" `
  -v "C:\Users\YourUser\unshackle:/app/unshackle" `
  unshackle:latest
```

### Docker Compose

See `docker-compose.yml` for a complete example with BuildKit configuration.

## GPU Support and Hardware Acceleration

The Dockerfile automatically detects WSL2 environments and configures GPU drivers appropriately. The `GPUSUPPORT` build argument accepts a space-separated list of GPU types: `intel`, `nvidia`, `amd`.

**Default:** `GPUSUPPORT="intel"` (safe for all systems)

### FFmpeg Hardware Acceleration

FFmpeg is pre-configured with environment variables for automatic GPU acceleration:

```bash
LIBVA_DRIVER_NAME=iHD              # Intel Media Driver
LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
```

**Using GPU encoding in FFmpeg:**

```bash
# H.264 with VA-API (Intel/AMD)
ffmpeg -i input.mp4 -c:v h264_vaapi -vf 'format=nv12,hwupload' output.mp4

# HEVC with VA-API
ffmpeg -i input.mp4 -c:v hevc_vaapi -vf 'format=nv12,hwupload' output.mp4

# H.264 with NVENC (NVIDIA - requires --gpus all)
ffmpeg -i input.mp4 -c:v h264_nvenc output.mp4

# Check available hardware encoders
ffmpeg -encoders | grep -E '(vaapi|qsv|nvenc|amf)'
```

FFmpeg will automatically fall back to software encoding if hardware acceleration is unavailable.

### GPU Driver Installation Behavior

**Native Linux:**
- Installs full driver stack including kernel-mode components
- NVIDIA: `nvidia-driver`, `nvidia-container-toolkit`
- Intel: `intel-media-va-driver-non-free`, `i965-va-driver-shaders`, VA-API libraries
- AMD: `rocminfo`, `mesa-vulkan-drivers`, firmware

**WSL2 (Auto-detected):**
- Skips kernel drivers (managed by Windows host)
- Installs only user-space libraries
- NVIDIA CUDA toolkit skipped (drivers from Windows)
- Intel/AMD: Installs user-space VA-API and Vulkan libraries only

### Running with GPU Access

**Native Linux:**

```bash
# Intel VA-API
docker run -d --name unshackle \
  --device /dev/dri --group-add video \
  -p 8080:80 -p 8888:8888 \
  unshackle:latest

# NVIDIA NVENC/CUDA
docker run -d --name unshackle \
  --gpus all \
  -p 8080:80 -p 8888:8888 \
  unshackle:latest
```

**Windows/WSL2:**
- `/dev/dri` device not available on Windows Docker Desktop
- GPU access depends on Windows drivers and WSL GPU passthrough
- Run without `--device` or `--gpus` flags for basic operation
- Hardware acceleration may work if Windows GPU drivers support it

### Verification Commands

Inside the running container:

```bash
# Check GPU detection script
docker exec unshackle /opt/bin/check-gpu.sh

# Intel VA-API (Linux only)
docker exec unshackle vainfo

# NVIDIA (requires --gpus all)
docker exec unshackle nvidia-smi

# FFmpeg hardware acceleration codecs
docker exec unshackle ffmpeg -codecs | grep -E "(vaapi|nvenc|qsv)"
```


## Accessing the Container

**Web UI:** `http://localhost:8080`  
**API:** `http://localhost:8888/api/`  
**API Documentation:** `http://localhost:8888/api/docs/`  
**Web Terminal:** Integrated in UI (requires WebSocket support)

### Web UI Configuration

On first launch, configure the UI via Settings page (`http://localhost:8080`):

1. **Unshackle API Configuration:**
   - API URL: `http://localhost:8888` (or your container's network address)
   - API Key: Leave empty for local development (API runs with `--no-key`)

2. **TMDB API Configuration (Required for Search):**
   - Get your free API key at [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api)
   - Enter the key in Settings → TMDB API Key
   - Search functionality requires this to be configured

3. **Web Terminal:**
   - Access via Terminal tab in UI
   - Provides full interactive bash shell with PTY support
   - Terminal resize supported
   - Loads `.bashrc` with aliases and fastfetch banner

**Interactive shell:**

```bash
docker exec -it unshackle bash
```

**Run Unshackle commands:**

```bash
# Check environment (should show 15/16 tools detected)
docker exec unshackle unshackle env check

# Download example
docker exec unshackle dl https://example.com/video.mpd
```

## Notes and Troubleshooting

- The Dockerfile automatically adds `contrib` and `non-free` components to Debian sources for driver packages
- BuildKit is required for cache mounts - builds will be slower without it
- All media tools are verified during the build to have at least 15/16 dependencies available (FFplay is optional)
- SubtitleEdit wrapper uses pysubs2/pycaption instead of the .NET build
- CCExtractor wrapper uses FFmpeg for CEA-608 caption extraction (matches original CLI interface)
- GPU verification script available at `/opt/bin/check-gpu.sh`

**Common Issues:**

- **UI search not working:** Configure TMDB API key in Settings page
- **Terminal not loading:** Ensure WebSocket support is enabled in your browser/proxy
- **Container not accessible:** Check port bindings (8080 for UI, 8888 for API)
- **GPU not detected in WSL2:** This is normal - Windows manages GPU drivers in WSL2
- **Tool detection shows 15/16:** FFplay is missing from jellyfin-ffmpeg7 but is optional

## Architecture

**Directory Structure:**

- `/opt/bin/` - All downloaded tools and wrappers
- `/opt/bento4/` - Bento4 SDK files (docs, includes, source)
- `/usr/local/bin/` - Symlinks to all tools (on PATH)
- `/app/binaries/` - Symlinks for Unshackle compatibility
- `/app/` - Unshackle source and virtual environment
- `/var/www/html/` - Built UI files (served by nginx)

**Services (supervisord):**

- `nginx` - Serves UI on port 80
- `unshackle-api` - REST API on port 8888

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

**Third-Party Components:**

- [Unshackle](https://github.com/unshackle-dl/unshackle) - Apache License 2.0
- [Unshackle UI](https://github.com/Kryxan/unshackle-ui) - MIT License
- All other included tools retain their respective licenses

