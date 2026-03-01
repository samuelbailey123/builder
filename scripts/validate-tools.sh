#!/usr/bin/env bash
# validate-tools.sh — verify every tool installed in the builder image.
# Exits non-zero if any tool is missing or fails its version check.
set -euo pipefail

PASS=0
FAIL=0
FAILED_TOOLS=""

check() {
    local name="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        printf "  %-20s OK\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "  %-20s FAIL\n" "$name"
        FAIL=$((FAIL + 1))
        FAILED_TOOLS="${FAILED_TOOLS} ${name}"
    fi
}

echo "=== Cloud CLIs ==="
check "aws"         aws --version
check "gcloud"      gcloud --version
check "az"          az --version
check "vault"       vault --version

echo ""
echo "=== Languages & Runtimes ==="
check "go"          go version
check "python3"     python3 --version
check "pip3"        pip3 --version
check "node"        node --version
check "npm"         npm --version

echo ""
echo "=== Container & Image Tools ==="
check "docker"      docker --version
check "buildx"      docker buildx version
check "trivy"       trivy --version
check "hadolint"    hadolint --version
check "dive"        dive --version

echo ""
echo "=== Kubernetes & IaC ==="
check "kubectl"     kubectl version --client
check "helm"        helm version --short
check "terraform"   terraform --version

echo ""
echo "=== Debugging ==="
check "strace"      strace -V
check "ltrace"      ltrace -V
check "tcpdump"     tcpdump --version
check "netstat"     netstat --version
check "dig"         dig -v
check "htop"        htop --version

echo ""
echo "=== Build & Dev Utilities ==="
check "git"         git --version
check "make"        make --version
check "curl"        curl --version
check "wget"        wget --version
check "jq"          jq --version
check "yq"          yq --version
check "vim"         vim --version
check "unzip"       unzip -v
check "shellcheck"  shellcheck --version

echo ""
echo "==============================="
printf "PASS: %d   FAIL: %d\n" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo "FAILED TOOLS:${FAILED_TOOLS}"
    exit 1
fi

echo "All tools validated successfully."
exit 0
