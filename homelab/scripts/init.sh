#!/usr/bin/env bash
#
# init.sh — Automated prerequisites setup for NUC homelab
#
# This script interactively guides you through:
# 1. SSH key setup (generate or use existing)
# 2. Tailscale auth key collection
# 3. Cloudflare API token collection
# 4. Updating installer configuration
#
# Usage: ./init.sh [OPTIONS]
# Or via Just: just init
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/cli.sh"

# ── Setup Functions ────────────────────────────────────────────────────

setup_ssh_key() {
  log_step "SSH Key Setup"
  
  local ssh_dir="${HOME}/.ssh"
  local pub_key=""
  local most_recent_key=""
  local most_recent_time=0
  
  # Find most recently modified key
  for key in "${ssh_dir}"/*.pub; do
    if [[ -f "$key" ]]; then
      local mod_time
      mod_time=$(stat -f %m "$key" 2>/dev/null || stat -c %Y "$key" 2>/dev/null || echo "0")
      if [[ $mod_time -gt $most_recent_time ]]; then
        most_recent_time=$mod_time
        most_recent_key="$key"
      fi
    fi
  done
  
  if [[ -n "$most_recent_key" ]]; then
    log_info "Most recently modified SSH key: ${most_recent_key}"
    pub_key=$(cat "$most_recent_key")
    
    # Validate the key format
    if ! validate_ssh_key "$pub_key"; then
      log_warn "Key format looks unusual"
    fi
    
    log_info "Key: ${pub_key:0:50}..."
    
    if confirm "Use this key?"; then
      echo "$pub_key"
      return 0
    fi
  fi
  
  # List other keys (fallback)
  local other_keys
  other_keys=$(find "$ssh_dir" -name "*.pub" -type f 2>/dev/null | head -5 || true)
  
  if [[ -n "$other_keys" ]]; then
    log_info "Available keys:"
    echo "$other_keys" | while read -r key; do
      echo "  - $key"
    done
    local key_path
    key_path=$(ask "Enter path to use (or press Enter to generate new)")
    if [[ -n "$key_path" && -f "$key_path" ]]; then
      pub_key=$(cat "$key_path")
      echo "$pub_key"
      return 0
    fi
  fi
  
  # Generate new key
  log_info "Generating new SSH key..."
  local email
  email=$(ask "Email for key (optional)" "steven@macbook")
  local default_key="${ssh_dir}/id_ed25519"
  
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  
  ssh-keygen -t ed25519 -C "$email" -f "$default_key" -N ""
  pub_key=$(cat "${default_key}.pub")
  
  log_ok "SSH key generated: ${default_key}"
  echo "$pub_key"
}

setup_tailscale_key() {
  log_step "Tailscale Auth Key"
  
  if secret_exists "tailscale-authkey"; then
    log_warn "Tailscale auth key already exists"
    if ! confirm "Overwrite?" "N"; then
      return 0
    fi
  fi
  
  cat <<EOF

${CYAN}To get your Tailscale auth key:${NC}

1. Open: https://login.tailscale.com/admin/settings/keys
2. Click: "Generate auth key..."
3. Set options:
   - Reusable: Yes
   - Ephemeral: No  
   - Expiry: 90 days
4. Click: Generate key
5. Copy the key (starts with tskey-auth-)

EOF
  
  local auth_key
  auth_key=$(ask_secret "Paste your Tailscale auth key:")
  
  # Validate format
  if ! validate_tailscale_key "$auth_key"; then
    log_error "Invalid Tailscale auth key format"
    log_info "Key should start with 'tskey-auth-'"
    return 1
  fi
  
  save_secret "tailscale-authkey" "$auth_key"
  log_ok "Tailscale auth key saved"
}

setup_cloudflare_token() {
  log_step "Cloudflare API Token"
  
  if secret_exists "cloudflare-token"; then
    log_warn "Cloudflare token already exists"
    if ! confirm "Overwrite?" "N"; then
      return 0
    fi
  fi
  
  cat <<EOF

${CYAN}To get your Cloudflare API token:${NC}

1. Open: https://dash.cloudflare.com/profile/api-tokens
2. Click: "Create Token"
3. Select: "Edit zone DNS" template
4. Configure:
   - Zone: ${DOMAIN}
   - Permissions: Zone:Read, DNS:Edit
5. Click: Continue to summary → Create token
6. Copy the token

EOF
  
  local token
  token=$(ask_secret "Paste your Cloudflare API token:")
  
  # Validate format
  if ! validate_cloudflare_token "$token"; then
    log_error "Invalid Cloudflare API token format"
    log_info "Token should be 35+ alphanumeric characters"
    return 1
  fi
  
  save_secret "cloudflare-token" "$token"
  log_ok "Cloudflare token saved"
}

update_installer_config() {
  local pub_key="$1"
  
  log_step "Update Installer Config"
  
  if ! confirm "Update installer configuration with your SSH key?"; then
    log_info "Skipping configuration update"
    return 0
  fi
  
  if [[ ! -f "$INSTALLER_CONFIG" ]]; then
    log_error "Installer config not found: $INSTALLER_CONFIG"
    return 1
  fi
  
  # Create backup
  backup_file "$INSTALLER_CONFIG"
  
  # Update the config
  log_info "Updating SSH keys..."
  
  # Replace placeholder keys
  # Handle both old and new placeholder formats
  local escaped_key
  escaped_key=$(echo "$pub_key" | sed 's/[&/\]/\\&/g')
  
  # macOS vs GNU sed
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHChkj8fKw2dvMhYo8C2gK6bUGxQbITP8dJlHBc5M3oQ steven@macbook/${escaped_key}/g" "$INSTALLER_CONFIG" 2>/dev/null || true
    sed -i '' "s/SSH_PUBLIC_KEY_PLACEHOLDER/${escaped_key}/g" "$INSTALLER_CONFIG" 2>/dev/null || true
    sed -i '' "s/CHANGE_ME/${escaped_key}/g" "$INSTALLER_CONFIG" 2>/dev/null || true
  else
    sed -i "s/ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHChkj8fKw2dvMhYo8C2gK6bUGxQbITP8dJlHBc5M3oQ steven@macbook/${escaped_key}/g" "$INSTALLER_CONFIG"
    sed -i "s/SSH_PUBLIC_KEY_PLACEHOLDER/${escaped_key}/g" "$INSTALLER_CONFIG"
    sed -i "s/CHANGE_ME/${escaped_key}/g" "$INSTALLER_CONFIG"
  fi
  
  if grep -q "$pub_key" "$INSTALLER_CONFIG"; then
    log_ok "Configuration updated"
  else
    log_warn "Could not verify SSH key was updated"
    log_info "Please check: $INSTALLER_CONFIG"
  fi
}

generate_caddy_hash() {
  log_step "Caddy Plugin Hash"
  
  if secret_exists "caddy-hash"; then
    log_warn "Caddy hash already exists"
    if ! confirm "Recompute?" "N"; then
      return 0
    fi
  fi
  
  log_info "Computing hash for Caddy Cloudflare DNS plugin..."
  log_info "This requires downloading the plugin to calculate its SHA256 hash."
  
  # Try to compute hash using nix-prefetch-url
  local hash
  if command -v nix-prefetch-url >/dev/null 2>&1; then
    hash=$(nix-prefetch-url --type sha256 \
      "https://github.com/caddy-dns/cloudflare/archive/refs/heads/master.tar.gz" 2>/dev/null || echo "")
    
    if [[ -n "$hash" ]]; then
      echo "sha256-${hash}" > "${SECRETS_DIR}/caddy-hash"
      log_ok "Hash computed and saved to secrets/caddy-hash"
      return 0
    fi
  fi
  
  # Fallback: create placeholder with instructions
  log_warn "Could not compute hash automatically"
  log_info "Creating placeholder. You'll need to update this after the first build attempt."
  
  cat > "${SECRETS_DIR}/caddy-hash" <<'EOF'
# Caddy Cloudflare Plugin Hash
# This will be populated automatically on first build, or you can compute it manually:
#
# Option 1: Let Nix compute it (recommended)
#   - Run: just nuc-build-iso
#   - Nix will fail with the expected hash
#   - Copy the hash from the error message
#   - Replace this file content with: sha256-THE_HASH
#
# Option 2: Manual computation
#   nix-prefetch-url --type sha256 https://github.com/caddy-dns/cloudflare/archive/refs/heads/master.tar.gz
#   Then save the output as: sha256-THE_HASH
#
PLACEHOLDER_REPLACE_AFTER_FIRST_BUILD
EOF
  
  log_ok "Placeholder created"
}
  log_step "Validation"
  
  local errors=0
  
  # SSH key
  if [[ -f "${HOME}/.ssh/id_ed25519" ]] || [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    log_ok "SSH key exists"
  else
    log_error "SSH key not found"
    ((errors++))
  fi
  
  # Tailscale key
  if secret_exists "tailscale-authkey"; then
    local key_content
    key_content=$(load_secret "tailscale-authkey")
    if [[ "$key_content" =~ ^tskey-auth- ]]; then
      log_ok "Tailscale key valid"
    else
      log_warn "Tailscale key format unexpected"
    fi
  else
    log_error "Tailscale key not found"
    ((errors++))
  fi
  
  # Cloudflare token
  if secret_exists "cloudflare-token"; then
    local token_content
    token_content=$(load_secret "cloudflare-token")
    if validate_cloudflare_token "$token_content"; then
      log_ok "Cloudflare token valid"
    elif [[ ${#token_content} -gt 30 ]]; then
      log_warn "Cloudflare token saved but format unexpected"
    else
      log_error "Cloudflare token too short"
      ((errors++))
    fi
  else
    log_error "Cloudflare token not found"
    ((errors++))
  fi
  
  # Caddy hash
  if secret_exists "caddy-hash"; then
    log_ok "Caddy hash saved"
  else
    log_warn "Caddy hash not computed (will be done on first build)"
  fi
  
  # Installer config
  if [[ -f "$INSTALLER_CONFIG" ]]; then
    if ! grep -q "CHANGE_ME\|PLACEHOLDER\|AAAAC3NzaC1lZDI1NTE5AAAAIHChkj" "$INSTALLER_CONFIG" 2>/dev/null; then
      log_ok "Installer config appears updated"
    else
      log_warn "Installer config may still have placeholder"
    fi
  else
    log_error "Installer config not found"
    ((errors++))
  fi
  
  return $errors
}

# ── Main ──────────────────────────────────────────────────────────────

main() {
  print_header "NUC Homelab Setup Initialization"
  
  # Check context
  if [[ ! -f "${HOMELAB_DIR}/flake.nix" ]]; then
    log_error "Not in homelab directory"
    exit 1
  fi
  
  # Parse flags
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
Usage: $0 [OPTIONS]

Interactive mode (default):
  Run without arguments for guided setup

Options:
  --help, -h        Show this help
  --check           Only run validation

EOF
    exit 0
  fi
  
  if [[ "${1:-}" == "--check" ]]; then
    if validate_setup; then
      print_footer "All checks passed"
      exit 0
    else
      log_error "Some checks failed"
      exit 1
    fi
  fi
  
  # Run setup steps
  local ssh_pub_key
  ssh_pub_key=$(setup_ssh_key)
  
  setup_tailscale_key
  setup_cloudflare_token
  generate_caddy_hash
  update_installer_config "$ssh_pub_key"
  
  # Validation
  echo ""
  if validate_setup; then
    print_footer "Setup complete!"
    echo ""
    log_info "You're ready to install! Run:"
    echo ""
    echo "  1. just nuc-build-iso     # Build installer ISO"
    echo "  2. just nuc-flash-iso     # Flash to USB"
    echo "  3. Boot NUC from USB"
    echo "  4. just nuc-install <IP>  # Install NixOS"
    echo ""
    log_info "See SETUP.md for detailed instructions."
  else
    echo ""
    log_warn "Some validations failed"
    log_info "You can re-run this script anytime: ./init.sh"
    exit 1
  fi
}

main "$@"
