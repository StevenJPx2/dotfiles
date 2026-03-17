# lib/common.sh — Shared utilities for homelab scripts
#
# This library provides common functionality used across all homelab scripts.
# Source it at the beginning of your scripts:
#   source "$(dirname "$0")/lib/common.sh"
#
# Exit Codes:
#   0 - Success
#   1 - General error
#   2 - Invalid arguments/usage
#   3 - Missing dependencies
#   4 - Network/connection error
#   5 - Validation error
#

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# ── Logging ────────────────────────────────────────────────────────────
log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${CYAN}===${NC} ${BOLD}$*${NC} ${CYAN}===${NC}"; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $*" >&2; }

# ── Environment & Configuration ─────────────────────────────────────
# Note: Scripts are in scripts/, so homelab root is two directories up from lib/
HOMELAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="${HOMELAB_DIR}/scripts"
LIB_DIR="${SCRIPTS_DIR}/lib"
CMD_DIR="${SCRIPTS_DIR}/cmd"
SECRETS_DIR="${HOMELAB_DIR}/secrets"
ENV_FILE="${HOMELAB_DIR}/.env"

# ── Input Validation ─────────────────────────────────────────────────

# Validate Cloudflare API token format
# Usage: validate_cloudflare_token <token>
validate_cloudflare_token() {
  local token="$1"
  # Cloudflare tokens are typically 40+ alphanumeric characters
  [[ "$token" =~ ^[a-zA-Z0-9_-]{35,}$ ]]
}

# Validate Tailscale auth key format
# Usage: validate_tailscale_key <key>
validate_tailscale_key() {
  local key="$1"
  [[ "$key" =~ ^tskey-auth-[a-zA-Z0-9_-]+$ ]]
}

# Validate SSH public key format
# Usage: validate_ssh_key <key_string>
validate_ssh_key() {
  local key="$1"
  [[ "$key" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp[0-9]+)\ [A-Za-z0-9+/]+=*(\ .+)?$ ]]
}

# Validate IP address
# Usage: validate_ip <ip>
validate_ip() {
  local ip="$1"
  [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

# Validate domain name
# Usage: validate_domain <domain>
validate_domain() {
  local domain="$1"
  [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z0-9.-]+$ ]]
}

# ── SSH Utilities ──────────────────────────────────────────────────────

# Test SSH connectivity to a host
# Usage: test_ssh <host> [user] [timeout]
test_ssh() {
  local host="$1"
  local user="${2:-root}"
  local timeout="${3:-5}"
  
  log_debug "Testing SSH to ${user}@${host} (timeout: ${timeout}s)"
  
  if ! ssh -o ConnectTimeout="$timeout" \
           -o BatchMode=yes \
           -o StrictHostKeyChecking=accept-new \
           "${user}@${host}" "echo 'SSH_OK'" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# Test SSH and exit on failure
# Usage: require_ssh <host> [user] [timeout]
require_ssh() {
  local host="$1"
  local user="${2:-root}"
  local timeout="${3:-5}"
  
  log_info "Testing SSH connection to ${user}@${host}..."
  if ! test_ssh "$host" "$user" "$timeout"; then
    log_error "Cannot connect to ${user}@${host}"
    log_info "Make sure:"
    log_info "  1. The host is reachable (ping ${host})"
    log_info "  2. SSH is enabled on the host"
    log_info "  3. Your SSH key is authorized"
    return 1
  fi
  log_ok "SSH connection successful"
}

# ── Environment Loading ──────────────────────────────────────────────

# Load .env file with optional validation
# Usage: load_env [env_file] [required_vars...]
load_env() {
  local env_file="${1:-$ENV_FILE}"
  shift || true
  
  if [[ ! -f "$env_file" ]]; then
    log_error "Environment file not found: $env_file"
    log_info "Copy .env.example to .env and configure it"
    return 1
  fi
  
  # shellcheck source=/dev/null
  source "$env_file"
  
  # Validate required variables
  local missing=0
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      log_error "Required variable not set in ${env_file}: $var"
      ((missing++))
    fi
  done
  
  if [[ $missing -gt 0 ]]; then
    return 1
  fi
  
  return 0
}

# Get environment variable with default
# Usage: env_or_default <var_name> <default_value>
env_or_default() {
  local var_name="$1"
  local default_value="$2"
  echo "${!var_name:-$default_value}"
}

# ── Permission Checks ─────────────────────────────────────────────────

# Check if running as root
require_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This operation requires root privileges"
    log_info "Run with: sudo $0"
    return 1
  fi
}

# Check if not running as root (for local operations)
require_non_root() {
  if [[ $EUID -eq 0 ]]; then
    log_warn "Running as root, but this is not recommended for this operation"
  fi
}

# ── Context Validation ────────────────────────────────────────────────

# Check if we're in the homelab directory
require_homelab_context() {
  if [[ ! -f "${HOMELAB_DIR}/flake.nix" ]]; then
    log_error "Not in homelab directory (flake.nix not found)"
    log_info "Please run this script from the homelab/ directory"
    return 1
  fi
}

# ── Secret Management ─────────────────────────────────────────────────

