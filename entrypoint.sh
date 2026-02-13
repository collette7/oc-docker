#!/usr/bin/env bash
set -e

CHROME_BIN="/root/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome"
CDP_PORT="${BROWSER_CDP_PORT:-9222}"

# Start Xvfb (virtual framebuffer) — some Chromium builds need a DISPLAY even in headless mode
export DISPLAY=:99
Xvfb :99 -screen 0 1280x720x24 -nolisten tcp &
XVFB_PID=$!
sleep 0.5

# Start Chromium in headless mode with CDP listening
"$CHROME_BIN" \
  --headless=new \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-software-rasterizer \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port="$CDP_PORT" \
  --no-first-run \
  --no-default-browser-check \
  --user-data-dir=/tmp/chrome-profile \
  about:blank &
CHROME_PID=$!

# Wait for CDP to be ready (up to 10 seconds)
for i in $(seq 1 20); do
  if curl -sf "http://127.0.0.1:${CDP_PORT}/json/version" > /dev/null 2>&1; then
    echo "[entrypoint] Chrome CDP ready on port ${CDP_PORT} (PID ${CHROME_PID})"
    break
  fi
  if [ "$i" -eq 20 ]; then
    echo "[entrypoint] WARNING: Chrome CDP not responding after 10s — continuing anyway"
  fi
  sleep 0.5
done

# Ensure Chrome restarts if it crashes
(
  while true; do
    wait "$CHROME_PID" 2>/dev/null || true
    echo "[entrypoint] Chrome exited, restarting..."
    sleep 1
    "$CHROME_BIN" \
      --headless=new \
      --no-sandbox \
      --disable-dev-shm-usage \
      --disable-gpu \
      --disable-software-rasterizer \
      --remote-debugging-address=127.0.0.1 \
      --remote-debugging-port="$CDP_PORT" \
      --no-first-run \
      --no-default-browser-check \
      --user-data-dir=/tmp/chrome-profile \
      about:blank &
    CHROME_PID=$!
  done
) &

# Start the Node.js wrapper server (foreground)
exec node src/server.js
