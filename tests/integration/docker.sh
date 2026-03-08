#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="surrealdb-lua-test"
IMAGE="surrealdb/surrealdb:latest"
SURREAL_HOST_PORT="${SURREAL_HOST_PORT:-18000}"
SURREAL_URL="${SURREAL_URL:-http://127.0.0.1:${SURREAL_HOST_PORT}}"
SURREAL_NS="${SURREAL_NS:-sdk}"
SURREAL_DB="${SURREAL_DB:-test}"
SURREAL_USER="${SURREAL_USER:-root}"
SURREAL_PASS="${SURREAL_PASS:-secret}"
SURREAL_AUTH_MODE="${SURREAL_AUTH_MODE:-unauthenticated}"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

cleanup

SURREAL_REQUIRE_SIGNIN="0"
if [ "$SURREAL_AUTH_MODE" = "unauthenticated" ]; then
  docker run -d \
    --name "$CONTAINER_NAME" \
    -e SURREAL_INSECURE_FORWARD_ACCESS_ERRORS=true \
    -p "${SURREAL_HOST_PORT}:8000" \
    "$IMAGE" \
    start --log debug --unauthenticated memory >/dev/null
else
  SURREAL_REQUIRE_SIGNIN="1"
  docker run -d \
    --name "$CONTAINER_NAME" \
    -e SURREAL_INSECURE_FORWARD_ACCESS_ERRORS=true \
    -p "${SURREAL_HOST_PORT}:8000" \
    "$IMAGE" \
    start --log debug --user "$SURREAL_USER" --pass "$SURREAL_PASS" memory >/dev/null
fi

wait_for_ready() {
  local max_attempts=30
  local attempt=1

  while [ "$attempt" -le "$max_attempts" ]; do
    if curl -sSf "$SURREAL_URL/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    attempt=$((attempt + 1))
  done

  return 1
}

if ! wait_for_ready; then
  echo "[integration] SurrealDB did not become healthy in time"
  docker logs "$CONTAINER_NAME" || true
  cleanup
  exit 1
fi

if ! SURREAL_URL="$SURREAL_URL" \
  SURREAL_NS="$SURREAL_NS" \
  SURREAL_DB="$SURREAL_DB" \
  SURREAL_USER="$SURREAL_USER" \
  SURREAL_PASS="$SURREAL_PASS" \
  SURREAL_REQUIRE_SIGNIN="$SURREAL_REQUIRE_SIGNIN" \
  lua tests/integration/test_surreal_live.lua; then
  echo "[integration] test failed, dumping container logs"
  docker logs "$CONTAINER_NAME" || true
  cleanup
  exit 1
fi

cleanup
