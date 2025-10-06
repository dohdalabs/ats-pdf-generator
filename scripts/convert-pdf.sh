#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/logging.sh"
source "$SCRIPT_DIR/utils/common.sh"

init_logger

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

INPUT_DIR="$(dirname "$INPUT_FILE")"
INPUT_FILENAME="$(basename "$INPUT_FILE")"
OUTPUT_BASENAME="$(basename "$OUTPUT_FILE")"

log_info "Converting: $INPUT_FILE -> $OUTPUT_FILE"
if [ -n "$DOCUMENT_TYPE" ]; then
    log_info "Document type: $DOCUMENT_TYPE"
fi

DOCKER_CMD="docker run --rm -v \"$(pwd)/$INPUT_DIR:/app/input\" -w /app ats-pdf-generator:dev"
PYTHON_CMD="source .venv/bin/activate && python src/ats_pdf_generator/ats_converter.py input/$INPUT_FILENAME -o input/$OUTPUT_BASENAME"

if eval "$DOCKER_CMD bash -c \"$PYTHON_CMD\""; then
    log_success "Conversion completed successfully"
    log_info "Output file: $OUTPUT_FILE"
else
    log_error "Conversion failed"
    exit 1
fi
