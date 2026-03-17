#!/usr/bin/env bash
#
# cmd/status.sh — Check status of all homelab services
#
# Usage: ./cmd/status.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOMELAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

print_header "Homelab Service Status"

# ── NixOS Native Services ──────────────────────────────────────────────
log_step "NixOS Native Services"

for svc in "${NATIVE_SERVICES[@]}"; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    echo -e "${GREEN}[RUNNING]${NC} $svc"
  else
    echo -e "${RED}[STOPPED]${NC} $svc"
  fi
done

# ── Docker Containers ───────────────────────────────────────────────
echo ""
log_step "Docker Containers"

if command -v docker &>/dev/null; then
  if docker info >/dev/null 2>&1; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
      log_info "No containers running"
  else
    log_warn "Docker daemon not accessible"
  fi
else
  log_info "Docker not installed"
fi

# ── Incus VMs ─────────────────────────────────────────────────────────
echo ""
log_step "Incus VMs"

if command -v incus &>/dev/null; then
  incus list 2>/dev/null || log_info "No VMs"
else
  log_info "Incus not installed"
fi

# ── Tailscale Status ────────────────────────────────────────────────
echo ""
log_step "Tailscale"

if command -v tailscale &>/dev/null; then
  if tailscale ip -4 >/dev/null 2>&1; then
    log_ok "Connected: $(tailscale ip -4)"
    tailscale status 2>/dev/null | head -3 || true
  else
    log_warn "Not connected"
    log_info "Run: sudo tailscale up"
  fi
else
  log_warn "Tailscale not installed"
fi

# ── DNS Resolution ────────────────────────────────────────────────────
echo ""
log_step "DNS Resolution"

for service in dashboard ha photos; do
  url=$(service_url "$service")
  domain=$(echo "$url" | sed 's|https://||')
  
  if dig +short "$domain" >/dev/null 2>&1; then
    ip=$(dig +short "$domain" | head -1)
    echo -e "${GREEN}[OK]${NC} ${domain} → ${ip}"
  else
    echo -e "${RED}[FAIL]${NC} ${domain} (not resolving)"
  fi
done

# ── Service Connectivity ──────────────────────────────────────────────
echo ""
log_step "Service Connectivity"

for port in 443 2283 3000 3001; do
  if nc -z localhost "$port" 2>/dev/null; then
    echo -e "${GREEN}[OPEN]${NC} Port ${port}"
  else
    echo -e "${RED}[CLOSED]${NC} Port ${port}"
  fi
done

print_footer "Status check complete"
