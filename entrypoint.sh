#!/usr/bin/env bash
set -e

CDP_PORT="${BROWSER_CDP_PORT:-9222}"
PROFILE_DIR="/tmp/chrome-profile"

# Start Xvfb (virtual framebuffer)
export DISPLAY=:99
Xvfb :99 -screen 0 1280x720x24 -nolisten tcp &
sleep 0.5

clean_locks() {
  rm -f "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonSocket" "$PROFILE_DIR/SingletonCookie"
}

start_chrome() {
  clean_locks
  # Use chromium-wrapper (already has --disable-dev-shm-usage --disable-gpu)
  /usr/local/bin/chromium-wrapper \
    --headless \
    --no-sandbox \
    --disable-setuid-sandbox \
    --disable-software-rasterizer \
    --remote-debugging-address=127.0.0.1 \
    --remote-debugging-port="$CDP_PORT" \
    --no-first-run \
    --no-default-browser-check \
    --user-data-dir="$PROFILE_DIR" \
    about:blank &
  CHROME_PID=$!
}

start_chrome

# Wait for CDP to be ready (up to 15 seconds)
for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${CDP_PORT}/json/version" > /dev/null 2>&1; then
    echo "[entrypoint] Chrome CDP ready on port ${CDP_PORT} (PID ${CHROME_PID})"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "[entrypoint] WARNING: Chrome CDP not responding after 15s — continuing anyway"
  fi
  sleep 0.5
done

# Watchdog: restart Chrome if it crashes (with backoff)
(
  while true; do
    wait "$CHROME_PID" 2>/dev/null || true
    echo "[entrypoint] Chrome exited, restarting in 5s..."
    sleep 5
    start_chrome
  done
) &

# Start the Node.js wrapper server (foreground)
exec node src/server.js
