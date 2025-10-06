#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MISE_TOML="$PROJECT_ROOT/mise.toml"

source "$SCRIPT_DIR/utils/logging.sh"
source "$SCRIPT_DIR/utils/common.sh"

init_logger

show_usage() {
    cat <<'USAGE_EOF'
SYNOPSIS
    extract-versions.sh [OPTIONS] {env|python|uv|shellcheck|hadolint|node|pnpm|list}

DESCRIPTION
    Extract tool versions from mise.toml for reuse in CI and automation.
    Supports printing individual values or emitting shell-friendly environment
    variables for pipelines.

OPTIONS
    -h, --help              Show this help message and exit

EXAMPLES
    ./scripts/extract-versions.sh env
    ./scripts/extract-versions.sh python
    ./scripts/extract-versions.sh list

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

if ! parse_common_flags "$@"; then
    show_usage
    exit 2
fi

if [ ${#COMMON_FLAGS_REMAINING[@]} -gt 0 ]; then
    set -- "${COMMON_FLAGS_REMAINING[@]}"
else
    set --
fi

if [ "$COMMON_FLAG_SHOW_HELP" = true ]; then
    show_usage
    exit 0
fi

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
    in_section && $0 ~ "^" tool " = " {
        gsub(/^[^"]*"/, "", $0)
        gsub(/".*$/, "", $0)
        print $0
        exit
    }
    ' "$MISE_TOML"
}

main() {
    local action="${1:-env}"

    case "$action" in
        env)
            log_info "# Tool versions extracted from mise.toml"
            echo "PYTHON_VERSION=$(extract_version python)"
            echo "UV_VERSION=$(extract_version uv)"
            echo "SHELLCHECK_VERSION=$(extract_version shellcheck)"
            echo "HADOLINT_VERSION=$(extract_version hadolint)"
            echo "NODE_VERSION=$(extract_version node)"
            echo "PNPM_VERSION=$(extract_version pnpm)"
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
        list)
            log_info "Tool versions from mise.toml:"
            log_info "=============================="
            log_info "python: $(extract_version python)"
            log_info "uv: $(extract_version uv)"
            log_info "shellcheck: $(extract_version shellcheck)"
            log_info "hadolint: $(extract_version hadolint)"
            log_info "node: $(extract_version node)"
            log_info "pnpm: $(extract_version pnpm)"
            ;;
        *)
            log_error "Unknown command: $action"
            show_usage
            exit 2
            ;;
    esac
}

main "$@"
