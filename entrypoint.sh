#!/usr/bin/env bash
set -e

# Start Xvfb (virtual framebuffer) — Chrome may need a DISPLAY even in headless mode
export DISPLAY=:99
Xvfb :99 -screen 0 1280x720x24 -nolisten tcp &
sleep 0.5
echo "[entrypoint] Xvfb started on DISPLAY=:99"

# Start the Node.js wrapper server (foreground)
exec node src/server.js
