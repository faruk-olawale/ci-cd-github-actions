#!/usr/bin/env bash
# ==============================================================================
# Linting Script for Assignment 3
# Validates project structure, required files, and Bash syntax.
# ==============================================================================

set -u

ERRORS=0

echo "=== Running DevOps Project Linter ==="

# 1. Check required repository files
REQUIRED_FILES=(
    "README.md"
    "app/app.sh"
    "scripts/lint.sh"
    "scripts/build.sh"
    "tests/test.sh"
    "Dockerfile"
    "compose.yaml"
    ".dockerignore"
    ".github/workflows/ci.yml"
)

echo "--- Checking Required Files ---"
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "[OK] Found $file"
    else
        echo "[FAIL] Missing required file: $file" >&2
        ERRORS=$((ERRORS + 1))
    fi
done

# 2. Check executable permissions
echo "--- Checking Executable Permissions ---"
SCRIPTS_TO_EXEC=(
    "app/app.sh"
    "scripts/lint.sh"
    "scripts/build.sh"
    "tests/test.sh"
)

for script in "${SCRIPTS_TO_EXEC[@]}"; do
    if [[ -f "$script" ]]; then
        if [[ -x "$script" ]]; then
            echo "[OK] Executable: $script"
        else
            echo "[FAIL] Script not executable: $script" >&2
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# 3. Check Bash syntax with bash -n
echo "--- Checking Bash Syntax ---"
ALL_SCRIPTS=$(find . -name "*.sh" -not -path "*/.*" 2>/dev/null)
for script in $ALL_SCRIPTS; do
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>&1; then
            echo "[OK] Bash syntax valid: $script"
        else
            echo "[FAIL] Syntax error in: $script" >&2
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# 4. Optional ShellCheck
echo "--- Checking ShellCheck (if available) ---"
if command -v shellcheck >/dev/null 2>&1; then
    echo "Running shellcheck..."
    for script in $ALL_SCRIPTS; do
        if shellcheck -e SC1090,SC1091 "$script"; then
            echo "[OK] ShellCheck passed: $script"
        else
            echo "[WARN] ShellCheck warnings for: $script"
        fi
    done
else
    echo "[INFO] ShellCheck not installed; skipped static analysis."
fi

# Summary
echo "======================================"
if [[ $ERRORS -eq 0 ]]; then
    echo "Linting Passed: All checks successful."
    exit 0
else
    echo "Linting Failed: $ERRORS errors found." >&2
    exit 1
fi
