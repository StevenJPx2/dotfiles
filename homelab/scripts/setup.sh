#!/usr/bin/env bash
#
# setup.sh — Main dispatcher for post-installation setup
#
# Usage: ./setup.sh [all|tailscale|dns|haos]
#
# Commands:
#   all       Run all setup steps (default)
#   tailscale Setup Tailscale authentication
#   dns       Setup Cloudflare DNS records
#   haos      Setup Home Assistant OS VM
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD_DIR="${SCRIPT_DIR}/cmd"
HOMELAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

# Show help
show_help() {
  cat <<EOF
NUC Homelab Post-Installation Setup

Usage: $0 [COMMAND]

Commands:
  all       Run all setup steps (default)
  tailscale Setup Tailscale authentication only
  dns       Setup Cloudflare DNS records only
  haos      Setup Home Assistant OS VM only

Environment:
  CF_API_TOKEN        Cloudflare API token
  TAILSCALE_AUTHKEY   Tailscale auth key

Examples:
  $0                  # Run all steps
  $0 tailscale        # Setup Tailscale only
  $0 dns              # Setup DNS only

EOF
}

# Check prerequisites
check_prereqs() {
  require_root
  
  # Warn if env vars not set
  if [[ -z "${CF_API_TOKEN:-}" ]]; then
    log_warn "CF_API_TOKEN not set in environment"
    log_info "Will prompt for it when needed"
  fi
  
  if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
    log_warn "TAILSCALE_AUTHKEY not set in environment"
    log_info "Will prompt for it when needed"
  fi
}

# Run all setup steps
run_all() {
  log_step "Running all setup steps"
  
  "${CMD_DIR}/setup-tailscale.sh" || {
    log_error "Tailscale setup failed"
    return 1
  }
  
  "${CMD_DIR}/setup-dns.sh" || {
    log_error "DNS setup failed"
    return 1
  }
  
  "${CMD_DIR}/setup-haos.sh" || {
    log_error "HAOS setup failed"
    return 1
  }
  
  log_ok "All setup steps completed!"
  echo ""
  log_info "Next steps:"
  log_info "  1. Note the HAOS IP address from above"
  log_info "  2. Update ${NIXOS_DIR}/services/caddy.nix with the IP"
  log_info "  3. Update ${NIXOS_DIR}/services/homepage.nix with the IP"
  log_info "  4. Run: just deploy"
  echo ""
  log_info "Access your services at:"
  print_service_urls
}

# Main
cmd="${1:-all}"

case "$cmd" in
  -h|--help|help)
    show_help
    exit 0
    ;;
  all)
    check_prereqs
    print_header "NUC Homelab Post-Setup"
    run_all
    print_footer "Setup complete"
    ;;
  tailscale|dns|haos)
    check_prereqs
    exec "${CMD_DIR}/setup-${cmd}.sh" "${@:2}"
    ;;
  *)
    log_error "Unknown command: $cmd"
    show_help
    exit 1
    ;;
esac
