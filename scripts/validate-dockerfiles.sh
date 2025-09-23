#!/bin/bash
#
# Dockerfile Static Analysis Script
#
# SYNOPSIS
#     validate-dockerfiles.sh [--help|-h] [dockerfile...]
#
# DESCRIPTION
#     Validates Dockerfiles using static analysis tools without building them.
#     Currently uses hadolint for comprehensive Dockerfile linting including
#     syntax validation and best practices checking.
#
#     If specific dockerfile paths are provided as arguments, only those files
#     will be validated. Otherwise, all Dockerfile.* files in the docker/
#     directory will be validated.
#
# OPTIONS
#     --help, -h    Show this help message and exit
#
# PREREQUISITES
#     hadolint      Must be pre-installed (managed by mise in development)
#
# EXAMPLES
#     validate-dockerfiles.sh                    # Validate all Dockerfiles
#     validate-dockerfiles.sh docker/Dockerfile.alpine  # Validate specific file
#     validate-dockerfiles.sh --help            # Show help
#
# EXIT STATUS
#     0    All Dockerfiles passed validation
#     1    One or more Dockerfiles failed validation or hadolint not found
#
# AUTHOR
#     Generated for ats-pdf-generator project
#
# SEE ALSO
#     hadolint(1), mise(1)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print informational message with blue prefix
# Arguments: $1 - message to display
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print success message with green prefix
# Arguments: $1 - message to display
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print warning message with yellow prefix
# Arguments: $1 - message to display
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print error message with red prefix
# Arguments: $1 - message to display
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if hadolint is available in PATH
#
# This function verifies that the hadolint command is available and
# exits with error code 1 if not found, providing installation
# instructions for different environments.
#
# Exit Status:
#   0    hadolint is available
#   1    hadolint not found (script exits)
#
# Side Effects:
#   - Exits script if hadolint not found
#   - Prints error messages with installation instructions
check_hadolint() {
    if ! command -v hadolint &> /dev/null; then
        log_error "hadolint not found. Please install it using:"
        log_error "  - Development: mise install (managed by mise.toml)"
        log_error "  - CI: Install via your CI environment"
        log_error "  - Manual: brew install hadolint (macOS) or download from GitHub releases"
        exit 1
    fi
}

# Run hadolint analysis on a Dockerfile
#
# Arguments:
#   $1  Path to the Dockerfile to analyze
#
# Returns:
#   0   Analysis passed (no errors, warnings are non-fatal)
#   1   Analysis failed (errors detected)
#
# Side Effects:
#   - Prints hadolint output to stdout
#   - Logs success/warning/error messages
#   - Counts and reports warnings vs errors
run_hadolint() {
    local dockerfile="$1"
    log_info "Analyzing $dockerfile with hadolint..."

    # Run hadolint and capture output
    local hadolint_output
    hadolint_output=$(hadolint "$dockerfile" 2>&1)
    local hadolint_exit_code=$?

    # Show hadolint output
    echo "$hadolint_output"

    # Count warnings vs errors
    local warnings
    local errors
    warnings=$(echo "$hadolint_output" | grep -c "warning\|info" || true)
    errors=$(echo "$hadolint_output" | grep -c "error" || true)

    if [ $hadolint_exit_code -eq 0 ]; then
        log_success "$dockerfile passed hadolint analysis"
        return 0
    elif [ $errors -eq 0 ] && [ $warnings -gt 0 ]; then
        log_warning "$dockerfile has $warnings hadolint warning(s) (non-fatal)"
        return 0
    else
        log_error "$dockerfile failed hadolint analysis with $errors error(s)"
        return 1
    fi
}


