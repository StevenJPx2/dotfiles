#!/usr/bin/env bash
#
# cmd/setup-haos.sh — Home Assistant OS VM setup
#
# Usage: ./cmd/setup-haos.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOMELAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

print_header "Home Assistant OS VM Setup"

# Check if VM already exists
if haos_exists; then
  log_warn "HAOS VM already exists"
  haos_status
  
  if ! confirm "Remove and recreate?" "N"; then
    log_info "Keeping existing VM"
    log_info "HAOS IP: $(haos_ip)"
    exit 0
  fi
  
  log_info "Stopping and deleting existing VM..."
  incus stop "$HAOS_NAME" --force 2>/dev/null || true
  incus delete "$HAOS_NAME" --force 2>/dev/null || true
fi

# Download HAOS image
HAOS_FILE="/tmp/haos_ova-${HAOS_VERSION}.qcow2"
HAOS_XZ="${HAOS_FILE}.xz"

if [[ -f "$HAOS_FILE" ]]; then
  log_info "Using existing HAOS image"
elif [[ -f "$HAOS_XZ" ]]; then
  log_info "Found compressed image, extracting..."
  xz -d "$HAOS_XZ"
else
  log_info "Downloading Home Assistant OS ${HAOS_VERSION}..."
  log_info "URL: ${HAOS_DOWNLOAD_URL}"
  
  if ! wget -q --show-progress --timeout=300 --tries=3 "$HAOS_DOWNLOAD_URL" -O "$HAOS_XZ"; then
    log_error "Failed to download HAOS image"
    exit 1
  fi
  
  log_info "Extracting..."
  xz -d "$HAOS_XZ"
fi

# Create VM
log_step "Creating Incus VM"
log_info "Name: ${HAOS_NAME}"
log_info "CPU: ${HAOS_CPU}"
log_info "Memory: ${HAOS_MEMORY}"
log_info "Disk: ${HAOS_DISK_SIZE}"

if ! incus init "$HAOS_NAME" --empty --vm \
  -c limits.cpu="$HAOS_CPU" \
  -c limits.memory="$HAOS_MEMORY" \
  -c security.secureboot=false; then
  log_error "Failed to create VM"
  exit 1
fi

# Import disk
log_info "Importing disk image (this may take a minute)..."
if ! qemu-img convert -f qcow2 -O raw "$HAOS_FILE" \
  "/var/lib/incus/storage-pools/default/virtual-machines/${HAOS_NAME}/root.img"; then
  log_error "Failed to import disk image"
  incus delete "$HAOS_NAME" --force 2>/dev/null || true
  exit 1
fi

# Start VM
log_info "Starting VM..."
if ! incus start "$HAOS_NAME"; then
  log_error "Failed to start VM"
  exit 1
fi

log_ok "HAOS VM created and started"

# Wait for boot
log_info "Waiting for HAOS to boot (~${HAOS_BOOT_TIMEOUT}s)..."
for i in $(seq 1 $HAOS_BOOT_TIMEOUT); do
  IP=$(haos_ip)
  if [[ -n "$IP" ]]; then
    break
  fi
  sleep 1
  echo -n "."
done
echo ""

# Get IP
HAOS_IP=$(haos_ip)

if [[ -n "$HAOS_IP" ]]; then
  log_ok "HAOS VM IP: ${HAOS_IP}"
  
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║  IMPORTANT: Update your configs!                               ║"
  echo "║                                                                ║"
  echo "║  1. Edit: homelab/nixos/caddy.nix                              ║"
  printf "║     Replace HAOS_VM_IP with: %-33s║\n" "${HAOS_IP}"
  echo "║                                                                ║"
  echo "║  2. Edit: homelab/nixos/homepage.nix                           ║"
  echo "║     Update the Home Assistant widget URL                       ║"
  echo "║                                                                ║"
  echo "║  3. Run: just deploy                                           ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
else
  log_warn "Could not determine HAOS IP yet"
  log_info "Check manually: incus list"
fi

# Cleanup
rm -f "$HAOS_FILE" "$HAOS_XZ"

print_footer "HAOS setup complete"
