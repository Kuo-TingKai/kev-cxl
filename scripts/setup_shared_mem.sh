#!/usr/bin/env bash
# Create shared memory file for multi-host CXL simulation.
# Run this once before starting Host A and Host B.

set -e
# On macOS there is no /dev/shm; use /tmp or env SHARED_MEM
if [[ -d /dev/shm ]]; then
  DEFAULT_SHARED="/dev/shm/cxl_shared_mem"
else
  DEFAULT_SHARED="${TMPDIR:-/tmp}/cxl_shared_mem"
fi
SHARED_MEM="${SHARED_MEM:-$DEFAULT_SHARED}"
SIZE="${CXL_SHARED_SIZE:-2G}"

if [[ -f "$SHARED_MEM" ]]; then
  echo "Shared memory file already exists: $SHARED_MEM"
  ls -la "$SHARED_MEM"
  exit 0
fi

echo "Creating shared memory file: $SHARED_MEM ($SIZE)"
if command -v fallocate &>/dev/null; then
  fallocate -l "$SIZE" "$SHARED_MEM"
else
  # macOS: no fallocate, use dd
  case "$SIZE" in
    *G) BLOCKS=$(( ${SIZE%G} * 1024 * 1024 )) ;;
    *M) BLOCKS=$(( ${SIZE%M} * 1024 )) ;;
    *) BLOCKS=$SIZE ;;
  esac
  dd if=/dev/zero of="$SHARED_MEM" bs=1024 count=$BLOCKS 2>/dev/null
fi
chmod 600 "$SHARED_MEM"
ls -la "$SHARED_MEM"
echo "Done. Start Host A and Host B in two terminals."
