#!/usr/bin/env bash

# ci.sh
# ----------------------------------------
# CI Environment Detection & Utilities
#
# This script provides utility functions to detect if the current shell
# session is running in a Continuous Integration (CI) environment and
# to retrieve information about the CI provider (e.g., GitHub Actions, GitLab CI).
#
# Intended Usage:
#   - Source this script in other Bash scripts to conditionally adjust
#     behavior for CI vs. local development.
#   - Use the provided functions:
#       is_ci           # Returns 0 if running in CI, 1 otherwise
#       get_ci_provider # Prints the name of the detected CI provider
#       get_ci_info     # Prints detailed CI environment info
#
# Example:
#   source ./scripts/utils/ci.sh
#   if is_ci; then
#       echo "Running in CI: $(get_ci_provider)"
#   fi
#
# This script is used by other project scripts to ensure consistent
# CI detection and reporting across local and automated workflows.
# ----------------------------------------

# Check if we're in a CI environment
is_ci() {
    [ "${CI:-false}" = "true" ] || [ "${GITHUB_ACTIONS:-false}" = "true" ] || [ "${GITLAB_CI:-false}" = "true" ] || [ "${JENKINS_URL:-}" != "" ] || [ "${BUILDKITE:-false}" = "true" ] || [ "${CIRCLECI:-false}" = "true" ] || [ "${TRAVIS:-false}" = "true" ]
}

# Get CI provider name
get_ci_provider() {
    if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
        echo "GitHub Actions"
    elif [ "${GITLAB_CI:-false}" = "true" ]; then
        echo "GitLab CI"
    elif [ "${JENKINS_URL:-}" != "" ]; then
        echo "Jenkins"
    elif [ "${BUILDKITE:-false}" = "true" ]; then
        echo "Buildkite"
    elif [ "${CIRCLECI:-false}" = "true" ]; then
        echo "CircleCI"
    elif [ "${TRAVIS:-false}" = "true" ]; then
        echo "Travis CI"
    elif [ "${CI:-false}" = "true" ]; then
        echo "Generic CI"
    else
        echo "Local"
    fi
}

# Get CI environment information
get_ci_info() {
    local provider
    provider=$(get_ci_provider)

    echo "CI Provider: $provider"
    if is_ci; then
        echo "CI Environment: true"
        if [ -n "${GITHUB_REPOSITORY:-}" ]; then
            echo "Repository: $GITHUB_REPOSITORY"
        fi
        if [ -n "${GITHUB_REF:-}" ]; then
            echo "Ref: $GITHUB_REF"
        fi
        if [ -n "${GITHUB_SHA:-}" ]; then
            echo "Commit: $GITHUB_SHA"
        fi
        if [ -n "${GITHUB_ACTOR:-}" ]; then
            echo "Actor: $GITHUB_ACTOR"
        fi
    else
        echo "CI Environment: false"
    fi
}

# Check if we should use direct commands vs mise tasks
should_use_direct_commands() {
    is_ci
}

# Get appropriate command prefix for the environment
get_command_prefix() {
    if should_use_direct_commands; then
        echo "direct"
    else
        echo "mise"
    fi
}
