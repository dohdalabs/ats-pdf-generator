#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/logging.sh"
source "$SCRIPT_DIR/utils/common.sh"

init_logger --script-name "$(basename "$0")"

show_usage() {
    cat <<'USAGE_EOF'
SYNOPSIS
    convert-pdf.sh [OPTIONS] <input_file>

DESCRIPTION
    Convert a Markdown file into a PDF using the development Docker image. The
    script mounts the working directory into the container and writes the
    resulting PDF next to the source file.

OPTIONS
    -o, --output FILE        Name of the generated PDF (defaults to input basename)
    --type TYPE             Document type hint (cover-letter, profile)
    -h, --help              Show this help message and exit

EXAMPLES
    ./scripts/convert-pdf.sh examples/sample-cover-letter.md
    ./scripts/convert-pdf.sh examples/sample-profile.md --type profile
    ./scripts/convert-pdf.sh examples/sample-cover-letter.md -o build/cover.pdf

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

# Capture stderr from parse_common_flags to show specific error messages
if ! parse_common_flags "$@" 2>&1; then
    # The error message was already printed to stderr by parse_common_flags
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

if [ $# -eq 0 ]; then
    show_usage
    exit 2
fi

INPUT_FILE=""
OUTPUT_FILE=""
DOCUMENT_TYPE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --type)
            DOCUMENT_TYPE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 2
            ;;
        *)
            INPUT_FILE="$1"
            shift
            break
            ;;
    esac

done

if [ -z "$INPUT_FILE" ]; then
    log_error "Missing input file"
    show_usage
    exit 2
fi

if [ ! -f "$INPUT_FILE" ]; then
    log_error "Input file not found: $INPUT_FILE"
    exit 1
fi

if [ $# -gt 0 ]; then
    log_error "Unexpected positional arguments: $*"
    show_usage
    exit 2
fi

if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="${INPUT_FILE%.md}.pdf"
fi

# Validate and sanitize input paths
validate_path() {
    local path="$1"
    local name="$2"

    # Check for newlines and shell metacharacters
    if [[ "$path" =~ [[:space:]] ]]; then
        log_error "$name contains whitespace or newlines: $path"
        exit 1
    fi

    # Check for dangerous shell metacharacters
    if [[ "$path" =~ [\;\|\&\<\>\(\)\$\`\\\"\'] ]]; then
        log_error "$name contains dangerous shell metacharacters: $path"
        exit 1
    fi

    # Check for null bytes
    if [[ "$path" =~ $'\0' ]]; then
        log_error "$name contains null bytes: $path"
        exit 1
    fi
}

# Validate input and output paths
validate_path "$INPUT_FILE" "Input file"
validate_path "$OUTPUT_FILE" "Output file"

INPUT_DIR="$(dirname "$INPUT_FILE")"
INPUT_FILENAME="$(basename "$INPUT_FILE")"
OUTPUT_BASENAME="$(basename "$OUTPUT_FILE")"

# Validate filenames
validate_path "$INPUT_FILENAME" "Input filename"
validate_path "$OUTPUT_BASENAME" "Output basename"

# Compute absolute host path for Docker volume mount using realpath
if command -v realpath >/dev/null 2>&1; then
    ABSOLUTE_INPUT_DIR="$(realpath "$INPUT_DIR")"
else
    # Fallback for systems without realpath
    if [[ "$INPUT_DIR" = /* ]]; then
        ABSOLUTE_INPUT_DIR="$INPUT_DIR"
    else
        ABSOLUTE_INPUT_DIR="$(pwd)/$INPUT_DIR"
    fi
fi

# Validate the resolved absolute path
validate_path "$ABSOLUTE_INPUT_DIR" "Absolute input directory"

log_info "Converting: $INPUT_FILE -> $OUTPUT_FILE"
if [ -n "$DOCUMENT_TYPE" ]; then
    log_info "Document type: $DOCUMENT_TYPE"
fi

# Build Python command arguments safely
PYTHON_ARGS=("input/$INPUT_FILENAME" "-o" "input/$OUTPUT_BASENAME")
if [ -n "$DOCUMENT_TYPE" ]; then
    PYTHON_ARGS+=("--type" "$DOCUMENT_TYPE")
fi

# Execute Docker command directly without eval or shell interpretation
# Use exec form to pass arguments directly without shell interpretation
if docker run --rm \
    -v "$ABSOLUTE_INPUT_DIR:/app/input" \
    -w /app \
    ats-pdf-generator:dev \
    bash -c "source .venv/bin/activate && exec python src/ats_pdf_generator/ats_converter.py \"\$@\"" \
    -- \
    "${PYTHON_ARGS[@]}"; then
    log_success "Conversion completed successfully"
    log_info "Output file: $OUTPUT_FILE"
else
    log_error "Conversion failed"
    exit 1
fi
