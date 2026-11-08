#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

flutter build web --release --no-web-resources-cdn
python3 scripts/create_web_precache_manifest.py build/web
rm -f build/web/flutter_service_worker.js
