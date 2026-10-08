#!/bin/bash
# Stops any running NotchMusic, rebuilds and installs it, and launches the copy in /Applications
set -euo pipefail
cd "$(dirname "$0")"

pkill -x NotchMusic 2>/dev/null || true
./build_app.sh
open /Applications/NotchMusic.app
