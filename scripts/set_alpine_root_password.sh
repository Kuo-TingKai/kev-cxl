#!/usr/bin/env bash
# Set root password on Alpine qcow2 so you can log in as root/alpine.
# Run after fetch_bootable_image.sh if alpine/alpine does not work.
# Requires: Docker (or local virt-customize from libguestfs-tools).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE="${1:-$PROJECT_DIR/alpine-cxl.qcow2}"
PASSWORD="${ALPINE_ROOT_PASSWORD:-alpine}"

if [[ ! -f "$IMAGE" ]]; then
  echo "Error: image not found: $IMAGE"
  echo "Usage: $0 [path/to/alpine-cxl.qcow2]"
  echo "Or run: ./scripts/fetch_bootable_image.sh first."
  exit 1
fi

echo "Setting root password on $IMAGE (password: $PASSWORD) ..."

if command -v virt-customize &>/dev/null; then
  virt-customize -a "$IMAGE" --root-password "password:$PASSWORD"
  echo "Done. Log in as root / $PASSWORD"
  exit 0
fi

if ! command -v docker &>/dev/null; then
  echo "Error: need virt-customize (brew install libguestfs) or Docker."
  echo "Install Docker and run again, or on Linux: apt install libguestfs-tools"
  exit 1
fi

# Prefer Alpine container (smaller/faster); fallback to Fedora
ABS_IMAGE="$(cd "$(dirname "$IMAGE")" && pwd)/$(basename "$IMAGE")"
IMG_NAME="$(basename "$ABS_IMAGE")"

echo "Using Docker (Alpine image ~1–2 min first run; if stuck 5+ min, Ctrl+C and re-run)..."
if docker run --rm \
  -v "$(dirname "$ABS_IMAGE")":/img \
  -w /img \
  alpine:edge \
  sh -c "apk add --no-cache guestfs-tools 2>/dev/null || apk add --no-cache guestfs-tools --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing && virt-customize -a $IMG_NAME --root-password password:$PASSWORD"; then
  echo "Done. Log in as root / $PASSWORD"
  exit 0
fi

echo "Alpine method failed, trying Fedora (first run 5–15 min)..."
docker run --rm \
  -v "$(dirname "$ABS_IMAGE")":/img \
  -w /img \
  fedora:latest \
  bash -c "dnf install -y libguestfs-tools && virt-customize -a $IMG_NAME --root-password password:$PASSWORD"

echo "Done. Log in as root / $PASSWORD"