# Validate a Dockerfile using static analysis tools
#
# This function validates a given Dockerfile using hadolint for static
# analysis. It reports any warnings or errors found and returns appropriate
# exit codes. The function is designed to be called for each Dockerfile
# in the repository and can be extended to include additional linting tools.
#
# Arguments:
#   $1  Path to the Dockerfile to validate
#
# Returns:
#   0   Dockerfile passes validation (no fatal errors)
#   1   Dockerfile fails validation (fatal errors detected)
#
# Side Effects:
#   - Prints validation progress and results
#   - Logs success/failure messages
#
# Example:
#   validate_dockerfile "docker/Dockerfile.standard"
#   for file in docker/Dockerfile.*; do
#       validate_dockerfile "$file"
#   done
validate_dockerfile() {
    local dockerfile="$1"

    echo "🔍 Validating $dockerfile..."

    # Run hadolint analysis
    if ! run_hadolint "$dockerfile"; then
        return 1
    fi

    return 0
}

# Main execution function for Dockerfile validation
#
# This function orchestrates the entire validation process:
# 1. Checks prerequisites (hadolint availability)
# 2. Discovers Dockerfiles (either from arguments or docker/ directory)
# 3. Validates each Dockerfile using hadolint
# 4. Provides summary of results
#
# Arguments:
#   $@  Optional list of specific Dockerfile paths to validate
#
# Returns:
#   0   All Dockerfiles passed validation
#   1   One or more Dockerfiles failed validation or no Dockerfiles found
#
# Side Effects:
#   - Prints progress and results to stdout
#   - Exits script with appropriate exit code
main() {
    log_info "Starting Dockerfile static analysis..."

    # Check prerequisites
    check_hadolint

    # Determine which Dockerfiles to validate
    local dockerfiles=()

    if [ $# -gt 0 ]; then
        # Use provided file arguments
        dockerfiles=("$@")
        log_info "Validating ${#dockerfiles[@]} specified Dockerfile(s)"
    else
        # Find all Dockerfiles in docker/ directory
        while IFS= read -r -d '' file; do
            dockerfiles+=("$file")
        done < <(find docker -name "Dockerfile.*" -print0)

        if [ ${#dockerfiles[@]} -eq 0 ]; then
            log_error "No Dockerfiles found in docker/ directory"
            exit 1
        fi

        log_info "Found ${#dockerfiles[@]} Dockerfiles to validate"
    fi

    # Validate each Dockerfile
    local total_failed=0
    for dockerfile in "${dockerfiles[@]}"; do
        if [ ! -f "$dockerfile" ]; then
            log_error "Dockerfile not found: $dockerfile"
            ((total_failed++))
            continue
        fi

        if ! validate_dockerfile "$dockerfile"; then
            ((total_failed++))
        fi
        echo ""
    done

    # Summary
    if [ $total_failed -eq 0 ]; then
        log_success "All Dockerfiles passed static analysis! ✅"
        exit 0
    else
        log_error "$total_failed Dockerfile(s) failed validation"
        exit 1
    fi
}

# Show usage if help requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat << EOF
Dockerfile Static Analysis Script

SYNOPSIS
    $0 [--help|-h] [dockerfile...]

DESCRIPTION
    Validates Dockerfiles using static analysis tools without building them.
    Currently uses hadolint for comprehensive Dockerfile linting including
    syntax validation and best practices checking.

    If specific dockerfile paths are provided as arguments, only those files
    will be validated. Otherwise, all Dockerfile.* files in the docker/
    directory will be validated.

OPTIONS
    --help, -h    Show this help message and exit

PREREQUISITES
    hadolint      Must be pre-installed (managed by mise in development)

EXAMPLES
    $0                                    # Validate all Dockerfiles
    $0 docker/Dockerfile.alpine          # Validate specific file
    $0 docker/Dockerfile.*               # Validate multiple files
    $0 --help                            # Show this help

EXIT STATUS
    0    All Dockerfiles passed validation
    1    One or more Dockerfiles failed validation or hadolint not found

AUTHOR
    Generated for ats-pdf-generator project

SEE ALSO
    hadolint(1), mise(1)
EOF
    exit 0
fi

# Run main function with all arguments except help
main "$@"
