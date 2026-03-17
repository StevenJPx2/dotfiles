#!/usr/bin/env bash
#
# nuc-setup.sh — Run post-installation setup on the NUC via SSH
#
# Usage: ./scripts/nuc-setup.sh [hostname]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

# Get hostname
HOST="${1:-nuc}"

print_header "Post-Installation Setup on NUC"
log_info "Connecting to ${HOST}..."
log_info "You may be prompted for your sudo password on the NUC"

# SSH and run setup
ssh -t "${NUC_USER}@${HOST}" "
  export CF_API_TOKEN=\$(cat /home/${NUC_USER}/homelab/secrets/cloudflare-token 2>/dev/null || echo '');
  export TAILSCALE_AUTHKEY=\$(cat /home/${NUC_USER}/homelab/secrets/tailscale-authkey 2>/dev/null || echo '');
  
  if [[ -z \"\${CF_API_TOKEN}\" ]]; then
    read -s -p 'Cloudflare API Token: ' CF_API_TOKEN;
    export CF_API_TOKEN;
    echo '';
  fi;
  
  if [[ -z \"\${TAILSCALE_AUTHKEY}\" ]]; then
    read -s -p 'Tailscale Auth Key: ' TAILSCALE_AUTHKEY;
    export TAILSCALE_AUTHKEY;
    echo '';
  fi;
  
  sudo -E /home/${NUC_USER}/homelab/scripts/setup.sh
"

print_footer "Setup initiated on NUC"
