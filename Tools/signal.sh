#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arrays to store results
failing_tests_signal5=()
failing_tests_signal6=()
failing_tests_other_signals=()
failing_tests_other=()
passing_tests=()
total_tests=0

# Function to check what type of failure occurred
check_failure_type() {
    local output_file="$1"
    local test_name="$2"

    if grep -q "error: Exited with unexpected signal code 5" "$output_file" || grep -q "signalled(5)" "$output_file"; then
        echo "signal5"
    elif grep -q "signalled(6)" "$output_file"; then
        echo "signal6"
    elif grep -q "signalled([0-9]*)" "$output_file"; then
        echo "other_signal"
    else
        echo "other"
    fi
}

# Create output directory
output_dir="test_outputs_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$output_dir"

echo -e "${YELLOW}Getting list of all tests...${NC}"

# Get list of all tests
test_list=$(swift test --list-tests 2>/dev/null | grep -E "^\s*.*\(\)" | sed 's/^[[:space:]]*//' | sed 's/()$//')

if [ -z "$test_list" ]; then
    echo -e "${RED}Could not retrieve test list. Make sure you're in a Swift package directory.${NC}"
    exit 1
fi

# Convert to array
IFS=$'\n' read -d '' -r -a tests <<< "$test_list"
total_tests=${#tests[@]}

echo -e "${YELLOW}Found $total_tests tests. Running each test individually...${NC}"
echo -e "${BLUE}Looking for both signal 5 (SIGTRAP) and signal 6 (SIGABRT) failures${NC}"
echo -e "${BLUE}Output files will be saved to: $output_dir/${NC}"
echo ""

# Create summary file
summary_file="$output_dir/detailed_summary.txt"
{
    echo "Test Execution Summary"
    echo "Generated on: $(date)"
    echo "Command: swift test --sanitize=address -c debug --verbose --filter [TEST_NAME]"
    echo "Total tests: $total_tests"
    echo ""
    echo "Signal Types:"
    echo "  Signal 5 (SIGTRAP) - Usually AddressSanitizer memory violations"
    echo "  Signal 6 (SIGABRT) - Usually assertion failures or abort() calls"
    echo ""
} > "$summary_file"

# Run each test individually
for i in "${!tests[@]}"; do
    test_name="${tests[i]}"
    current=$((i + 1))

    echo -e "${YELLOW}[$current/$total_tests] Running: $test_name${NC}"

    # Create safe filename for this test
    safe_test_name="${test_name//[^a-zA-Z0-9._-]/_}"
    test_output_file="$output_dir/${safe_test_name}.log"

    # Run the test and capture ALL output (stdout and stderr)
    {
        echo "=== Test: $test_name ==="
        echo "Command: swift test --filter \"$test_name\" --sanitize=address -c debug --verbose"
        echo "Started at: $(date)"
        echo ""
    } > "$test_output_file"

    # Run the actual test
    swift test --filter "$test_name" --sanitize=address -c debug --verbose >> "$test_output_file" 2>&1
    exit_code=$?

    {
        echo ""
        echo "Exit code: $exit_code"
        echo "Finished at: $(date)"
    } >> "$test_output_file"

    # Determine failure type
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}  ✓ PASSED${NC}"
        passing_tests+=("$test_name")
        echo "PASSED: $test_name" >> "$summary_file"
    else
        failure_type=$(check_failure_type "$test_output_file" "$test_name")
        case $failure_type in
            "signal5")
                echo -e "${RED}  ✗ FAILED with signal 5 (SIGTRAP)${NC}"
                failing_tests_signal5+=("$test_name")
                echo "SIGNAL 5 (SIGTRAP): $test_name" >> "$summary_file"
                ;;
            "signal6")
                echo -e "${RED}  ✗ FAILED with signal 6 (SIGABRT)${NC}"
                failing_tests_signal6+=("$test_name")
                echo "SIGNAL 6 (SIGABRT): $test_name" >> "$summary_file"
                ;;
            "other_signal")
                signal_num=$(grep -o "signalled([0-9]*)" "$test_output_file" | head -1)
                echo -e "${RED}  ✗ FAILED with $signal_num${NC}"
                failing_tests_other_signals+=("$test_name")
                echo "OTHER SIGNAL ($signal_num): $test_name" >> "$summary_file"
                ;;
            *)
                echo -e "${YELLOW}  ! FAILED with other error (exit code: $exit_code)${NC}"
                failing_tests_other+=("$test_name")
                echo "OTHER FAILURE (exit $exit_code): $test_name" >> "$summary_file"
                ;;
        esac

        # Show error preview
        echo -e "${BLUE}    Error preview:${NC}"
        if grep -q "AddressSanitizer" "$test_output_file"; then
            echo -e "${RED}    [AddressSanitizer detected]${NC}"
            grep -A 3 "AddressSanitizer" "$test_output_file" | head -6 | sed 's/^/      /'
        elif grep -q "signalled" "$test_output_file"; then
            grep -A 2 -B 2 "signalled" "$test_output_file" | head -5 | sed 's/^/      /'
        else
            grep -A 2 "error:" "$test_output_file" | head -5 | sed 's/^/      /'
        fi
        echo ""
    fi
done

# Update summary with final counts
{
    echo ""
    echo "=== FINAL SUMMARY ==="
    echo "Passed: ${#passing_tests[@]}"
    echo "Failed with signal 5 (SIGTRAP): ${#failing_tests_signal5[@]}"
    echo "Failed with signal 6 (SIGABRT): ${#failing_tests_signal6[@]}"
    echo "Failed with other signals: ${#failing_tests_other_signals[@]}"
    echo "Failed with other errors: ${#failing_tests_other[@]}"
    echo "Total: $total_tests"
} >> "$summary_file"

