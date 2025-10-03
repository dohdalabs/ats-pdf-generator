#!/usr/bin/env bash

# extract-versions.sh
#
# Extracts tool versions from mise.toml for use in CI pipelines and automation.
# Ensures version consistency between local development (using mise) and CI jobs.
#
# Usage:
#   ./scripts/extract-versions.sh <tool>
#     Prints the version of the specified tool (e.g., python, node, pnpm) as defined in mise.toml.
#
#   ./scripts/extract-versions.sh env
#     Outputs all relevant tool versions as environment variables for CI consumption.
#
# Intended for use in CI workflows and scripts that need to dynamically retrieve tool versions.

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MISE_TOML="$PROJECT_ROOT/mise.toml"

# Check if mise.toml exists
if [ ! -f "$MISE_TOML" ]; then
    echo "Error: mise.toml not found at $MISE_TOML" >&2
    exit 1
fi

# Function to extract version from mise.toml
extract_version() {
    local tool="$1"

    # Parse TOML file by finding the tools section and then the tool
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

# Main function
main() {
    local action="${1:-env}"

    case "$action" in
        "env")
            # Output as environment variables for CI
            echo "# Tool versions extracted from mise.toml"
            echo "PYTHON_VERSION=$(extract_version python)"
            echo "UV_VERSION=$(extract_version uv)"
            echo "SHELLCHECK_VERSION=$(extract_version shellcheck)"
            echo "HADOLINT_VERSION=$(extract_version hadolint)"
            echo "NODE_VERSION=$(extract_version node)"
            echo "PNPM_VERSION=$(extract_version pnpm)"
            ;;
        "python")
            extract_version python
            ;;
        "uv")
            extract_version uv
            ;;
        "shellcheck")
            extract_version shellcheck
            ;;
        "hadolint")
            extract_version hadolint
            ;;
        "node")
            extract_version node
            ;;
        "pnpm")
            extract_version pnpm
            ;;
        "list")
            echo "Tool versions from mise.toml:"
            echo "=============================="
            echo "python: $(extract_version python)"
            echo "uv: $(extract_version uv)"
            echo "shellcheck: $(extract_version shellcheck)"
            echo "hadolint: $(extract_version hadolint)"
            echo "node: $(extract_version node)"
            echo "pnpm: $(extract_version pnpm)"
            ;;
        *)
            echo "Usage: $0 {env|python|uv|shellcheck|hadolint|node|pnpm|list}" >&2
            echo ""
            echo "Commands:"
            echo "  env          - Output as environment variables for CI"
            echo "  python       - Get Python version"
            echo "  uv           - Get UV version"
            echo "  shellcheck   - Get shellcheck version"
            echo "  hadolint     - Get hadolint version"
            echo "  node         - Get Node.js version"
            echo "  pnpm         - Get pnpm version"
            echo "  list         - List all versions"
            exit 1
            ;;
    esac
}

main "$@"
