#!/usr/bin/env bash
#
# cmd/setup-tailscale.sh — Tailscale setup for NUC
#
# Usage: ./cmd/setup-tailscale.sh [auth_key]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

AUTH_KEY="${1:-${TAILSCALE_AUTHKEY:-}}"

print_header "Tailscale Setup"

# Check if already authenticated
if tailscale status 2>/dev/null | grep -q "Logged out"; then
  log_info "Tailscale is not authenticated"
elif tailscale ip -4 >/dev/null 2>&1; then
  log_ok "Tailscale is already authenticated"
  log_info "Tailscale IP: $(tailscale ip -4)"
  exit 0
fi

# Get auth key if not provided
if [[ -z "$AUTH_KEY" ]]; then
  log_info "Tailscale authentication required"
  echo ""
  echo "Get an auth key from: https://login.tailscale.com/admin/settings/keys"
  echo "  - Reusable: Yes"
  echo "  - Ephemeral: No"
  echo "  - Expiry: 90 days"
  echo ""
  AUTH_KEY=$(ask_secret "Paste your Tailscale auth key (starts with tskey-auth-):" "^tskey-auth-" "Key should start with 'tskey-auth-'")
fi

# Validate key format
if [[ ! "$AUTH_KEY" =~ ^tskey-auth- ]]; then
  log_warn "Auth key doesn't start with 'tskey-auth-'"
  confirm "Continue anyway?" "N" || exit 1
fi

# Save auth key to file
log_info "Saving auth key..."
echo "$AUTH_KEY" > "$TAILSCALE_AUTHKEY_FILE"
chmod 600 "$TAILSCALE_AUTHKEY_FILE"

# Start tailscaled if not running
log_info "Starting tailscaled..."
systemctl start tailscaled || true

# Authenticate
log_info "Authenticating with Tailscale..."
if tailscale up --authkey="$AUTH_KEY" --ssh; then
  log_ok "Tailscale authenticated successfully"
else
  log_error "Tailscale authentication failed"
  exit 1
fi

# Wait for IP
log_info "Waiting for Tailscale IP..."
if wait_for "tailscale ip -4" "Waiting for Tailscale IP" 15 2; then
  TS_IP=$(tailscale ip -4)
  log_ok "Tailscale IP: $TS_IP"
else
  log_warn "Could not get Tailscale IP"
fi

# Show status
echo ""
tailscale status | head -5

print_footer "Tailscale setup complete"
