# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-11-27

### Added

- **Automated Update Script**: `unshackle-update.sh` for managing updates
  - Downloads latest Unshackle and UI repositories
  - Copies custom API files from UI to Unshackle core
  - Builds and deploys UI automatically
  - Available at `/opt/bin/unshackle-update.sh`
- **Dynamic Bash Prompt**: Shows project name and version from pyproject.toml
  - Format: `unshackle (2.1.0): /app #`
  - Color-coded: green for name, yellow for version
  - Falls back to standard prompt if pyproject.toml unavailable

### Changed

- **Dockerfile Optimization**: Replaced git clone commands with update script
  - Single script manages both Unshackle and UI downloads
  - Update script called twice: once for source, once for UI build
  - Improved build reproducibility and maintainability
- **GPU Defaults**: Changed default `GPUSUPPORT` from "intel nvidia" to "intel"
  - Safer for all systems (harmless if no Intel GPU present)
  - Universal compatibility across different hardware configurations
- **FFmpeg Environment**: Added GPU acceleration environment variables
  - `LIBVA_DRIVER_NAME=iHD` for Intel Quick Sync
  - `LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri`
  - Automatic fallback to software encoding if GPU unavailable

### Fixed

- **TypeScript Compilation**: Fixed all TypeScript strict mode errors in UI fork
  - Deleted obsolete `connection-status-indicator-old.tsx` causing syntax errors
  - Added null checks in `downloads-store.ts` and `store-manager.ts`
- **SubtitleEdit Detection**: Created capitalized symlinks for Unshackle compatibility
  - Binary is `subtitleedit` (lowercase) but Unshackle expects `SubtitleEdit` (capitalized)
  - Tool detection now shows 15/16 (only optional FFplay missing)
- **dircolors Warning**: Fixed "no SHELL environment variable" warning in `.bashrc`
  - Added `export SHELL=/bin/bash` to bashrc
- **Line Endings**: Added sed normalization for `.bashrc` to handle potential CRLF issues
- **API Integration**: Custom routes.py from UI repository now properly integrated
  - API files copied from `unshackle-ui/api/` to `/app/unshackle/core/api/`
  - Enables UI-driven API customization and enhancements

### Documentation

- Updated README with terminal integration details
- Added terminal configuration and troubleshooting sections
- Enhanced Web UI access documentation with WebSocket information

## [1.0.2] - 2025-12-05

### Added

- **StabbedByBrick Services**: Added StabbedByBrick's collection of non-premium services for Unshackle (https://github.com/stabbedbybrick/services). These services are included as part of the update process and can be selectively applied by the administrator via the `unshackle-update.sh` script to avoid overwriting custom local service modifications.


## [1.0.0] - 2025-11-27

### Added

- Complete refactored release of Unshackle Docker with comprehensive media toolkit
- Multi-GPU support (Intel, NVIDIA, AMD) with automatic WSL2 detection
- FFmpeg hardware acceleration with VA-API, QSV, NVENC, AMF support
- Complete media processing tools:
  - Bento4 SDK (mp4decrypt, mp4encrypt, mp4info)
  - dovi_tool for Dolby Vision metadata
  - hdr10plus_tool for HDR10+ metadata
  - N_m3u8DL-RE for HLS/DASH/ISM downloads
  - shaka-packager for media packaging
  - hola-proxy for VPN/proxy services
  - jellyfin-ffmpeg7 with hardware acceleration
  - aria2c, mediainfo, mkvtoolnix, mpv, caddy
- Wrapper scripts:
  - CCExtractor wrapper using FFmpeg for CEA-608 captions
  - SubtitleEdit wrapper for subtitle format conversion
  - Unshackle CLI wrappers for easier command access
- Modified Unshackle UI fork with TypeScript fixes
- TMDB search integration (requires API key)
- Docker BuildKit optimization with cache mounts
- Comprehensive README with build instructions and troubleshooting
- GPU verification script at `/opt/bin/check-gpu.sh`
- Health check endpoint
- Supervisor-managed services (nginx + unshackle-api)
- CORS middleware for web UI access

### Technical Details

- Base image: `python:slim-trixie` (Debian trixie)
- FFmpeg version: 7.1.2-Jellyfin
- Bento4 version: 1.6.0-641
- dovi_tool version: 2.3.1
- hdr10plus_tool version: 1.7.1
- Ports exposed: 80 (UI), 8888 (API)
- Default GPU support: Intel (safe for all systems)


## [0.0.0] - 2025-11-23

- initial build of Dockerfile with UI