# lib/config.sh — Centralized configuration for homelab
#
# Source after common.sh:
#   source "$(dirname "$0")/lib/common.sh"
#   source "$(dirname "$0")/lib/config.sh"
#

# ── Domain Configuration ──────────────────────────────────────────────
readonly DOMAIN="stevenjohn.co"
readonly SUBDOMAIN="home"
readonly FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

# ── Service URLs ────────────────────────────────────────────────────
declare -A SERVICE_URLS=(
  [dashboard]="https://${FULL_DOMAIN}"
  [ha]="https://ha.${FULL_DOMAIN}"
  [photos]="https://photos.${FULL_DOMAIN}"
  [dns]="https://dns.${FULL_DOMAIN}"
  [status]="https://status.${FULL_DOMAIN}"
  [tasks]="https://tasks.${FULL_DOMAIN}"
)

# ── NUC Configuration ───────────────────────────────────────────────
readonly NUC_USER="${NUC_USER:-steven}"
readonly NUC_HOST="${NUC_HOST:-nuc}"
readonly NUC_REMOTE_PATH="${NUC_REMOTE_PATH:-/home/${NUC_USER}/homelab}"
readonly LAN_INTERFACE="${LAN_INTERFACE:-eno1}"

# ── HAOS Configuration ────────────────────────────────────────────────
readonly HAOS_VERSION="14.2"
readonly HAOS_NAME="haos"
readonly HAOS_CPU="2"
readonly HAOS_MEMORY="4GiB"
readonly HAOS_DISK_SIZE="64GiB"

readonly HAOS_DOWNLOAD_URL="https://github.com/home-assistant/operating-system/releases/download/${HAOS_VERSION}/haos_ova-${HAOS_VERSION}.qcow2.xz"

# ── Timing Configuration ─────────────────────────────────────────────
readonly HAOS_BOOT_TIMEOUT=60  # Seconds to wait for HAOS to boot
readonly SSH_TIMEOUT=5           # Seconds for SSH connection test
readonly DNS_WAIT_TIMEOUT=60     # Seconds to wait for DNS propagation
readonly DOWNLOAD_TIMEOUT=300    # Seconds for wget downloads

# ── Services ────────────────────────────────────────────────────────

# NixOS native systemd services to monitor
readonly NATIVE_SERVICES=(
  caddy
  immich-server
  immich-machine-learning
  pihole-ftl
  pihole-web
  uptime-kuma
  homepage-dashboard
  tailscaled
)

# Docker containers to monitor
readonly DOCKER_CONTAINERS=(
  super-productivity
  watchtower
)

# Incus VMs to monitor
readonly INCUS_VMS=(
  haos
)

# All TCP ports used by services
readonly SERVICE_PORTS=(
  53    # Pi-hole DNS
  80    # Caddy HTTP
  443   # Caddy HTTPS
  2283  # Immich
  3000  # Homepage
  3001  # Uptime Kuma
  8020  # Super Productivity
  8053  # Pi-hole Web
  8123  # Home Assistant (in VM)
)

# UDP ports
readonly SERVICE_PORTS_UDP=(
  53    # Pi-hole DNS
)

# ── File Paths ──────────────────────────────────────────────────────
readonly INSTALLER_CONFIG="${HOMELAB_DIR}/nixos/installer/configuration.nix"
readonly NIXOS_DIR="${HOMELAB_DIR}/nixos"
readonly TAILSCALE_AUTHKEY_FILE="/etc/tailscale/authkey"
readonly CADDY_ENV_FILE="/etc/caddy-env"
readonly HOMEPAGE_SECRETS_FILE="/etc/homepage-secrets"

# ── Cloudflare Configuration ─────────────────────────────────────────
readonly CF_API_URL="https://api.cloudflare.com/client/v4"
readonly CF_DNS_RECORDS=(
  "${SUBDOMAIN}"
  "*.${SUBDOMAIN}"
)

# ── Helper Functions ────────────────────────────────────────────────

# Get service URL by name
# Usage: service_url <name>
service_url() {
  local name="$1"
  echo "${SERVICE_URLS[$name]:-}"
}

# Print all service URLs
print_service_urls() {
  log_info "Services available at:"
  for service in "${!SERVICE_URLS[@]}"; do
    # Only print unique URLs (some services have multiple names)
    [[ "$service" == "homeassistant" ]] && continue
    [[ "$service" == "immich" ]] && continue
    [[ "$service" == "pihole" ]] && continue
    [[ "$service" == "uptime" ]] && continue
    [[ "$service" == "superproductivity" ]] && continue
    
    log_info "  ${service}: ${SERVICE_URLS[$service]}"
  done
}

# Get HAOS VM info
# Usage: haos_info [field: name|version|cpu|memory|url]
haos_info() {
  local field="${1:-url}"
  case "$field" in
    name)       echo "$HAOS_NAME" ;;
    version)    echo "$HAOS_VERSION" ;;
    cpu)        echo "$HAOS_CPU" ;;
    memory)     echo "$HAOS_MEMORY" ;;
    url)        echo "${SERVICE_URLS[ha]}" ;;
    download)   echo "$HAOS_DOWNLOAD_URL" ;;
    *)          echo "Unknown field: $field" >&2; return 1 ;;
  esac
}

# Check if HAOS VM exists
haos_exists() {
  incus info "$HAOS_NAME" >/dev/null 2>&1
}

# Get HAOS VM status
haos_status() {
  if haos_exists; then
    incus list "$HAOS_NAME" --format=compact 2>/dev/null | tail -1
  else
    echo "not created"
  fi
}

# Get HAOS IP address
haos_ip() {
  incus list --format=json 2>/dev/null | \
    jq -r ".[] | select(.name==\"${HAOS_NAME}\") | .state.network.eth0.addresses[] | select(.family==\"inet\") | .address" 2>/dev/null | head -1
}

# ── Validation Helpers ───────────────────────────────────────────────

# Validate configuration
validate_config() {
  local errors=0
  
  # Check domain format
  if ! is_valid_domain "$FULL_DOMAIN"; then
    log_error "Invalid domain format: $FULL_DOMAIN"
    ((errors++))
  fi
  
  # Check secrets directory
  if [[ ! -d "$SECRETS_DIR" ]]; then
    log_warn "Secrets directory not found: $SECRETS_DIR"
  fi
  
  # Check required files
  for file in "${INSTALLER_CONFIG}" "${HOMELAB_DIR}/flake.nix"; do
    if [[ ! -f "$file" ]]; then
      log_error "Required file not found: $file"
      ((errors++))
    fi
  done
  
  if [[ $errors -gt 0 ]]; then
    log_error "Configuration validation failed with $errors error(s)"
    return 1
  fi
  
  log_ok "Configuration valid"
  return 0
}

# Print configuration summary
print_config_summary() {
  print_header "Configuration Summary"
  
  log_info "Domain: ${FULL_DOMAIN}"
  log_info "NUC User: ${NUC_USER}"
  log_info "LAN Interface: ${LAN_INTERFACE}"
  log_info "HAOS Version: ${HAOS_VERSION}"
  echo ""
  print_service_urls
}
