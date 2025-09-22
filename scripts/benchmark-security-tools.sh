#!/bin/bash
# benchmark-security-tools.sh
# Security tools performance benchmarking script

set -euo pipefail

# Configuration
IMAGE="${1:-ats-pdf-generator:alpine}"
ITERATIONS="${2:-3}"
OUTPUT_DIR="${3:-./benchmark-results}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}🔍 Security Tools Performance Benchmark${NC}"
echo "======================================"
echo "Image: $IMAGE"
echo "Iterations: $ITERATIONS"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Function to run benchmark
run_benchmark() {
    local tool_name="$1"
    local command="$2"
    local output_file="$OUTPUT_DIR/${tool_name}-benchmark.txt"

    echo -e "${YELLOW}Testing $tool_name...${NC}"

    # Check if tool is available
    if ! command -v "$tool_name" &> /dev/null; then
        echo -e "${RED}❌ $tool_name not found. Skipping...${NC}"
        return 1
    fi

    # Run benchmark
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
        echo "  Iteration $i/$ITERATIONS..."

        # Measure time
        local start_time
        start_time=$(date +%s.%N)
        eval "$command" >> "$output_file" 2>&1
        local end_time
        end_time=$(date +%s.%N)

        local duration
        duration=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $duration" | bc)

        if (( $(echo "$duration < $min_time" | bc -l) )); then
            min_time=$duration
        fi

        if (( $(echo "$duration > $max_time" | bc -l) )); then
            max_time=$duration
        fi

        echo "    Duration: ${duration}s"
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

    echo -e "${GREEN}✅ $tool_name benchmark complete${NC}"
    echo "  Average: ${avg_time}s"
    echo "  Min: ${min_time}s"
    echo "  Max: ${max_time}s"
    echo ""
}

# Check if bc is available
if ! command -v bc &> /dev/null; then
    echo -e "${RED}❌ bc (calculator) not found. Please install bc to run benchmarks.${NC}"
    exit 1
fi

# Run benchmarks for each tool
echo -e "${BLUE}Starting benchmarks...${NC}"
echo ""

# Trivy benchmark
run_benchmark "trivy" "trivy image --format table --quiet $IMAGE"

# Grype benchmark
run_benchmark "grype" "grype $IMAGE --quiet"

# Docker Scout benchmark (if available)
if command -v docker &> /dev/null; then
    run_benchmark "docker-scout" "docker scout cves $IMAGE --quiet"
fi

# Snyk benchmark (if available)
if command -v snyk &> /dev/null; then
    run_benchmark "snyk" "snyk container test $IMAGE --quiet"
fi

# Generate summary report
echo -e "${BLUE}📊 Generating summary report...${NC}"
SUMMARY_FILE="$OUTPUT_DIR/benchmark-summary.txt"

{
    echo "Security Tools Benchmark Summary"
    echo "================================"
    echo "Image: $IMAGE"
    echo "Date: $(date)"
    echo "Iterations: $ITERATIONS"
    echo ""
} > "$SUMMARY_FILE"

# Extract results from individual files
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

echo -e "${GREEN}✅ Benchmark complete!${NC}"
echo "Results saved to: $OUTPUT_DIR"
echo "Summary report: $SUMMARY_FILE"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Review individual benchmark files in $OUTPUT_DIR"
echo "2. Check summary report: $SUMMARY_FILE"
echo "3. Compare results and select best performing tool"
echo "4. Create GitHub issue with findings"
