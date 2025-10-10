#!/bin/bash
set -euo pipefail

# Simple logging functions
log_info() {
    echo "INFO: $*"
}

log_error() {
    echo "ERROR: $*" >&2
}

log_warning() {
    echo "WARNING: $*" >&2
}

log_success() {
    echo "SUCCESS: $*"
}

IMAGE="ats-pdf-generator:alpine"
ITERATIONS=3
OUTPUT_DIR="./benchmark-results"

show_usage() {
    cat <<'USAGE_EOF'
SYNOPSIS
    benchmark-security-tools.sh [OPTIONS]

DESCRIPTION
    Benchmark container security scanners using a specified image. Measures
    execution time across multiple iterations and records results to disk.

OPTIONS
    -h, --help              Show this help message and exit
    --image NAME            Container image to scan (default: ats-pdf-generator:alpine)
    --iterations N          Number of iterations per tool (default: 3)
    --output DIR            Directory to store benchmark results (default: ./benchmark-results)

EXAMPLES
    ./scripts/benchmark-security-tools.sh
    ./scripts/benchmark-security-tools.sh --image my-image:latest --iterations 5

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

# Parse command line arguments
SHOW_HELP=false
ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    show_usage
    exit 0
fi

# Set remaining arguments
set -- "${ARGS[@]}"

while [ $# -gt 0 ]; do
    case "$1" in
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
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
            log_error "Unexpected argument: $1"
            show_usage
            exit 2
            ;;
    esac

done

# Input validation
log_info "Validating input parameters..."

# Validate ITERATIONS
if [ -z "${ITERATIONS:-}" ]; then
    log_error "ITERATIONS is not set"
    exit 1
fi

if ! [[ "$ITERATIONS" =~ ^[1-9][0-9]*$ ]]; then
    log_error "ITERATIONS must be a positive integer (non-zero, digits only), got: '$ITERATIONS'"
    exit 1
fi

# Validate IMAGE
if [ -z "${IMAGE:-}" ]; then
    log_error "IMAGE is not set"
    exit 1
fi

# Validate OUTPUT_DIR
if [ -z "${OUTPUT_DIR:-}" ]; then
    log_error "OUTPUT_DIR is not set"
    exit 1
fi

# Normalize OUTPUT_DIR path (handle both relative and absolute paths)
if [[ "$OUTPUT_DIR" = /* ]]; then
    # Absolute path - use as is
    OUTPUT_DIR="$OUTPUT_DIR"
else
    # Relative path - make it absolute from current directory
    OUTPUT_DIR="$(pwd)/$OUTPUT_DIR"
fi

# Check if OUTPUT_DIR exists or can be created
if [ -d "$OUTPUT_DIR" ]; then
    # Directory exists, check if it's writable
    if [ ! -w "$OUTPUT_DIR" ]; then
        log_error "OUTPUT_DIR exists but is not writable: '$OUTPUT_DIR'"
        exit 1
    fi
else
    # Directory doesn't exist, check if parent is writable
    parent_dir=$(dirname "$OUTPUT_DIR")

    if [ ! -d "$parent_dir" ]; then
        log_error "Parent directory does not exist: '$parent_dir'"
        exit 1
    fi

    if [ ! -w "$parent_dir" ]; then
        log_error "Parent directory is not writable: '$parent_dir'"
        exit 1
    fi

    # Try to create the directory
    if ! mkdir -p "$OUTPUT_DIR" 2>/dev/null; then
        log_error "Failed to create OUTPUT_DIR: '$OUTPUT_DIR'"
        exit 1
    fi
fi

log_success "Input validation passed"

if [ $# -gt 0 ]; then
    log_error "Unexpected positional arguments: $*"
    exit 2
fi

if ! command -v bc >/dev/null 2>&1; then
    log_error "bc (calculator) not found. Install bc to run benchmarks"
    exit 1
fi

log_info "🔍 Security Tools Performance Benchmark"
log_info "Image: $IMAGE"
log_info "Iterations: $ITERATIONS"
log_info "Output Directory: $OUTPUT_DIR"

run_benchmark() {
    local tool_name="$1"
    shift  # Remove tool_name from arguments
    local output_file="$OUTPUT_DIR/${tool_name}-benchmark.txt"

    log_info "Testing $tool_name..."

    if ! command -v "$tool_name" >/dev/null 2>&1; then
        log_warning "$tool_name not found. Skipping"
        return 1
    fi

    # Build command array with tool name and all remaining arguments
    local command=("$tool_name" "$@")

    {
        echo "Tool: $tool_name"
        echo "Image: $IMAGE"
        echo "Iterations: $ITERATIONS"
        echo "Date: $(date)"
        echo ""
    } > "$output_file"

    local total_time=0
    local min_time=999999
    local max_time=0

    for ((i=1; i<=ITERATIONS; i++)); do
        log_info "  Iteration $i/$ITERATIONS..."

        local start_time end_time duration
        start_time=$(date +%s.%N)
        if ! "${command[@]}" >> "$output_file" 2>&1; then
            log_error "$tool_name command failed"
            return 1
        fi
        end_time=$(date +%s.%N)

        duration=$(echo "$end_time - $start_time" | bc -l)
        total_time=$(echo "$total_time + $duration" | bc -l)

        if (( $(echo "$duration < $min_time" | bc -l) )); then
            min_time=$duration
        fi

        if (( $(echo "$duration > $max_time" | bc -l) )); then
            max_time=$duration
        fi

        log_info "    Duration: ${duration}s"
    done

    local avg_time
    avg_time=$(echo "scale=3; $total_time / $ITERATIONS" | bc)

    {
        echo ""
        echo "=== BENCHMARK RESULTS ==="
        echo "Average Time: ${avg_time}s"
        echo "Min Time: ${min_time}s"
        echo "Max Time: ${max_time}s"
        echo "Total Time: ${total_time}s"
    } >> "$output_file"

    log_success "$tool_name benchmark complete"
    log_info "  Average: ${avg_time}s"
    log_info "  Min: ${min_time}s"
    log_info "  Max: ${max_time}s"
}

run_benchmark "trivy" trivy image --format table --quiet "$IMAGE"
run_benchmark "grype" grype "$IMAGE" --quiet
if command -v docker >/dev/null 2>&1; then
    run_benchmark "docker-scout" docker scout cves "$IMAGE" --quiet
fi
if command -v snyk >/dev/null 2>&1; then
    run_benchmark "snyk" snyk container test "$IMAGE" --quiet
fi

log_info "📊 Generating summary report..."
SUMMARY_FILE="$OUTPUT_DIR/benchmark-summary.txt"
{
    echo "Security Tools Benchmark Summary"
    echo "================================"
    echo "Image: $IMAGE"
    echo "Date: $(date)"
    echo "Iterations: $ITERATIONS"
    echo ""
} > "$SUMMARY_FILE"

{
    for file in "$OUTPUT_DIR"/*-benchmark.txt; do
        if [[ -f "$file" ]]; then
            tool_name=$(basename "$file" -benchmark.txt)
            echo "=== $tool_name ==="
            grep -A 4 "BENCHMARK RESULTS" "$file"
            echo ""
        fi
    done
} >> "$SUMMARY_FILE"

log_success "Benchmark complete"
log_info "Results saved to: $OUTPUT_DIR"
log_info "Summary report: $SUMMARY_FILE"
log_info "Next steps: review benchmarks, compare tools, document findings"
