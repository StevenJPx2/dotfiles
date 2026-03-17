#!/usr/bin/env bash
#
# doctor.sh — Check system health and prerequisites
#
# Usage: ./scripts/doctor.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

echo "🏥 NUC Homelab System Check"
echo ""
echo "Checking prerequisites..."
echo ""

errors=0
warnings=0

# Check SSH key
if [[ -f ~/.ssh/id_ed25519.pub ]] || [[ -f ~/.ssh/id_rsa.pub ]] || ls ~/.ssh/*.pub >/dev/null 2>&1; then
  log_ok "SSH key found"
else
  log_error "SSH key not found"
  log_info "Run: ssh-keygen -t ed25519"
  ((errors++))
fi

echo ""

# Check secrets
if secret_exists "tailscale-authkey"; then
  log_ok "Tailscale auth key saved"
else
  log_error "Tailscale auth key missing"
  log_info "Run: just init"
  ((errors++))
fi

if secret_exists "cloudflare-token"; then
  log_ok "Cloudflare token saved"
else
  log_error "Cloudflare token missing"
  log_info "Run: just init"
  ((errors++))
fi

if secret_exists "caddy-hash"; then
  if grep -q "PLACEHOLDER" "${SECRETS_DIR}/caddy-hash" 2>/dev/null; then
    log_warn "Caddy hash placeholder (will compute on first build)"
    ((warnings++))
  else
    log_ok "Caddy hash saved"
  fi
else
  log_warn "Caddy hash not found (will create on first run)"
  ((warnings++))
fi

echo ""

# Check installer config
if [[ -f "$INSTALLER_CONFIG" ]]; then
  if grep -q "steven@macbook" "$INSTALLER_CONFIG" 2>/dev/null; then
    log_error "Installer config has placeholder SSH key"
    log_info "Run: just init"
    ((errors++))
  else
    log_ok "Installer config appears updated"
  fi
else
  log_error "Installer config not found"
  ((errors++))
fi

echo ""

# Check tools
if command -v nix >/dev/null 2>&1; then
  log_ok "Nix is installed"
else
  log_error "Nix not found"
  log_info "Install from https://nixos.org/download.html"
  ((errors++))
fi

if command -v just >/dev/null 2>&1; then
  log_ok "Just is installed"
else
  log_error "Just not found"
  log_info "Install: brew install just"
  ((errors++))
fi

echo ""

# Summary
if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
  print_footer "All checks passed! Ready to install."
elif [[ $errors -eq 0 ]]; then
  print_footer "Checks passed with ${warnings} warnings"
  log_info "Run 'just nuc-help' for next steps"
else
  log_error "Found ${errors} error(s) and ${warnings} warning(s)"
  log_info "Fix the errors above, then run 'just doctor' again"
  exit 1
fi