echo ""
echo -e "${YELLOW}==================== FINAL SUMMARY ====================${NC}"
echo -e "${GREEN}Passed: ${#passing_tests[@]}${NC}"
echo -e "${RED}Failed with signal 5 (SIGTRAP): ${#failing_tests_signal5[@]}${NC}"
echo -e "${RED}Failed with signal 6 (SIGABRT): ${#failing_tests_signal6[@]}${NC}"
echo -e "${RED}Failed with other signals: ${#failing_tests_other_signals[@]}${NC}"
echo -e "${YELLOW}Failed with other errors: ${#failing_tests_other[@]}${NC}"
echo -e "Total: $total_tests"
echo ""

# Create files for different failure types
create_failure_file() {
    local tests_array=("$@")
    local filename="$1"
    local description="$2"
    shift 2
    tests_array=("$@")

    if [ ${#tests_array[@]} -gt 0 ]; then
        {
            echo "$description"
            echo "Generated on: $(date)"
            echo "Count: ${#tests_array[@]}"
            echo ""
            for test in "${tests_array[@]}"; do
                echo "  • $test"
            done
        } > "$output_dir/$filename"
    fi
}

# Handle signal failures
# shellcheck disable=SC2034  # array populated but individual sub-arrays used for reporting
all_signal_failures=("${failing_tests_signal5[@]}" "${failing_tests_signal6[@]}" "${failing_tests_other_signals[@]}")

if [ ${#failing_tests_signal5[@]} -gt 0 ] || [ ${#failing_tests_signal6[@]} -gt 0 ] || [ ${#failing_tests_other_signals[@]} -gt 0 ]; then
    echo -e "${RED}Tests failing with signals:${NC}"

    if [ ${#failing_tests_signal5[@]} -gt 0 ]; then
        echo -e "${RED}  Signal 5 (SIGTRAP) - ${#failing_tests_signal5[@]} tests:${NC}"
        printf '    • %s\n' "${failing_tests_signal5[@]}"
    fi

    if [ ${#failing_tests_signal6[@]} -gt 0 ]; then
        echo -e "${RED}  Signal 6 (SIGABRT) - ${#failing_tests_signal6[@]} tests:${NC}"
        printf '    • %s\n' "${failing_tests_signal6[@]}"
    fi

    if [ ${#failing_tests_other_signals[@]} -gt 0 ]; then
        echo -e "${RED}  Other signals - ${#failing_tests_other_signals[@]} tests:${NC}"
        printf '    • %s\n' "${failing_tests_other_signals[@]}"
    fi

    # Create individual failure files
    if [ ${#failing_tests_signal5[@]} -gt 0 ]; then
        create_failure_file "signal5_failures.txt" "Tests failing with Signal 5 (SIGTRAP):" "${failing_tests_signal5[@]}"
    fi

    if [ ${#failing_tests_signal6[@]} -gt 0 ]; then
        create_failure_file "signal6_failures.txt" "Tests failing with Signal 6 (SIGABRT):" "${failing_tests_signal6[@]}"
    fi

    # Create combined signal failures file
    {
        echo "All tests failing with signals:"
        echo "Generated on: $(date)"
        echo ""
        if [ ${#failing_tests_signal5[@]} -gt 0 ]; then
            echo "Signal 5 (SIGTRAP) failures (${#failing_tests_signal5[@]}):"
            printf '  • %s\n' "${failing_tests_signal5[@]}"
            echo ""
        fi
        if [ ${#failing_tests_signal6[@]} -gt 0 ]; then
            echo "Signal 6 (SIGABRT) failures (${#failing_tests_signal6[@]}):"
            printf '  • %s\n' "${failing_tests_signal6[@]}"
            echo ""
        fi
        if [ ${#failing_tests_other_signals[@]} -gt 0 ]; then
            echo "Other signal failures (${#failing_tests_other_signals[@]}):"
            printf '  • %s\n' "${failing_tests_other_signals[@]}"
        fi
    } > "$output_dir/all_signal_failures.txt"

    echo ""
    echo -e "${BLUE}Files created:${NC}"
    echo -e "  • $output_dir/all_signal_failures.txt (all signal-related failures)"
    if [ ${#failing_tests_signal5[@]} -gt 0 ]; then
        echo -e "  • $output_dir/signal5_failures.txt (SIGTRAP failures)"
    fi
    if [ ${#failing_tests_signal6[@]} -gt 0 ]; then
        echo -e "  • $output_dir/signal6_failures.txt (SIGABRT failures)"
    fi
else
    echo -e "${GREEN}🎉 No tests failed with signals!${NC}"
fi

echo -e "  • $output_dir/detailed_summary.txt (complete summary)"
echo -e "  • $output_dir/[test_name].log (individual test outputs)"

# Show AddressSanitizer analysis if any
if find "$output_dir" -name "*.log" -exec grep -l "AddressSanitizer" {} \; | head -1 >/dev/null 2>&1; then
    echo ""
    echo -e "${YELLOW}AddressSanitizer Issues Detected:${NC}"
    echo -e "${BLUE}Sample AddressSanitizer output:${NC}"
    find "$output_dir" -name "*.log" -exec grep -l "AddressSanitizer" {} \; | head -1 | xargs grep -A 10 "AddressSanitizer" | head -15 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}All test outputs saved to: $output_dir/${NC}"
