#!/usr/bin/env sh
set -eu

# Map environment variables to irkerd CLI flags

args=""

# TLS/SSL
[ -n "${IRKER_CA_FILE:-}" ] && args="$args -c $IRKER_CA_FILE"
[ -n "${IRKER_CERT_FILE:-}" ] && args="$args -e $IRKER_CERT_FILE"

# Logging
LOG_LEVEL="${IRKER_LOG_LEVEL:-}"
if [ -n "$LOG_LEVEL" ]; then
  args="$args -d $LOG_LEVEL"
fi

# Listen addresses (default to all interfaces)
HOST="${IRKER_HOST:-0.0.0.0}"
HOST6="${IRKER_HOST6:-::}"
args="$args -H $HOST -H6 $HOST6"

# Force StreamHandler to stdout/stderr by setting any --log-file value
LOG_FILE="${IRKER_LOG_FILE:--}"
args="$args -l $LOG_FILE"

# Identity and auth
[ -n "${IRKER_NICK:-}" ] && args="$args -n $IRKER_NICK"
if [ -n "${IRKER_PASSWORD_FILE:-}" ]; then
  args="$args -P $IRKER_PASSWORD_FILE"
elif [ -n "${IRKER_PASSWORD:-}" ]; then
  args="$args -p $IRKER_PASSWORD"
fi

# Timeouts
[ -n "${IRKER_TIMEOUT:-}" ] && args="$args -t $IRKER_TIMEOUT"

exec python3 /app/irkerd $args
