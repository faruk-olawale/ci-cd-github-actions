#!/usr/bin/env bash
# ==============================================================================
# Automated Test Suite for Assignment 3
# Covers at least 8 meaningful tests for CLI functionality, input validation,
# network checks, and exit codes.
# ==============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BIN="$APP_DIR/app/app.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "  [PASS] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "  [FAIL] $1: $2" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_exit_code() {
    local test_name="$1"
    local expected_code="$2"
    shift 2
    local output
    output=$("$@" 2>&1)
    local actual_code=$?

    if [[ "$actual_code" -eq "$expected_code" ]]; then
        pass "$test_name (expected $expected_code, got $actual_code)"
    else
        fail "$test_name" "Expected exit code $expected_code but got $actual_code. Output: $output"
    fi
}

assert_output_contains() {
    local test_name="$1"
    local expected_substring="$2"
    shift 2
    local output
    output=$("$@" 2>&1)
    local actual_code=$?

    if echo "$output" | grep -qi "$expected_substring"; then
        pass "$test_name (output contains '$expected_substring')"
    else
        fail "$test_name" "Output did not contain '$expected_substring'. Output was: $output"
    fi
}

echo "================================================="
echo " Running Automated Student Test Suite"
echo " Target Binary: $APP_BIN"
echo "================================================="

# Test 1: help command returns exit code 0
assert_exit_code "Test 1: 'help' command returns exit 0" 0 "$APP_BIN" help

# Test 2: help command displays usage information
assert_output_contains "Test 2: 'help' displays usage output" "Usage:" "$APP_BIN" help

# Test 3: system-info command returns exit code 0
assert_exit_code "Test 3: 'system-info' returns exit 0" 0 "$APP_BIN" system-info

# Test 4: system-info contains system metrics
assert_output_contains "Test 4: 'system-info' outputs hostname and OS" "Hostname:" "$APP_BIN" system-info

# Test 5: missing command returns exit code 2
assert_exit_code "Test 5: Missing command returns exit 2" 2 "$APP_BIN"

# Test 6: invalid command returns exit code 2
assert_exit_code "Test 6: Invalid command returns exit 2" 2 "$APP_BIN" nonexistent-cmd-xyz

# Test 7: missing host argument in check-host returns exit code 2
assert_exit_code "Test 7: 'check-host' missing argument returns exit 2" 2 "$APP_BIN" check-host

# Test 8: valid host check resolves successfully and returns exit code 0
assert_exit_code "Test 8: 'check-host 127.0.0.1' returns exit 0" 0 "$APP_BIN" check-host 127.0.0.1

# Test 9: missing port argument in check-port returns exit code 2
assert_exit_code "Test 9: 'check-port' missing port argument returns exit 2" 2 "$APP_BIN" check-port localhost

# Test 10: non-numeric port in check-port returns exit code 2
assert_exit_code "Test 10: 'check-port' non-numeric port returns exit 2" 2 "$APP_BIN" check-port localhost abc

# Test 11: out-of-range port 0 returns exit code 2
assert_exit_code "Test 11: 'check-port' port 0 returns exit 2" 2 "$APP_BIN" check-port localhost 0

# Test 12: out-of-range port 65536 returns exit code 2
assert_exit_code "Test 12: 'check-port' port 65536 returns exit 2" 2 "$APP_BIN" check-port localhost 65536

# Test 13: closed port check returns operational failure exit code 1
assert_exit_code "Test 13: 'check-port' closed port returns exit 1" 1 "$APP_BIN" check-port 127.0.0.1 65432

echo "================================================="
echo "Test Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "================================================="

if [[ $FAIL_COUNT -eq 0 ]]; then
    exit 0
else
    exit 1
fi
