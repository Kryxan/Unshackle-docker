# Unshackle Dockerfile

A long long time ago, in a repository just over at github.com/unshackle-dl/unshackle.... the developers removed the docker support from their source. I wanted it back, so I made this...

This repository contains a standalone copy of the `Dockerfile` used to build an Unshackle image with the Unshackle UI. The Unshackle UI is currently in development and does not work in it's current state.

I have created a modified version of the UI and this Dockerfile references that. It also only partially works, and required some modifications to the backend Unshackle. Due to unforseen consequences of those changes, I am not including my changes to the Unshackle source. 

Notes & usage:
- The Dockerfile uses build ARGs to reference the Unshackle sources:
  - `UNSHACKLE_BRANCH` (default: `main`)
  - `UNSHACKLE_SOURCE` (default: `https://github.com/unshackle-dl/unshackle`)
  - `UI_BRANCH` / `UI_SOURCE` for the web UI

- The Dockerfile depends on Debian `slim-trixie` packages and some `non-free` driver components. I'm running this on a system with a single integrated intel gpu. Edit the dockerfile or ommit the the drivers if you do not need/want them.


### Wrapper Scripts
 The following container wrapper scripts are created:    
 - `unshackle` > `uv run unshackle`    
 - `dl` > `uv run unshackle dl`

 So you can run `unshackle` instead of the full `uv run unshackle`.
     
     
     
     
-----
# Building
Build example:

```bash
docker build -t unshackle:latest .
```

After build run with Docker:

 ```bash
 docker run -d --name unshackle \
   --restart unless-stopped \
   -p 8080:80 -p 8888:8888 \
   -v yourpath/Downloads:/app/downloads \
   -v yourpath/unshackle/temp:/app/temp \
   -v yourpath/unshackle/cookies:/app/unshackle/cookies \
   -v yourpath/unshackle/cache:/app/unshackle/cache \
   -v yourpath/unshackle/WVDs:/app/unshackle/WVDs \
   -v yourpath/unshackle/PRDs:/app/unshackle/PRDs \
   -v yourpath/unshackle/unshackle.yaml:/app/unshackle/unshackle.yaml \
   -v yourpath/unshackle/services:/app/unshackle/services \
   --device /dev/dri --group-add video \
   --env PYTHONUNBUFFERED=1
   unshackle:latest

```

Or use docker-compose (example):

```bash
docker compose up -d --build
```
