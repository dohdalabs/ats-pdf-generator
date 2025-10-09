#!/bin/bash
set -euo pipefail

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

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

INPUT_FILE="$1"
OUTPUT_FILE="${INPUT_FILE%.md}.pdf"

if [ $# -ge 3 ] && [ "$2" = "-o" ]; then
    OUTPUT_FILE="$3"
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE" >&2
    exit 1
fi

INPUT_DIR=$(dirname "$INPUT_FILE")
INPUT_FILENAME=$(basename "$INPUT_FILE")
OUTPUT_BASENAME=$(basename "$OUTPUT_FILE")

echo "Converting: $INPUT_FILE -> $OUTPUT_FILE"

docker run --rm \
    -v "$(realpath "$INPUT_DIR"):/app/input" \
    -w /app \
    ats-pdf-generator:dev \
    bash -c "source .venv/bin/activate && python src/ats_pdf_generator/ats_converter.py input/$INPUT_FILENAME -o input/$OUTPUT_BASENAME"

echo "✅ PDF generated: $OUTPUT_FILE"
