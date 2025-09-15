#!/bin/bash

# ATS PDF Generator Installer
# Simple one-liner installer for the ATS PDF Generator utility

set -e

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

# Function to show usage
show_usage() {
    cat << 'USAGE_EOF'
ATS PDF Generator
Convert your Markdown content to ATS-compatible PDFs

Usage: ats-pdf [OPTIONS] <input_file>

Options:
    -o, --output FILE        Output PDF file (default: input.pdf)
    --type TYPE             Document type (cover-letter, profile)
    --title TITLE           Document title
    --author AUTHOR         Document author
    --date DATE             Document date
    -h, --help              Show this help message

Document Types:
    cover-letter  - ATS-optimized cover letter (default)
    profile       - Professional profile/summary document

Examples:
    ats-pdf cover-letter.md                     # Convert cover letter
    ats-pdf profile.md --type profile           # Convert professional profile
    ats-pdf cover-letter.md -o "John_Doe_Cover_Letter.pdf"

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
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
    dohdalabs/ats-pdf-generator:latest \
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

# Main installation process
main() {
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
}

# Run the installer
main "$@"
