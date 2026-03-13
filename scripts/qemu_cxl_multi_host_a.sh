#!/usr/bin/env bash
# Host A: multi-host shared CXL storage (SSH forwarded to 2222).
# Run setup_shared_mem.sh first; then run this and qemu_cxl_multi_host_b.sh in two terminals.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# macOS: no /dev/shm; use SHARED_MEM from setup_shared_mem.sh or /tmp
if [[ -z "$SHARED_MEM" ]]; then
  [[ -d /dev/shm ]] && SHARED_MEM="/dev/shm/cxl_shared_mem" || SHARED_MEM="${TMPDIR:-/tmp}/cxl_shared_mem"
fi
IMAGE="${QEMU_IMAGE_A:-$PROJECT_DIR/host_a.qcow2}"

ACCEL="tcg"
if [[ "$(uname -m)" == "x86_64" ]] && [[ "$(uname -s)" == "Linux" ]]; then
  if grep -q vmx /proc/cpuinfo 2>/dev/null || grep -q svm /proc/cpuinfo 2>/dev/null; then
    ACCEL="kvm"
  fi
fi

if [[ ! -f "$SHARED_MEM" ]]; then
  echo "Error: Shared memory not found. Run: ./scripts/setup_shared_mem.sh"
  exit 1
fi
if [[ ! -f "$IMAGE" ]]; then
  echo "Error: Image not found: $IMAGE (set QEMU_IMAGE_A or create host_a.qcow2)"
  exit 1
fi

echo "Starting Host A (CXL shared, hostfwd=tcp::2222-:22)..."
exec qemu-system-x86_64 \
  -m 4G -smp 4 \
  -machine "q35,cxl=on,accel=$ACCEL" \
  -object memory-backend-file,id=cxl-mem0,mem-path="$SHARED_MEM",size=2G,share=on \
  -device pxb-cxl,id=cxl.0,bus=pcie.0,bus_nr=52 \
  -device cxl-rp,id=rp0,bus=cxl.0,chassis=0,slot=0 \
  -device cxl-type3,bus=rp0,volatile-memdev=cxl-mem0,id=cxl-vmem0 \
  -drive "file=$IMAGE,format=qcow2" \
  -net nic -net user,hostfwd=tcp::2222-:22 \
  -nographic
