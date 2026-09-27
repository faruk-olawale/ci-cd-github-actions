#!/usr/bin/env bash
# ==============================================================================
# Docker Build and Smoke Test Script for Assignment 3
# Builds the devops-tool image and executes automated container smoke tests.
# ==============================================================================

set -u

IMAGE_NAME="devops-tool"
FAILED_TESTS=0

echo "=========================================="
echo " Docker Build & Smoke Tests"
echo " Image: $IMAGE_NAME"
echo "=========================================="

# 1. Build the Docker image
echo "Building Docker image '$IMAGE_NAME'..."
if docker build -t "$IMAGE_NAME" .; then
    echo "[PASS] Docker image built successfully."
else
    echo "[FAIL] Docker image build failed." >&2
    exit 1
fi

# Helper function to run container test
run_smoke_test() {
    local test_name="$1"
    local expected_status="$2"  # "zero" or "nonzero" or specific code
    shift 2

    echo "Running smoke test: $test_name..."
    local output
    output=$(docker run --rm "$IMAGE_NAME" "$@" 2>&1)
    local code=$?

    if [[ "$expected_status" == "zero" ]]; then
        if [[ $code -eq 0 ]]; then
            echo "  [PASS] $test_name exited with 0"
        else
            echo "  [FAIL] $test_name expected 0 but exited with $code" >&2
            echo "  Output: $output" >&2
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    elif [[ "$expected_status" == "nonzero" ]]; then
        if [[ $code -ne 0 ]]; then
            echo "  [PASS] $test_name exited with non-zero ($code)"
        else
            echo "  [FAIL] $test_name expected non-zero but exited with 0" >&2
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        if [[ $code -eq "$expected_status" ]]; then
            echo "  [PASS] $test_name exited with expected $expected_status"
        else
            echo "  [FAIL] $test_name expected $expected_status but exited with $code" >&2
            echo "  Output: $output" >&2
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
}

# Smoke test 1: help
run_smoke_test "Container 'help' command" "zero" help

# Smoke test 2: system-info
run_smoke_test "Container 'system-info' command" "zero" system-info

# Smoke test 3: invalid command must fail with non-zero exit code
run_smoke_test "Container 'invalid-command' handling" "nonzero" invalid-command-smoke-test

# Smoke test 4: host resolution / connectivity on localhost
run_smoke_test "Container 'check-host localhost'" "zero" check-host 127.0.0.1

# Smoke test 5: invalid port rejection with exit code 2
run_smoke_test "Container 'check-port localhost 0' rejection" "2" check-port 127.0.0.1 0

echo "=========================================="
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "All Docker smoke tests passed successfully."
    exit 0
else
    echo "Docker smoke tests failed with $FAILED_TESTS failures." >&2
    exit 1
fi