# Load secret from file
# Usage: load_secret <filename>
load_secret() {
  local filename="$1"
  local filepath="${SECRETS_DIR}/${filename}"
  
  if [[ ! -f "$filepath" ]]; then
    log_error "Secret file not found: ${filepath}"
    log_info "Create it with: echo 'secret' > ${filepath}"
    return 1
  fi
  
  cat "$filepath"
}

# Save secret to file
# Usage: save_secret <filename> <content>
save_secret() {
  local filename="$1"
  local content="$2"
  local filepath="${SECRETS_DIR}/${filename}"
  
  mkdir -p "$SECRETS_DIR"
  chmod 700 "$SECRETS_DIR"
  
  echo "$content" > "$filepath"
  chmod 600 "$filepath"
  
  log_debug "Saved secret to ${filepath}"
}

# Check if secret exists
# Usage: secret_exists <filename>
secret_exists() {
  local filename="$1"
  [[ -f "${SECRETS_DIR}/${filename}" ]]
}

# ── User Interaction ─────────────────────────────────────────────────

# Ask for confirmation
# Usage: confirm [message] [default=Y|N]
confirm() {
  local message="${1:-Continue?}"
  local default="${2:-Y}"
  
  local prompt
  if [[ "$default" == "Y" ]]; then
    prompt="[Y/n]"
  else
    prompt="[y/N]"
  fi
  
  read -r -p "$message $prompt " response
  [[ -z "$response" ]] && response="$default"
  [[ "$response" =~ ^[Yy]$ ]]
}

# Ask for sensitive input (hidden)
# Usage: ask_secret <prompt> [validation_regex] [error_message]
ask_secret() {
  local prompt="$1"
  local validation_regex="${2:-}"
  local error_message="${3:-Invalid input}"
  local input=""
  
  while [[ -z "$input" ]]; do
    read -r -s -p "$prompt " input
    echo
    
    if [[ -z "$input" ]]; then
      log_error "Input cannot be empty"
      continue
    fi
    
    if [[ -n "$validation_regex" && ! "$input" =~ $validation_regex ]]; then
      log_warn "$error_message"
      if ! confirm "Continue anyway?" "N"; then
        input=""
      fi
    fi
  done
  
  echo "$input"
}

# Ask for public input (visible)
# Usage: ask <prompt> [default_value]
ask() {
  local prompt="$1"
  local default="${2:-}"
  local input
  
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " input
    [[ -z "$input" ]] && input="$default"
  else
    read -r -p "$prompt: " input
  fi
  
  echo "$input"
}

# ── File Operations ───────────────────────────────────────────────────

# Backup file with timestamp
# Usage: backup_file <filepath>
backup_file() {
  local filepath="$1"
  if [[ -f "$filepath" ]]; then
    local backup="${filepath}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$filepath" "$backup"
    log_info "Created backup: ${backup}"
  fi
}

# Replace text in file safely
# Usage: replace_in_file <filepath> <search_pattern> <replacement>
replace_in_file() {
  local filepath="$1"
  local search="$2"
  local replace="$3"
  
  backup_file "$filepath"
  
  # Escape special characters for sed
  local escaped_replace
  escaped_replace=$(echo "$replace" | sed 's/[&/\]/\\&/g')
  
  # macOS and GNU sed have different -i flags
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/${search}/${escaped_replace}/g" "$filepath"
  else
    sed -i "s/${search}/${escaped_replace}/g" "$filepath"
  fi
}

# ── Waiting & Polling ─────────────────────────────────────────────────

# Wait for a command to succeed with timeout
# Usage: wait_for <command> [message] [max_attempts] [delay]
wait_for() {
  local command="$1"
  local message="${2:-Waiting...}"
  local max_attempts="${3:-30}"
  local delay="${4:-2}"
  
  log_info "$message (up to $((max_attempts * delay))s)"
  
  local attempt=1
  while [[ $attempt -le $max_attempts ]]; do
    if eval "$command" >/dev/null 2>&1; then
      return 0
    fi
    
    echo -n "."
    sleep "$delay"
    attempt=$((attempt + 1))
  done
  
  echo ""
  log_error "Timeout after ${max_attempts} attempts"
  return 1
}

# ── Validation ─────────────────────────────────────────────────────────

# Validate SSH public key format
# Usage: is_valid_ssh_key <key_string>
is_valid_ssh_key() {
  local key="$1"
  [[ "$key" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp[0-9]+)\ [A-Za-z0-9+/]+=* ]]
}

# Validate IP address
# Usage: is_valid_ip <ip>
is_valid_ip() {
  local ip="$1"
  [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

# Validate domain name
# Usage: is_valid_domain <domain>
is_valid_domain() {
  local domain="$1"
  [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z0-9.-]+$ ]]
}

# ── Header/Footer ────────────────────────────────────────────────────

# Print script header
# Usage: print_header <title>
print_header() {
  local title="$1"
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  printf "║  %-60s║\n" "$title"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
}

# Print success footer
# Usage: print_footer [message]
print_footer() {
  local message="${1:-Complete!}"
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  printf "║  ✓ %-58s║\n" "$message"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
}

# ── Error Handling ────────────────────────────────────────────────────

# Trap errors and show location
trap_error() {
  local line="$1"
  local command="$2"
  log_error "Error on line ${line}: ${command}"
}

# Enable strict error trapping
enable_error_trap() {
  trap 'trap_error $LINENO "$BASH_COMMAND"' ERR
}
