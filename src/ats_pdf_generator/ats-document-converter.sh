#!/bin/bash

# ATS Document Converter
# Convert markdown cover letters and profiles to ATS-optimized PDFs
# pre-commit: skip-help-validation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to show usage
show_usage() {
    cat << EOF
ATS Document Converter
Convert markdown cover letters and profiles to ATS-optimized PDFs

Usage: $0 [OPTIONS] <input_file>

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
    $0 cover-letter.md                     # Convert cover letter
    $0 profile.md --type profile           # Convert professional profile
    $0 cover-letter.md -o "John_Doe_Cover_Letter.pdf"

ATS Optimization Features:
    - Standard fonts (Arial, sans-serif) for maximum compatibility
    - High contrast text (black on white) for readability
    - Simple, clean layout that ATS systems can parse
    - Selectable text for proper content extraction
    - Optimized spacing and typography

Requirements:
    - Docker (automatically used if available)
    - Markdown file with proper document formatting
EOF
}

# Function to check if Docker is available
check_docker() {
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if local tools are available
check_local() {
    if command -v pandoc &> /dev/null && command -v weasyprint &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to get the appropriate CSS file
get_css_file() {
    local doc_type="$1"
    local input_dir="$2"

    # First, check for user custom CSS in .ats-pdf directory
    local custom_css="$HOME/.ats-pdf/custom.css"
    if [ -f "$custom_css" ]; then
        print_info "Using custom CSS: $custom_css"
        echo "$custom_css"
        return 0
    fi

    # Check for custom CSS in the same directory as input file
    local local_custom_css="$input_dir/.ats-pdf/custom.css"
    if [ -f "$local_custom_css" ]; then
        print_info "Using local custom CSS: $local_custom_css"
        echo "$local_custom_css"
        return 0
    fi

    # Fall back to default CSS
    local css_file="templates/ats-${doc_type}.css"

    # Check if the CSS file exists
    if [ ! -f "$css_file" ]; then
        print_error "CSS file not found: $css_file"
        print_info "Available CSS files:"
        ls -1 templates/ats-*.css 2>/dev/null || echo "No CSS files found"
        exit 1
    fi

    echo "$css_file"
}

# Function to convert resume using Docker
convert_with_docker() {
    local input_file="$1"
    local output_file="$2"
    local css_file="$3"
    local title="$4"
    local author="$5"
    local date="$6"

    local docker_cmd=("docker" "run" "--rm" "-v" "$input_dir:/app" "-w" "/app" "dohdalabs/ats-pdf-generator:latest")

    # Add input file (use basename since we're mounting the directory)
    docker_cmd+=("${input_basename}")

    # Add output file (use input filename with .pdf extension if not specified)
    if [ -n "$output_file" ]; then
        docker_cmd+=("-o" "${output_file}")
    else
        # Generate output filename from input filename
        local input_basename
        input_basename=$(basename "$input_file" .md)
        local default_output="${input_basename}.pdf"
        docker_cmd+=("-o" "${default_output}")
    fi

    # Add CSS file if specified
    if [ -n "$css_file" ]; then
        docker_cmd+=("--css" "${css_file}")
    fi

    # Add metadata if specified
    if [ -n "$title" ]; then
        docker_cmd+=("--title" "${title}")
    fi

    if [ -n "$author" ]; then
        docker_cmd+=("--author" "${author}")
    fi

    if [ -n "$date" ]; then
        docker_cmd+=("--date" "${date}")
    fi

    # Use weasyprint engine (best for resumes)
    docker_cmd+=("--pdf-engine" "weasyprint")

    print_info "Converting resume using Docker..."
    print_info "Command: ${docker_cmd[*]}"

    if "${docker_cmd[@]}"; then
        print_success "Resume converted successfully"
    else
        print_error "Conversion failed"
        exit 1
    fi
}

# Function to convert resume using local tools
convert_with_local() {
    local input_file="$1"
    local output_file="$2"
    local css_file="$3"
    local title="$4"
    local author="$5"
    local date="$6"

    local pandoc_cmd=("pandoc" "${input_file}")

    # Add output file if specified
    if [ -n "$output_file" ]; then
        pandoc_cmd+=("-o" "${output_file}")
    fi

    # Add CSS file if specified
    if [ -n "$css_file" ]; then
        pandoc_cmd+=("--css" "${css_file}")
    fi

    # Add metadata if specified
    if [ -n "$title" ]; then
        pandoc_cmd+=("-M" "title=${title}")
    fi

    if [ -n "$author" ]; then
        pandoc_cmd+=("-M" "author=${author}")
    fi

    if [ -n "$date" ]; then
        pandoc_cmd+=("-M" "date=${date}")
    fi

    # Use weasyprint engine
    pandoc_cmd+=("--pdf-engine" "weasyprint")

    print_info "Converting resume using local tools..."
    print_info "Command: ${pandoc_cmd[*]}"

    if "${pandoc_cmd[@]}"; then
        print_success "Resume converted successfully"
    else
        print_error "Conversion failed"
        exit 1
    fi
}

# Function to validate document format
validate_document() {
    local input_file="$1"
    local doc_type="$2"

    print_info "Validating document format..."

    if [ "$doc_type" = "cover-letter" ]; then
        # Check for cover letter structure
        if grep -qi "dear\|to whom\|hiring manager" "$input_file"; then
            print_success "Cover letter format detected"
        else
            print_warning "Consider adding a proper salutation (Dear, To Whom It May Concern, etc.)"
        fi
    elif [ "$doc_type" = "profile" ]; then
        # Check for profile structure
        if grep -qi "summary\|profile\|about\|overview" "$input_file"; then
            print_success "Professional profile format detected"
        else
            print_warning "Consider adding a clear profile summary or overview section"
        fi
    fi

    # Check document length
    local word_count
    word_count=$(wc -w < "$input_file")
    if [ "$doc_type" = "cover-letter" ] && [ "$word_count" -gt 400 ]; then
        print_warning "Cover letter is quite long ($word_count words). Consider keeping it under 400 words."
    fi
}

# Main script logic
main() {
    # Parse command line arguments
    local input_file=""
    local output_file=""
    local doc_type="cover-letter"
    local title=""
    local author=""
    local date=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            --type)
                doc_type="$2"
                shift 2
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            --author)
                author="$2"
                shift 2
                ;;
            --date)
                date="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                if [ -z "$input_file" ]; then
                    input_file="$1"
                else
                    print_error "Unknown option: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Check if input file is provided
    if [ -z "$input_file" ]; then
        print_error "Input file is required"
        show_usage
        exit 1
    fi

    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        print_error "Input file '$input_file' does not exist"
        exit 1
    fi

    # Get the directory of the input file for relative path handling
    local input_dir
    local input_basename
    input_dir=$(dirname "$(realpath "$input_file")")
    input_basename=$(basename "$input_file")

    print_info "Input file: $input_file"
    print_info "Input directory: $input_dir"

    # Validate document format
    validate_document "$input_file" "$doc_type"

    # Get the appropriate CSS file
    css_file=$(get_css_file "$doc_type" "$input_dir")
    print_info "Using CSS file: $css_file"

    # Use Docker if available, otherwise show error
    if check_docker; then
        print_info "Converting with Docker (ATS-optimized)"
        convert_with_docker "$input_file" "$output_file" "$css_file" "$title" "$author" "$date"
    else
        print_error "Docker is required for this tool"
        print_info "Please install Docker to use the ATS Document Converter"
        print_info "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # No cleanup needed - using permanent CSS files

    print_success "Document conversion completed!"
    print_info "Output file: ${output_file:-${input_file%.*}.pdf}"
}

# Run main function
main "$@"
