#!/usr/bin/env bash
set -e

# ---------------------------------------------------------------------------
# 1. Virtual framebuffer — Chrome may need a DISPLAY even in headless mode
# ---------------------------------------------------------------------------
export DISPLAY=:99
Xvfb :99 -screen 0 1280x720x24 -nolisten tcp &
sleep 0.5
echo "[entrypoint] Xvfb started on DISPLAY=:99"

# ---------------------------------------------------------------------------
# 2. Pre-launch Chrome so OpenClaw can attach via CDP (attachOnly mode).
#
#    OpenClaw's managed launch has a hardcoded 15 s timeout that is too tight
#    for Railway's resource-constrained containers.  By starting Chrome here
#    we give it unlimited time with matching flags (--headless=new).
# ---------------------------------------------------------------------------
CHROME_BIN="/root/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome"
CHROME_DATA="/data/.clawdbot/browser/openclaw/user-data"
CDP_PORT=18800

if [ -x "$CHROME_BIN" ]; then
  mkdir -p "$CHROME_DATA"

  # Remove stale lock files left by a previous container on the persistent volume
  rm -f "$CHROME_DATA/SingletonLock" "$CHROME_DATA/SingletonSocket" "$CHROME_DATA/SingletonCookie"

  "$CHROME_BIN" \
    --headless=new \
    --no-sandbox \
    --disable-setuid-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --disable-background-networking \
    --disable-sync \
    --disable-component-update \
    --disable-features=Translate,MediaRouter \
    --disable-session-crashed-bubble \
    --hide-crash-restore-bubble \
    --disable-blink-features=AutomationControlled \
    --no-first-run \
    --no-default-browser-check \
    --password-store=basic \
    --remote-debugging-port="$CDP_PORT" \
    --remote-allow-origins=* \
    --user-data-dir="$CHROME_DATA" \
    about:blank &

  CHROME_PID=$!
  echo "[entrypoint] Chrome launched (pid $CHROME_PID), waiting for CDP on port $CDP_PORT…"

  # Poll until Chrome's CDP endpoint responds (up to 60 s)
  READY=0
  for i in $(seq 1 120); do
    if curl -sf "http://127.0.0.1:$CDP_PORT/json/version" >/dev/null 2>&1; then
      READY=1
      echo "[entrypoint] Chrome CDP ready after ~$((i / 2))s"
      break
    fi
    sleep 0.5
  done

  if [ "$READY" -eq 0 ]; then
    echo "[entrypoint] WARNING: Chrome CDP did not become ready in 60 s — continuing anyway"
  fi
else
  echo "[entrypoint] WARNING: Chrome binary not found at $CHROME_BIN — skipping pre-launch"
fi

# ---------------------------------------------------------------------------
# 3. Start the Node.js wrapper server (foreground)
# ---------------------------------------------------------------------------
exec node src/server.js
