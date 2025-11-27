#!/usr/bin/env bash
set -e
curl -f http://localhost:8888/api/health || exit 1
