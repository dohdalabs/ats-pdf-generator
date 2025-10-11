#!/bin/bash

# ATS PDF Generator Installer Script
#
# This script provides a quick and easy way to install or update the ATS PDF Generator utility.
# Usage:
#   curl -sSL https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/install.sh | bash
#   or download and run: ./install.sh
#
# Purpose:
#   - Installs the ATS PDF Generator tool for converting Markdown resumes to ATS-friendly PDFs.
#   - Supports updating to the latest version and displaying help.
#   - Designed for a smooth, no-sudo, one-liner installation experience.

set -euo pipefail

# Function to show usage
show_usage() {
    cat << 'USAGE_EOF'
SYNOPSIS
    install.sh [OPTIONS]

DESCRIPTION
    ATS PDF Generator Installer - Simple one-liner installer for the ATS PDF Generator utility.
    This script installs the ATS PDF Generator tool that converts Markdown files to
    ATS-compatible PDFs for job applications.

OPTIONS
    -h, --help              Show this help message and exit
    update, -u, --update    Update to the latest version

EXAMPLES
    # Install the ATS PDF Generator
    curl -sSL https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/install.sh | bash

    # Update to the latest version
    curl -sSL https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/install.sh | bash -s -- --update

    # Show help
    ./install.sh --help

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

# Check if help is requested (must be first)
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check system requirements
check_requirements() {
    print_info "Checking system requirements..."

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        print_info "Please install Docker from https://docs.docker.com/get-docker/"
        print_info "Supported platforms: macOS, Linux, Windows (WSL2)"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        print_info "Please start Docker and try again"
        exit 1
    fi

    # Check Docker architecture support
    local arch
    arch=$(uname -m)
    print_info "Detected architecture: $arch"
    print_info "Docker will automatically select the optimal image for your system"

    print_success "System requirements met"
}

# Function to determine installation directory
get_install_dir() {
    # Try common bin directories
    for dir in "$HOME/.local/bin" "/usr/local/bin" "$HOME/bin"; do
        if [ -d "$dir" ] && [ -w "$dir" ]; then
            echo "$dir"
            return 0
        fi
    done

    # Fallback to ~/.local/bin and create if needed
    local fallback="$HOME/.local/bin"
    mkdir -p "$fallback"
    echo "$fallback"
}

# Function to install the utility
install_utility() {
    local install_dir="$1"
    local script_name="ats-pdf"
    local script_path="$install_dir/$script_name"

    print_info "Installing to: $install_dir"

    # Create the wrapper script
    cat > "$script_path" << 'EOF'
#!/bin/bash

# ATS PDF Generator Wrapper
# Simple wrapper for the ATS PDF Generator Docker container

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Check if update is requested
if [[ "$1" == "update" || "$1" == "--update" || "$1" == "-u" ]]; then
    echo "Updating ATS PDF Generator to latest version..."

    # Re-run the installer with update flag
    curl -sSL https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/install.sh | bash -s -- --update
    exit 0
fi

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Error: No input file specified"
    show_usage
    exit 1
fi

# Run the Docker container
docker run --rm \
    -v "$(pwd):/app" \
    -v "$HOME/.ats-pdf:/app/.ats-pdf" \
    dohdalabs/ats-pdf-generator:v1.0.0 \
    "$@"
EOF

    # Make the script executable
    chmod +x "$script_path"

    print_success "ATS PDF Generator installed as '$script_name'"

    # Check if the directory is in PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_warning "Installation directory is not in your PATH"
        print_info "Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo "export PATH=\"$install_dir:\$PATH\""
        print_info "Then restart your terminal or run: source ~/.bashrc"
    else
        print_success "Ready to use! Try: ats-pdf --help"
    fi
}

# Function to check for updates
check_for_updates() {
    print_info "Checking for updates..."

    # Get current version from the installed script (if exists)
    local current_version="v1.0.0"  # Default to current version
    if command -v ats-pdf &> /dev/null; then
        # Try to extract version from script (this is a simple approach)
        current_version="v1.0.0"
    fi

    # Check if latest version is available
    if command -v docker &> /dev/null; then
        print_info "Current version: $current_version"
        print_info "Latest version available on Docker Hub"

        # Pull the latest image to update local cache
        if docker pull dohdalabs/ats-pdf-generator:latest &> /dev/null; then
            print_success "Updated to latest version"
            print_info "You can now use: ats-pdf <your-file.md>"
        else
            print_warning "Could not update to latest version"
            print_info "Check your internet connection and Docker setup"
        fi
    else
        print_warning "Docker not available - cannot check for updates"
    fi
}

# Function to create user customization directory
setup_customizations() {
    local custom_dir="$HOME/.ats-pdf"

    if [ ! -d "$custom_dir" ]; then
        mkdir -p "$custom_dir"
        print_info "Created customization directory: $custom_dir"
    fi

    # Create a sample custom CSS file
    local sample_css="$custom_dir/custom.css"
    if [ ! -f "$sample_css" ]; then
        cat > "$sample_css" << 'EOF'
/* Custom CSS for ATS PDF Generator */
/* This file will be used instead of the default CSS if it exists */

/* Example customizations: */
/*
body {
    font-family: 'Times New Roman', serif;
    font-size: 12pt;
    line-height: 1.4;
}

h1, h2, h3 {
    color: #2c3e50;
}

.cover-letter {
    max-width: 800px;
    margin: 0 auto;
}
*/
EOF
        print_info "Created sample custom CSS file: $sample_css"
        print_info "Edit this file to customize your PDF styling"
    fi
}

# Function to handle update command
handle_update() {
    echo "ATS PDF Generator Updater"
    echo "========================"
    echo

    check_requirements
    check_for_updates

    echo
    print_success "Update complete!"
}

# Main installation process
main() {
    # Check if update flag is provided
    if [[ "${1:-}" == "--update" || "${1:-}" == "-u" ]]; then
        handle_update
        exit 0
    fi

    echo "ATS PDF Generator Installer"
    echo "=========================="
    echo

    check_requirements

    local install_dir
    install_dir=$(get_install_dir)
    install_utility "$install_dir"
    setup_customizations

    echo
    print_success "Installation complete!"
    print_info "You can now use 'ats-pdf' from anywhere to convert your Markdown files"
    print_info "To update to the latest version later, run: curl -sSL https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/install.sh | bash -s -- --update"
}

# Run the installer
main "$@"
