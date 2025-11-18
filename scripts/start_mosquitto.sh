#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT="${SCRIPT_DIR}/.."
COMPOSE_FILE="${REPO_ROOT}/integration_tests/docker/mosquitto/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "docker-compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

# Detect Docker Compose command (v2 plugin vs legacy binary)
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Docker Compose not found. Install Docker Desktop or docker-compose." >&2
  exit 127
fi

"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" up -d
sleep 2
