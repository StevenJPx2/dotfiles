#!/usr/bin/env bash
#
# deploy.sh — Deploy homelab configuration changes to NUC
#
# Usage: ./deploy.sh [OPTIONS]
#
# Options:
#   (no args)   Full deploy: rsync + nixos-rebuild switch
#   --dry-run   Show what would be synced without changes
#   --status    Check service status on NUC
#   --diff      Show NixOS config diff before applying
#   --test      Deploy with nixos-rebuild test (no bootloader update)
#   --help      Show this help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD_DIR="${SCRIPT_DIR}/cmd"
HOMELAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${HOMELAB_DIR}/.env"

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/cli.sh"

# Show help
show_help() {
  cat <<EOF
Homelab Deployment Script

Usage: $(basename "$0") [OPTIONS]

Options:
  -h, --help      Show this help message
  -v, --verbose   Enable verbose output
  -n, --dry-run   Show what would be synced without changes
  --status        Check service status on NUC
  --diff          Show NixOS configuration diff
  --test          Test deployment (no bootloader update)

Environment:
  NUC_HOST          Target NUC hostname/IP
  NUC_USER          SSH user (default: steven)
  NUC_REMOTE_PATH   Remote path (default: /home/\$NUC_USER/homelab)

Examples:
  $(basename "$0")              # Full deploy
  $(basename "$0") --dry-run    # Preview changes
  $(basename "$0") --status     # Check services

EOF
}

# Parse CLI flags
if ! parse_cli_flags "$@"; then
  show_help
  exit 0
fi

# Load environment
if [[ -f "$ENV_FILE" ]]; then
  load_env "$ENV_FILE" NUC_HOST NUC_USER || {
    log_error "Failed to load environment"
    exit 1
  }
else
  log_warn "No .env file found, using defaults"
  NUC_HOST="${NUC_HOST:-nuc}"
  NUC_USER="${NUC_USER:-steven}"
fi

NUC_REMOTE_PATH="${NUC_REMOTE_PATH:-/home/${NUC_USER}/homelab}"

# Sync files to NUC
sync_files() {
  local dry_run_flag="${1:-}"
  
  log_step "Syncing files to NUC"
  log_info "Source: ${SCRIPT_DIR}/"
  log_info "Target: ${NUC_USER}@${NUC_HOST}:${NUC_REMOTE_PATH}/"
  
  if is_dry_run; then
    log_info "[DRY RUN] Would sync files"
    return 0
  fi
  
  rsync -avz --delete \
    ${dry_run_flag} \
    --exclude '.env' \
    --exclude '.env.example' \
    --exclude '.git' \
    --exclude '*.example' \
    --exclude 'result*' \
    --exclude '.direnv' \
    "${SCRIPT_DIR}/" "${NUC_USER}@${NUC_HOST}:${NUC_REMOTE_PATH}/"
  
  log_ok "Files synced"
}

# Run nixos-rebuild
rebuild() {
  local mode="${1:-switch}"
  
  log_step "Running nixos-rebuild"
  log_info "Mode: ${mode}"
  
  if is_dry_run; then
    log_info "[DRY RUN] Would run: nixos-rebuild ${mode}"
    return 0
  fi
  
  ssh "${NUC_USER}@${NUC_HOST}" "sudo nixos-rebuild ${mode}"
  log_ok "Rebuild complete"
}

# Show diff
show_diff() {
  log_step "Showing configuration diff"
  
  if is_dry_run; then
    log_info "[DRY RUN] Would show diff"
    return 0
  fi
  
  ssh "${NUC_USER}@${NUC_HOST}" "
    sudo nixos-rebuild build && \
    (command -v nvd >/dev/null 2>&1 && \
     nvd diff /run/current-system result || \
     echo 'nvd not installed, install with: nix-env -iA nixpkgs.nix-diff')
  " || true
}

# Main dispatcher
case "${1:-}" in
  --status)
    shift
    exec "${CMD_DIR}/status.sh" "$@"
    ;;
  --diff)
    require_ssh "$NUC_HOST" "$NUC_USER"
    sync_files
    show_diff
    ;;
  --test)
    require_ssh "$NUC_HOST" "$NUC_USER"
    sync_files
    rebuild "test"
    log_ok "Test deployment complete"
    ;;
  --dry-run|-n)
    export CLI_DRY_RUN=1
    require_ssh "$NUC_HOST" "$NUC_USER"
    sync_files "--dry-run"
    ;;
  --help|-h)
    show_help
    exit 0
    ;;
  "")
    # Full deploy
    print_header "Homelab Deployment"
    require_ssh "$NUC_HOST" "$NUC_USER"
    sync_files
    rebuild "switch"
    print_footer "Deployment complete"
    ;;
  *)
    log_error "Unknown option: $1"
    show_help
    exit 1
    ;;
esac
