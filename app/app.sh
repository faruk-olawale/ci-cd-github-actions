#!/usr/bin/env bash
# ==============================================================================
# DevOps Diagnostic CLI Application
# Provides system information, host resolution/connectivity, and port validation.
# ==============================================================================

set -u

# Resolve host to IP address
resolve_host() {
    local target="$1"
    local ip=""

    if command -v getent >/dev/null 2>&1; then
        ip=$(getent ahosts "$target" 2>/dev/null | awk '{print $1}' | head -n 1)
        if [[ -z "$ip" ]]; then
            ip=$(getent hosts "$target" 2>/dev/null | awk '{print $1}' | head -n 1)
        fi
    fi

    if [[ -z "$ip" ]] && command -v nslookup >/dev/null 2>&1; then
        ip=$(nslookup "$target" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -n 1)
    fi

    if [[ -z "$ip" ]] && command -v host >/dev/null 2>&1; then
        ip=$(host "$target" 2>/dev/null | awk '/has address/ { print $4 }' | head -n 1)
    fi

    if [[ -z "$ip" ]]; then
        # Check if already an IPv4 address
        if [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            ip="$target"
        fi
    fi

    echo "$ip"
}

# Perform basic connectivity check via ICMP ping
check_connectivity() {
    local target="$1"
    if ping -c 2 -W 2 "$target" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Subcommand: system-info
cmd_system_info() {
    echo "=========================================="
    echo " System Information Diagnostic"
    echo "=========================================="
    echo "Hostname:         $(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo 'Unknown')"
    echo "Current User:     $(whoami 2>/dev/null || id -un 2>/dev/null || echo "${USER:-unknown}")"
    echo "Date/Time:        $(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || date)"

    local os_info="Unknown"
    if [[ -f /etc/os-release ]]; then
        os_info=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    fi
    echo "Operating System: $os_info ($(uname -s 2>/dev/null || echo 'Linux'))"
    echo "Kernel Version:   $(uname -r 2>/dev/null || echo 'Unknown')"
    echo "Uptime:           $(uptime -p 2>/dev/null || uptime 2>/dev/null || echo 'N/A')"

    local cpu_arch
    cpu_arch=$(uname -m 2>/dev/null || echo 'Unknown')
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '1')
    local cpu_model="Unknown"
    if [[ -f /proc/cpuinfo ]]; then
        cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo 'Unknown')
    fi
    echo "CPU Architecture: $cpu_arch ($cpu_cores cores)"
    echo "CPU Model:        $cpu_model"

    echo "Memory Usage:"
    if command -v free >/dev/null 2>&1; then
        free -h 2>/dev/null || free 2>/dev/null || echo "Unable to query memory"
    elif [[ -f /proc/meminfo ]]; then
        grep -E 'MemTotal|MemFree|MemAvailable' /proc/meminfo 2>/dev/null || echo "Memory info unavailable"
    else
        echo "Memory details unavailable"
    fi

    echo "Working Directory: $(pwd)"
    return 0
}

# Subcommand: check-host <host>
cmd_check_host() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        echo "Error: Hostname or IP address required." >&2
        echo "Usage: ./app/app.sh check-host <host>" >&2
        return 2
    fi

    echo "=== Host Diagnostics: $target ==="
    local ip
    ip=$(resolve_host "$target")

    if [[ -n "$ip" ]]; then
        echo "Resolution: Host '$target' resolved to $ip"
    else
        echo "Resolution: Failed to resolve host '$target'" >&2
        return 1
    fi

    echo "Checking ICMP connectivity for '$target'..."
    if check_connectivity "$target"; then
        echo "Connectivity: Host '$target' ($ip) is reachable."
        return 0
    else
        echo "Connectivity: Host '$target' ($ip) is unreachable via ICMP." >&2
        return 1
    fi
}

# Subcommand: check-port <host> <port>
cmd_check_port() {
    local target="${1:-}"
    local port="${2:-}"

    if [[ -z "$target" || -z "$port" ]]; then
        echo "Error: Both host and port arguments are required." >&2
        echo "Usage: ./app/app.sh check-port <host> <port>" >&2
        return 2
    fi

    # Validate that port is strictly numeric
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be an integer between 1 and 65535. Received: '$port'" >&2
        return 2
    fi

    # Enforce base-10 numerical evaluation
    local port_num=$(( 10#$port ))

    # Validate port bounds 1 - 65535
    if (( port_num < 1 || port_num > 65535 )); then
        echo "Error: Port out of range (1-65535). Received: $port_num" >&2
        return 2
    fi

    echo "=== TCP Port Check: $target:$port_num ==="

    # Test TCP connectivity
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 3 "$target" "$port_num" >/dev/null 2>&1; then
            echo "Status: Connection to $target on TCP port $port_num SUCCEEDED."
            return 0
        else
            echo "Status: Connection to $target on TCP port $port_num FAILED (Connection refused or timed out)." >&2
            return 1
        fi
    else
        if timeout 3 bash -c "</dev/tcp/$target/$port_num" 2>/dev/null; then
            echo "Status: Connection to $target on TCP port $port_num SUCCEEDED."
            return 0
        else
            echo "Status: Connection to $target on TCP port $port_num FAILED (Connection refused or timed out)." >&2
            return 1
        fi
    fi
}

# Subcommand: help
cmd_help() {
    cat << 'HELP_EOF'
DevOps CI/CD Diagnostic Utility

Usage:
  ./app/app.sh <command> [arguments]

Commands:
  system-info                     Display system metrics and diagnostic information
  check-host <host>               Resolve host and test network connectivity
  check-port <host> <port>        Validate port and test TCP connectivity (1-65535)
  help                            Display this help and usage message

Options:
  -h, --help                      Display this help and usage message

Exit Codes:
  0 - Success
  1 - Operational/runtime failure (e.g. host unreachable, port connection failed)
  2 - Invalid command, missing argument, or invalid input

Examples:
  ./app/app.sh system-info
  ./app/app.sh check-host localhost
  ./app/app.sh check-port localhost 80
  ./app/app.sh help
HELP_EOF
    return 0
}

# ------------------------------------------------------------------------------
# Entry Point & Argument Parsing
# ------------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
    echo "Error: No command provided." >&2
    echo "Run './app/app.sh help' for usage instructions." >&2
    exit 2
fi

COMMAND="$1"
shift

case "$COMMAND" in
    system-info)
        cmd_system_info "$@"
        exit $?
        ;;
    check-host)
        cmd_check_host "$@"
        exit $?
        ;;
    check-port)
        cmd_check_port "$@"
        exit $?
        ;;
    help|--help|-h)
        cmd_help "$@"
        exit 0
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'." >&2
        echo "Run './app/app.sh help' for available commands." >&2
        exit 2
        ;;
esac

# Intentional syntax violation for CI failure demo
if [[ "intentional_syntax_error" == "test" ]]; then
    echo "This block is unclosed syntax error"
