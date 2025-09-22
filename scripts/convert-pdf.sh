#!/bin/bash

# ATS PDF Generator - Development Convenience Script
# Simple wrapper for converting documents using the dev Docker image

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

show_usage() {
    cat << EOF
ATS PDF Generator - Development Convenience Script

Usage: $0 <input_file> [options]

Options:
    -o, --output FILE        Output PDF file (default: input.pdf)
    --type TYPE             Document type (cover-letter, profile)
    -h, --help              Show this help message

Examples:
    $0 cover-letter.md                     # Convert cover letter
    $0 profile.md --type profile           # Convert professional profile
    $0 cover-letter.md -o "John_Doe_Cover_Letter.pdf"

This script uses the development Docker image with uv for fast conversions.
EOF
}

# Check if input file is provided
if [ $# -eq 0 ] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Parse arguments
input_file="$1"
shift

output_file=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        --type)
            # Document type parameter (currently unused)
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate input file
if [ ! -f "$input_file" ]; then
    print_error "Input file not found: $input_file"
    exit 1
fi

# Set default output file if not specified
if [ -z "$output_file" ]; then
    output_file="${input_file%.md}.pdf"
fi

# Get the directory of the input file
input_dir=$(dirname "$input_file")
input_filename=$(basename "$input_file")

print_info "Converting: $input_file -> $output_file"

# Build the Docker command
docker_cmd="docker run --rm -v \"$(pwd)/$input_dir:/app/input\" -w /app ats-pdf-generator:dev"
python_cmd="source .venv/bin/activate && python src/ats_pdf_generator/ats_converter.py input/$input_filename -o input/$(basename "$output_file")"

# Execute the conversion
if eval "$docker_cmd bash -c \"$python_cmd\""; then
    print_success "Conversion completed successfully!"
    print_info "Output file: $output_file"
else
    print_error "Conversion failed!"
    exit 1
fi
