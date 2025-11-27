# Changelog

All notable changes to this repository and Docker image are recorded in this file.

## Unreleased
- README: Added expanded "Unshackle Environment Dependencies Installation" section. Documented recommended tools and GPU verification commands.
- Dockerfile:
  - Added `mpv` to apt installs.
  - Installed `ffsubsync` (used as a CLI replacement for SubtitleEdit) and added a `subtitleedit` wrapper.
  - Added automated fetch attempts for prebuilt binaries (Bento4/mp4decrypt, CCExtractor) from GitHub releases and placed them into `/app/binaries`.
  - Made UI build conditional safe via `UNSHACKLE_UI_SUPPORT` and added Caddy installation (optional) into the UI build steps.
  - Removed deprecated nginx 8889 transparent proxy (now only ports 80 and 8888 used).
  - Added `GPUSUPPORT` guidance and made GPU package installs tolerant to missing packages.
  - Created wrapper scripts `/usr/local/bin/unshackle` and `/usr/local/bin/dl` more robustly.
- docker-compose.yml: Added `build.args.GPUSUPPORT` example and clarified device mapping notes for Linux/WSL/Windows.

## Notes
- Some prebuilt binary downloads are attempted during build using GitHub Releases API; network access and GitHub rate limits may affect these steps. Failing downloads are non-fatal to the build.
- `ccextractor` and other tools may not be available in Debian `trixie` base repositories — downloads/compiles are the fallback.

If you want these tools pinned to specific release versions (recommended for reproducibility), we can update the Dockerfile to use explicit release tags/URLs.
