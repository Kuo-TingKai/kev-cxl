#!/usr/bin/env bash
# Single VM with CXL Type-3 device (1GB volatile memory).
# On Mac (ARM): uses TCG; replace image path before running.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Path to your x86_64 Linux image (qcow2). Must be bootable (see README / fetch_bootable_image.sh).
IMAGE="${QEMU_IMAGE:-$PROJECT_DIR/your_linux_image.qcow2}"
# Optional: boot from ISO to install OS to the disk (e.g. Ubuntu server ISO)
ISO="${QEMU_ISO:-}"
# Optional: use graphical window so login prompt appears (set to 1 if -nographic shows no login)
GRAPHIC="${QEMU_GRAPHIC:-0}"

# Create shm files for CXL (macOS has no /dev/shm, use TMPDIR)
SHM_DIR="/dev/shm"
[[ -d /dev/shm ]] || SHM_DIR="${TMPDIR:-/tmp}"
CXL_TEST="${CXL_TEST_PATH:-$SHM_DIR/cxltest}"
CXL_VOLATILE="${CXL_VOLATILE_PATH:-$SHM_DIR/cxl-volatile1}"
CXL_LSA_FILE="${CXL_LSA_PATH:-$SHM_DIR/cxl-lsa1}"

if [[ ! -f "$CXL_TEST" ]]; then
  echo "Creating $CXL_TEST (256M)..."
  dd if=/dev/zero of="$CXL_TEST" bs=1M count=256 2>/dev/null
fi
if [[ ! -f "$CXL_VOLATILE" ]]; then
  echo "Creating $CXL_VOLATILE (1G)..."
  dd if=/dev/zero of="$CXL_VOLATILE" bs=1M count=1024 2>/dev/null
fi
if [[ ! -f "$CXL_LSA_FILE" ]]; then
  echo "Creating $CXL_LSA_FILE (256K LSA)..."
  dd if=/dev/zero of="$CXL_LSA_FILE" bs=1K count=256 2>/dev/null
fi

# On macOS (ARM) use TCG; on Linux x86 with KVM use kvm
ACCEL="tcg"
if [[ "$(uname -m)" == "x86_64" ]] && [[ "$(uname -s)" == "Linux" ]]; then
  if grep -q vmx /proc/cpuinfo 2>/dev/null || grep -q svm /proc/cpuinfo 2>/dev/null; then
    ACCEL="kvm"
  fi
fi

if [[ ! -f "$IMAGE" ]]; then
  echo "Error: Linux image not found: $IMAGE"
  echo "  - Use a bootable image (empty qcow2 is not bootable)."
  echo "  - Run: ./scripts/fetch_bootable_image.sh   then  export QEMU_IMAGE=\$PWD/alpine-cxl.qcow2"
  echo "  - Or set QEMU_IMAGE to your own bootable qcow2, or use QEMU_ISO=path/to/install.iso to install to disk."
  exit 1
fi

CDROM_ARGS=()
if [[ -n "$ISO" ]] && [[ -f "$ISO" ]]; then
  CDROM_ARGS=(-cdrom "$ISO")
  echo "Booting with CDROM (install OS to disk): $ISO"
fi

# Display: -nographic = serial only (Alpine login may not show); graphic = VGA window with login
if [[ "$GRAPHIC" == "1" ]] || [[ "$GRAPHIC" == "yes" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    DISPLAY_ARGS=(-display cocoa)
  else
    DISPLAY_ARGS=(-display gtk)
  fi
  echo "Using graphical window (login prompt in window)."
else
  DISPLAY_ARGS=(-nographic)
  echo "Using serial console only. For login prompt use: QEMU_GRAPHIC=1 $0"
fi

# Attach disk to main PCIe root (pcie.0); pxb-cxl accepts only bridges, not virtio.
echo "Starting QEMU with CXL Type-3 (accel=$ACCEL)..."
exec qemu-system-x86_64 \
  -m 4G \
  -smp 4 \
  -machine "q35,cxl=on,accel=$ACCEL" \
  -object memory-backend-file,id=mem0,mem-path="$CXL_TEST",size=256M,share=on \
  -object memory-backend-file,id=cxl-mem1,mem-path="$CXL_VOLATILE",size=1G,share=on \
  -object memory-backend-file,id=cxl-lsa1,mem-path="$CXL_LSA_FILE",size=256K,share=on \
  -device pxb-cxl,id=cxl.0,bus=pcie.0,bus_nr=52 \
  -device cxl-rp,id=rp0,bus=cxl.0,chassis=0,slot=0 \
  -device cxl-type3,bus=rp0,volatile-memdev=cxl-mem1,id=cxl-pmem0,lsa=cxl-lsa1 \
  -drive "file=$IMAGE,format=qcow2,if=none,id=drive0" \
  -device virtio-blk-pci,drive=drive0,bus=pcie.0,addr=0x6 \
  "${CDROM_ARGS[@]}" \
  "${DISPLAY_ARGS[@]}"
