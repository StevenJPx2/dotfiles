#!/usr/bin/env bash
#
# cmd/setup-dns.sh — Cloudflare DNS setup for NUC
#
# Usage: ./cmd/setup-dns.sh [cf_api_token] [tailscale_ip]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOMELAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

CF_API_TOKEN="${1:-${CF_API_TOKEN:-}}"
TAILSCALE_IP="${2:-$(tailscale ip -4 2>/dev/null || echo "")}"

print_header "Cloudflare DNS Setup"

# Get API token if not provided
if [[ -z "$CF_API_TOKEN" ]]; then
  log_info "Cloudflare API token required"
  echo ""
  echo "Get a token from: https://dash.cloudflare.com/profile/api-tokens"
  echo "  - Use 'Edit zone DNS' template"
  echo "  - Zone: ${DOMAIN}"
  echo ""
  CF_API_TOKEN=$(ask_secret "Paste your Cloudflare API token:")
fi

# Get Tailscale IP if not provided
if [[ -z "$TAILSCALE_IP" ]]; then
  log_info "Getting Tailscale IP..."
  TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
  
  if [[ -z "$TAILSCALE_IP" ]]; then
    log_error "Could not get Tailscale IP"
    log_info "Is Tailscale running? Try: sudo tailscale up"
    exit 1
  fi
fi

log_ok "Using Tailscale IP: ${TAILSCALE_IP}"

# Get Zone ID
log_info "Looking up Cloudflare zone ID..."
ZONE_ID=$(curl -s -X GET "${CF_API_URL}/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" | \
  jq -r '.result[0].id')

if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
  log_error "Could not find zone ID for ${DOMAIN}"
  log_info "Check that your API token has Zone:Read permission"
  exit 1
fi

log_ok "Zone ID: ${ZONE_ID}"

# Function to create DNS record
create_record() {
  local name="$1"
  local content="$2"
  
  log_info "Creating DNS record: ${name}.${DOMAIN}"
  
  local response=$(curl -s -X POST "${CF_API_URL}/zones/${ZONE_ID}/dns_records" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\": \"A\",
      \"name\": \"${name}\",
      \"content\": \"${content}\",
      \"ttl\": 120,
      \"proxied\": false
    }")
  
  if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
    log_ok "Created: ${name}.${DOMAIN}"
    return 0
  else
    local error=$(echo "$response" | jq -r '.errors[0].message')
    if [[ "$error" == *"already exists"* ]]; then
      log_warn "Already exists: ${name}.${DOMAIN}"
      return 0
    else
      log_error "Failed: ${error}"
      return 1
    fi
  fi
}

# Create records
log_step "Creating DNS Records"
for record in "${CF_DNS_RECORDS[@]}"; do
  create_record "$record" "$TAILSCALE_IP" || true
done

echo ""
log_ok "DNS setup complete!"
echo ""
log_info "Services will be available at:"
for service in dashboard ha photos dns status tasks; do
  log_info "  ${service}: $(service_url $service)"
done

print_footer "DNS setup complete"
