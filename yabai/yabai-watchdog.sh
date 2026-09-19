#!/bin/bash
# yabai hang watchdog: if IPC stops responding, hard-restart the daemon.
# Designed to be run by LaunchAgent every few minutes, or as a long loop.

set -u

YABAI="${YABAI_PATH:-/opt/homebrew/bin/yabai}"
TIMEOUT_SEC="${YABAI_WATCHDOG_TIMEOUT:-3}"
LOG="${YABAI_WATCHDOG_LOG:-/tmp/yabai_watchdog.log}"
LOCK="/tmp/yabai_${USER}.lock"
SOCK="/tmp/yabai_${USER}.socket"
SA_SOCK="/tmp/yabai-sa_${USER}.socket"
COOLDOWN_FILE="/tmp/yabai_watchdog_cooldown"
COOLDOWN_SEC="${YABAI_WATCHDOG_COOLDOWN:-120}"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"
}

alive_ipc() {
  # Returns 0 if yabai answers a simple query within TIMEOUT_SEC.
  if ! command -v "$YABAI" >/dev/null 2>&1 && [ ! -x "$YABAI" ]; then
    return 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$YABAI" "$TIMEOUT_SEC" <<'PY'
import subprocess, sys
yabai, timeout = sys.argv[1], float(sys.argv[2])
try:
    r = subprocess.run(
        [yabai, "-m", "query", "--spaces"],
        capture_output=True, timeout=timeout,
    )
    sys.exit(0 if r.returncode == 0 and r.stdout else 1)
except Exception:
    sys.exit(1)
PY
    return $?
  fi
  # Fallback without python (no hard timeout)
  out="$("$YABAI" -m query --spaces 2>/dev/null)" || return 1
  [ -n "$out" ]
}

in_cooldown() {
  [ -f "$COOLDOWN_FILE" ] || return 1
  last=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  [ $((now - last)) -lt "$COOLDOWN_SEC" ]
}

restart_yabai() {
  log "hang detected — restarting yabai"
  date +%s >"$COOLDOWN_FILE"
  uid="$(id -u)"

  # Kill daemon + any stuck clients waiting on the socket
  /usr/bin/pkill -9 -x yabai 2>/dev/null || true
  sleep 0.4
  rm -f "$LOCK" "$SOCK" "$SA_SOCK"

  # Prefer official LaunchAgent (com.asmvik.yabai) — avoid double agents
  if launchctl kickstart -k "gui/${uid}/com.asmvik.yabai" >/dev/null 2>&1; then
    log "kickstart com.asmvik.yabai ok"
  elif "$YABAI" --restart-service >/dev/null 2>&1; then
    log "restart-service ok"
  elif "$YABAI" --start-service >/dev/null 2>&1; then
    log "start-service ok"
  else
    nohup "$YABAI" >/dev/null 2>&1 &
    log "direct launch pid=$!"
  fi

  sleep 1.2
  if alive_ipc; then
    log "yabai healthy after restart"
    return 0
  fi
  log "yabai still unhealthy after restart"
  return 1
}

# If no process, let LaunchAgent/service own startup — only recover hangs/zombies.
if ! /usr/bin/pgrep -x yabai >/dev/null 2>&1; then
  # Quiet when service is intentionally stopped; try once if socket/lock stale.
  if [ -e "$LOCK" ] || [ -e "$SOCK" ]; then
    if ! in_cooldown; then
      log "stale lock/socket without process — cleaning"
      rm -f "$LOCK" "$SOCK" "$SA_SOCK"
      "$YABAI" --start-service >/dev/null 2>&1 || true
    fi
  fi
  exit 0
fi

if alive_ipc; then
  exit 0
fi

if in_cooldown; then
  log "unhealthy but in cooldown — skip"
  exit 0
fi

restart_yabai
exit $?
