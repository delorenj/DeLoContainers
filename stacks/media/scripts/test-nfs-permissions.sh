#!/bin/bash
# Comprehensive NFS permission validation helper
# Usage: ./test-nfs-permissions.sh [container_name]

set -euo pipefail

CONTAINER=${1:-qbittorrent}
HOST_MOUNT=${HOST_MOUNT:-/mnt/video}
NFS_SOURCE=${NFS_SOURCE:-192.168.1.50:/volume1/video}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_STACK_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$MEDIA_STACK_DIR/.env"

EXPECTED_UID=1000
EXPECTED_GID=1000

if [ -f "$ENV_FILE" ]; then
  ENV_PUID=$(grep -E '^PUID=' "$ENV_FILE" | tail -n 1 | cut -d '=' -f2 | tr -d '\r' | xargs)
  ENV_PGID=$(grep -E '^PGID=' "$ENV_FILE" | tail -n 1 | cut -d '=' -f2 | tr -d '\r' | xargs)

  if [ -n "$ENV_PUID" ]; then
    EXPECTED_UID="$ENV_PUID"
  fi

  if [ -n "$ENV_PGID" ]; then
    EXPECTED_GID="$ENV_PGID"
  fi
fi

echo "🔍 Testing NFS mount permissions for $CONTAINER"
echo "================================================="
echo "Expecting UID:GID -> ${EXPECTED_UID}:${EXPECTED_GID}"

FAILED=0

# Check container status early so we can short-circuit if needed
if ! docker compose ps "$CONTAINER" | grep -q "Up"; then
  echo "❌ Container $CONTAINER is not running"
  exit 1
fi

echo "✅ Container $CONTAINER is running"

# Validate host mount status
echo ""
echo "🔧 Host mount validation ($HOST_MOUNT)"

if mountpoint -q "$HOST_MOUNT"; then
  echo "✅ Host mount is active"
  HOST_OWNER=$(stat -c "%u:%g" "$HOST_MOUNT" 2>/dev/null || true)
  if [ -z "$HOST_OWNER" ]; then
    echo "❌ Unable to determine host ownership for $HOST_MOUNT"
    FAILED=1
  elif [ "$HOST_OWNER" = "${EXPECTED_UID}:${EXPECTED_GID}" ]; then
    echo "✅ Host ownership matches expected ${EXPECTED_UID}:${EXPECTED_GID}"
  else
    echo "❌ Host ownership is $HOST_OWNER (expected ${EXPECTED_UID}:${EXPECTED_GID})"
    echo ""
    echo "🔧 REMEDIATION STEPS:"
    echo "1. Server-side (Synology):"
    echo "   - Run: ./scripts/synology-nfs-config.sh (on NAS)"
    echo "   - Or manually: edit DSM > Control Panel > Shared Folder > NFS Permissions"
    echo "   - Set: anonuid=${EXPECTED_UID} anongid=${EXPECTED_GID}"
    echo ""
    echo "2. Client-side (this machine):"
    echo "   - Run: ./scripts/fix-nfs-client.sh"
    echo "   - Or manually: add uid=${EXPECTED_UID},gid=${EXPECTED_GID} to mount options"
    echo ""
    FAILED=1
  fi
else
  echo "❌ Host mount is not active"
  echo "   Remount with: sudo mount -t nfs4 -o rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,_netdev $NFS_SOURCE $HOST_MOUNT"
  FAILED=1
fi

# Container-level checks
echo ""
echo "📦 Container mount validation (/emma)"

if docker exec "$CONTAINER" test -d /emma >/dev/null 2>&1; then
  echo "✅ /emma mount is visible inside container"
else
  echo "❌ /emma mount not present inside container"
  FAILED=1
fi

if docker exec "$CONTAINER" ls -la /emma >/dev/null 2>&1; then
  echo "✅ Read permission test passed"
elif docker exec "$CONTAINER" ls /emma >/dev/null 2>&1; then
  echo "✅ Read permission test passed (basic listing)"
else
  echo "❌ Read permission test failed"
  FAILED=1
fi

if docker exec "$CONTAINER" touch "/emma/test-write-${CONTAINER}.txt" >/dev/null 2>&1; then
  echo "✅ Write permission test passed"
  docker exec "$CONTAINER" rm "/emma/test-write-${CONTAINER}.txt" >/dev/null 2>&1 || true
else
  echo "❌ Write permission test failed - NFS export is read-only"
  echo "   Ensure rw permissions on NAS shared folder and export"
  FAILED=1
fi

CONTAINER_OWNER=$(docker exec "$CONTAINER" stat -c "%u:%g" /emma 2>/dev/null || true)
if [ -z "$CONTAINER_OWNER" ]; then
  echo "❌ Unable to determine container ownership for /emma"
  FAILED=1
elif [ "$CONTAINER_OWNER" = "${EXPECTED_UID}:${EXPECTED_GID}" ]; then
  echo "✅ Container ownership matches expected ${EXPECTED_UID}:${EXPECTED_GID}"
else
  echo "❌ Container sees /emma as $CONTAINER_OWNER (expected ${EXPECTED_UID}:${EXPECTED_GID})"
  echo ""
  echo "🔧 REMEDIATION STEPS:"
  echo "1. Check server NFS export: anonuid=${EXPECTED_UID} anongid=${EXPECTED_GID}"
  echo "2. Check client mount options: uid=${EXPECTED_UID},gid=${EXPECTED_GID}"
  echo "3. Run: ./scripts/fix-nfs-client.sh"
  echo ""
  FAILED=1
fi

echo ""

if [ "$FAILED" -eq 0 ]; then
  echo "🎉 NFS mount is fully functional!"
  echo "   Container: $CONTAINER"
  echo "   Host mount: $HOST_MOUNT"
  echo "   NFS source: $NFS_SOURCE"
  exit 0
else
  echo "⚠️  One or more permission checks failed"
  exit 1
fi
