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

        # GitHub Actions
        if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
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

        # GitLab CI
        elif [ "${GITLAB_CI:-false}" = "true" ]; then
            if [ -n "${CI_PROJECT_PATH:-}" ]; then
                echo "Repository: $CI_PROJECT_PATH"
            fi
            if [ -n "${CI_COMMIT_REF_NAME:-}" ]; then
                echo "Ref: $CI_COMMIT_REF_NAME"
            fi
            if [ -n "${CI_COMMIT_SHA:-}" ]; then
                echo "Commit: $CI_COMMIT_SHA"
            fi
            if [ -n "${GITLAB_USER_LOGIN:-}" ]; then
                echo "Actor: $GITLAB_USER_LOGIN"
            fi

        # Jenkins
        elif [ -n "${JENKINS_URL:-}" ]; then
            if [ -n "${JOB_NAME:-}" ]; then
                echo "Job: $JOB_NAME"
            fi
            if [ -n "${BUILD_NUMBER:-}" ]; then
                echo "Build: $BUILD_NUMBER"
            fi
            if [ -n "${GIT_COMMIT:-}" ]; then
                echo "Commit: $GIT_COMMIT"
            fi

        # Buildkite
        elif [ "${BUILDKITE:-false}" = "true" ]; then
            if [ -n "${BUILDKITE_PROJECT_SLUG:-}" ]; then
                echo "Repository: $BUILDKITE_PROJECT_SLUG"
            fi
            if [ -n "${BUILDKITE_BRANCH:-}" ]; then
                echo "Ref: $BUILDKITE_BRANCH"
            fi
            if [ -n "${BUILDKITE_COMMIT:-}" ]; then
                echo "Commit: $BUILDKITE_COMMIT"
            fi
            if [ -n "${BUILDKITE_BUILD_CREATOR:-}" ]; then
                echo "Actor: $BUILDKITE_BUILD_CREATOR"
            fi

        # CircleCI
        elif [ "${CIRCLECI:-false}" = "true" ]; then
            if [ -n "${CIRCLE_PROJECT_REPONAME:-}" ] && [ -n "${CIRCLE_PROJECT_USERNAME:-}" ]; then
                echo "Repository: $CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME"
            fi
            if [ -n "${CIRCLE_BRANCH:-}" ]; then
                echo "Ref: $CIRCLE_BRANCH"
            fi
            if [ -n "${CIRCLE_SHA1:-}" ]; then
                echo "Commit: $CIRCLE_SHA1"
            fi
            if [ -n "${CIRCLE_USERNAME:-}" ]; then
                echo "Actor: $CIRCLE_USERNAME"
            fi

        # Travis CI
        elif [ "${TRAVIS:-false}" = "true" ]; then
            if [ -n "${TRAVIS_REPO_SLUG:-}" ]; then
                echo "Repository: $TRAVIS_REPO_SLUG"
            fi
            if [ -n "${TRAVIS_BRANCH:-}" ]; then
                echo "Ref: $TRAVIS_BRANCH"
            fi
            if [ -n "${TRAVIS_COMMIT:-}" ]; then
                echo "Commit: $TRAVIS_COMMIT"
            fi
            if [ -n "${TRAVIS_COMMIT_AUTHOR:-}" ]; then
                echo "Actor: $TRAVIS_COMMIT_AUTHOR"
            fi
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
