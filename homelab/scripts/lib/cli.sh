# lib/cli.sh — Common CLI utilities for homelab commands
#
# Source after common.sh:
#   source "$(dirname "$0")/lib/common.sh"
#   source "$(dirname "$0")/lib/cli.sh"
#

# ── CLI State ──────────────────────────────────────────────
readonly CLI_DRY_RUN="${CLI_DRY_RUN:-0}"
readonly CLI_VERBOSE="${CLI_VERBOSE:-0}"
readonly CLI_QUIET="${CLI_QUIET:-0}"

# ── Usage / Help ───────────────────────────────────────────

# Show standard help message
# Usage: show_help <script_name> <description> <args_description>
show_help() {
  local script_name="$1"
  local description="$2"
  shift 2
  
  cat <<EOF
${description}

Usage: ${script_name} [OPTIONS] [COMMAND]

Options:
  -h, --help        Show this help message
  -v, --verbose     Enable verbose output
  -n, --dry-run     Show what would be done without executing
  -q, --quiet       Suppress non-error output

Commands:
$(printf '  %-16s %s\n' "$@")

Examples:
  ${script_name}
  ${script_name} --help
  ${script_name} --dry-run

EOF
}

# ── Argument Parsing ─────────────────────────────────────────

# Parse standard CLI flags
# Usage: parse_cli_flags "$@" (modifies positional params)
parse_cli_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        return 1  # Signal caller to show help
        ;;
      -v|--verbose)
        export CLI_VERBOSE=1
        export DEBUG=1
        set -x
        shift
        ;;
      -n|--dry-run)
        export CLI_DRY_RUN=1
        log_info "DRY RUN MODE: No changes will be made"
        shift
        ;;
      -q|--quiet)
        export CLI_QUIET=1
        # Redefine log_info to do nothing
        eval 'log_info() { :; }'
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        log_error "Unknown option: $1"
        return 1
        ;;
      *)
        break
        ;;
    esac
  done
  
  # Return remaining args
  echo "$@"
}

# Check if dry run mode is enabled
is_dry_run() {
  [[ "$CLI_DRY_RUN" == "1" ]]
}

# Execute command or print in dry run mode
# Usage: run_or_print <command>
run_or_print() {
  if is_dry_run; then
    log_info "[DRY RUN] Would execute: $*"
  else
    "$@"
  fi
}

# ── Environment Requirements ──────────────────────────────

# Require environment variable to be set
require_env_var() {
  local var_name="$1"
  local description="${2:-$var_name}"
  
  if [[ -z "${!var_name:-}" ]]; then
    log_error "Required environment variable not set: ${var_name}"
    log_info "This should be: ${description}"
    log_info "Set it in .env or export it:"
    log_info "  export ${var_name}=value"
    return 1
  fi
}

# Require multiple environment variables
require_env_vars() {
  local missing=0
  for var in "$@"; do
    if ! require_env_var "$var"; then
      ((missing++))
    fi
  done
  
  if [[ $missing -gt 0 ]]; then
    return 1
  fi
}

# ── Subcommand Dispatch ────────────────────────────────────

# Dispatch to subcommand handler
# Usage: dispatch <default_cmd> <cmd1> <handler1> [cmd2] [handler2] ...
dispatch() {
  local default_cmd="$1"
  shift
  
  local cmd="${1:-$default_cmd}"
  shift || true
  
  # Build command map
  declare -A handlers
  while [[ $# -ge 2 ]]; do
    handlers["$1"]="$2"
    shift 2
  done
  
  if [[ -n "${handlers[$cmd]:-}" ]]; then
    "${handlers[$cmd]}" "$@"
  else
    log_error "Unknown command: $cmd"
    log_info "Available commands:"
    for key in "${!handlers[@]}"; do
      log_info "  - $key"
    done
    return 1
  fi
}

# ── Progress Indicators ──────────────────────────────────

# Show spinner while command runs
# Usage: with_spinner <message> <command>
with_spinner() {
  local message="$1"
  shift
  local pid
  
  log_info "$message..."
  
  "$@" &
  pid=$!
  
  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  local i=0
  
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i + 1) % 8 ))
    printf "\r%s %s" "${spin:$i:1}" "$message..."
    sleep 0.1
  done
  
  printf "\r"
  
  wait $pid
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    log_ok "$message complete"
  else
    log_error "$message failed"
  fi
  
  return $exit_code
}

# ── Menu System ────────────────────────────────────────────

# Show menu and get selection
# Usage: select_option <prompt> <option1> <option2> ...
select_option() {
  local prompt="$1"
  shift
  
  echo ""
  log_step "$prompt"
  echo ""
  
  local i=1
  local options=("$@")
  
  for option in "${options[@]}"; do
    echo "  $i) $option"
    ((i++))
  done
  
  echo ""
  local selection
  while true; do
    read -r -p "Select [1-$((i-1))]: " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && \
       [[ "$selection" -ge 1 ]] && \
       [[ "$selection" -lt $i ]]; then
      echo "${options[$((selection-1))]}"
      return 0
    fi
    log_warn "Invalid selection, please try again"
  done
}

# ── Error Handling ─────────────────────────────────────────

# Exit with error code and message
fail() {
  local message="${1:-Operation failed}"
  local code="${2:-1}"
  
  log_error "$message"
  exit "$code"
}

# Check last command and fail if error
check_fail() {
  local code=$?
  local message="$1"
  
  if [[ $code -ne 0 ]]; then
    fail "$message" "$code"
  fi
}

# Cleanup function registration
declare -a CLEANUP_FUNCTIONS=()

# Register cleanup function
# Usage: on_exit <function_name>
on_exit() {
  CLEANUP_FUNCTIONS+=("$1")
}

# Run all registered cleanup functions
run_cleanup() {
  for func in "${CLEANUP_FUNCTIONS[@]}"; do
    $func 2>/dev/null || true
  done
}

# Set trap to run cleanup on exit
trap run_cleanup EXIT
