#!/usr/bin/env bash
# Download a minimal bootable x86_64 Linux qcow2 for CXL testing.
# Run once; then use: export QEMU_IMAGE=$PWD/alpine-cxl.qcow2

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="${1:-$PROJECT_DIR/alpine-cxl.qcow2}"

# Alpine generic cloud image (BIOS, tiny ~114MB). Adjust version if URL 404.
ALPINE_URL="https://dev.alpinelinux.org/~tomalok/alpine-cloud-images/v3.21/generic/x86_64/generic_alpine-3.21.6-x86_64-bios-tiny-r0.qcow2"
# Fallback: older path pattern
ALPINE_URL_ALT="https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/native/alpine-virt-3.18.4-x86_64.qcow2"

if [[ -f "$OUTPUT" ]]; then
  echo "Already exists: $OUTPUT"
  echo "Use: export QEMU_IMAGE=$OUTPUT"
  exit 0
fi

echo "Downloading bootable Alpine Linux image to $OUTPUT ..."
if command -v curl &>/dev/null; then
  if curl -fSL -o "$OUTPUT" "$ALPINE_URL" 2>/dev/null; then
    echo "Done. Use: export QEMU_IMAGE=$OUTPUT"
    exit 0
  fi
  echo "First URL failed, trying fallback..."
  curl -fSL -o "$OUTPUT" "$ALPINE_URL_ALT" || true
elif command -v wget &>/dev/null; then
  if wget -q -O "$OUTPUT" "$ALPINE_URL" 2>/dev/null; then
    echo "Done. Use: export QEMU_IMAGE=$OUTPUT"
    exit 0
  fi
  wget -q -O "$OUTPUT" "$ALPINE_URL_ALT" || true
else
  echo "Error: need curl or wget"
  exit 1
fi

if [[ -f "$OUTPUT" ]] && [[ -s "$OUTPUT" ]]; then
  echo "Done. Use: export QEMU_IMAGE=$OUTPUT"
else
  echo "Download failed. Get a bootable qcow2 manually, e.g.:"
  echo "  Alpine: https://alpinelinux.org/cloud/"
  echo "  Or use option 2 in README: boot from ISO and install to your empty disk."
  exit 1
fi
