#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MISE_TOML="$PROJECT_ROOT/mise.toml"

# Simple logging functions
log_info() {
    echo "INFO: $*"
}

log_error() {
    echo "ERROR: $*" >&2
}

show_usage() {
    cat <<'USAGE_EOF'
SYNOPSIS
    extract-versions.sh [OPTIONS] {env|python|uv|shellcheck|hadolint|node|pnpm|just|trivy|list}

DESCRIPTION
    Extract tool versions from mise.toml for reuse in CI and automation.
    Supports printing individual values or emitting shell-friendly environment
    variables for pipelines.

OPTIONS
    -h, --help              Show this help message and exit

EXAMPLES
    ./scripts/extract-versions.sh env
    ./scripts/extract-versions.sh python
    ./scripts/extract-versions.sh just
    ./scripts/extract-versions.sh trivy
    ./scripts/extract-versions.sh list

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

# Parse command line arguments
SHOW_HELP=false
ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    show_usage
    exit 0
fi

# Set remaining arguments
set -- "${ARGS[@]}"

if [ ! -f "$MISE_TOML" ]; then
    log_error "mise.toml not found at $MISE_TOML"
    exit 1
fi

extract_version() {
    local tool="$1"
    awk -v tool="$tool" '
    BEGIN { in_section = 0 }
    /^\[tools\]/ { in_section = 1; next }
    /^\[/ { in_section = 0 }
    in_section {
        prefix = tool " = \""
        if (index($0, prefix) == 1) {
            split($0, parts, "\"")
            print parts[2]
            exit
        }
    }
    ' "$MISE_TOML"
}

main() {
    local action="${1:-env}"

    case "$action" in
        env)
            echo "PYTHON_VERSION=$(extract_version python)"
            echo "UV_VERSION=$(extract_version uv)"
            echo "SHELLCHECK_VERSION=$(extract_version shellcheck)"
            echo "HADOLINT_VERSION=$(extract_version hadolint)"
            echo "NODE_VERSION=$(extract_version node)"
            echo "PNPM_VERSION=$(extract_version pnpm)"
            echo "JUST_VERSION=$(extract_version just)"
            echo "TRIVY_VERSION=$(extract_version trivy)"
            ;;
        python)
            extract_version python
            ;;
        uv)
            extract_version uv
            ;;
        shellcheck)
            extract_version shellcheck
            ;;
        hadolint)
            extract_version hadolint
            ;;
        node)
            extract_version node
            ;;
        pnpm)
            extract_version pnpm
            ;;
        just)
            extract_version just
            ;;
        trivy)
            extract_version trivy
            ;;
        list)
            log_info "Tool versions from mise.toml:"
            log_info "=============================="
            log_info "python: $(extract_version python)"
            log_info "uv: $(extract_version uv)"
            log_info "shellcheck: $(extract_version shellcheck)"
            log_info "hadolint: $(extract_version hadolint)"
            log_info "node: $(extract_version node)"
            log_info "pnpm: $(extract_version pnpm)"
            log_info "just: $(extract_version just)"
            log_info "trivy: $(extract_version trivy)"
            ;;
        *)
            log_error "Unknown command: $action"
            show_usage
            exit 2
            ;;
    esac
}

main "$@"
