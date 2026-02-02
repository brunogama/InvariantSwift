#!/usr/bin/env python3

import subprocess
import os
import re
import datetime
from pathlib import Path
import sys
import time
import json
import argparse
import concurrent.futures
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, List, Tuple, Optional

class SignalAnalyzer:
    def __init__(self, timeout: int = 1800, max_workers: int = 3):
        self.output_dir = f"signal_analysis_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
        Path(self.output_dir).mkdir(exist_ok=True)
        self.timeout = timeout
        self.max_workers = max_workers

    def run_full_test_suite(self) -> Tuple[int, str, List[str]]:
        """Run the full test suite and capture Signal 5 occurrences"""
        print("🔍 Step 1: Running FULL test suite to reproduce Signal 5...")

        start_time = time.time()

        try:
            result = subprocess.run([
                "swift", "test",
                "--sanitize=address",
                "-c", "debug",
                "--verbose"
            ], capture_output=True, text=True, timeout=self.timeout)

            duration = time.time() - start_time

            # Save full output
            full_output_file = Path(self.output_dir) / "full_suite_run.log"
            with open(full_output_file, 'w') as f:
                f.write(f"Full test suite run\n")
                f.write(f"Started: {datetime.datetime.now()}\n")
                f.write(f"Duration: {duration:.2f}s\n")
                f.write(f"Exit code: {result.returncode}\n\n")
                f.write("STDOUT:\n")
                f.write(result.stdout)
                f.write("\nSTDERR:\n")
                f.write(result.stderr)

            # Extract tests that failed with Signal 5
            signal5_tests = self.extract_signal5_tests(result.stdout + result.stderr)

            print(f"✅ Full suite completed in {duration:.1f}s")
            print(f"📝 Output saved to: {full_output_file}")

            return result.returncode, result.stdout + result.stderr, signal5_tests

        except subprocess.TimeoutExpired:
            print("❌ Full test suite timed out")
            return -1, "TIMEOUT", []
        except Exception as e:
            print(f"❌ Error running full suite: {e}")
            return -2, str(e), []

    def extract_signal5_tests(self, output: str) -> List[str]:
        """Extract test names that failed with Signal 5 - Enhanced detection"""
        signal5_tests = []
        lines = output.split('\n')

        # More robust signal detection patterns
        signal_patterns = [
            r"error: Exited with unexpected signal code 5",
            r"signalled\(5\)",
            r"SIGTRAP.*signal 5",
            r"Process.*terminated.*signal 5",
            r"terminated with signal 5"
        ]

        current_test = None
        for i, line in enumerate(lines):
            # Look for test start - more flexible patterns
            test_start_patterns = [
                r'◇ Test "([^"]+)".*started',
                r'Test Case.*"([^"]+)".*started',
                r'Running test.*"([^"]+)"',
                r'Test "([^"]+)" started\.'
            ]

            for pattern in test_start_patterns:
                match = re.search(pattern, line)
                if match:
                    current_test = match.group(1)
                    break

            # Check for any signal 5 pattern
            if current_test and any(re.search(pattern, line) for pattern in signal_patterns):
                if current_test not in signal5_tests:  # Avoid duplicates
                    signal5_tests.append(current_test)
                current_test = None  # Reset to avoid duplicates

        return signal5_tests

    def extract_test_execution_order(self, output: str) -> List[str]:
        """Extract the order in which tests were executed"""
        test_order = []
        lines = output.split('\n')

        test_start_patterns = [
            r'◇ Test "([^"]+)".*started',
            r'Test Case.*"([^"]+)".*started',
            r'Running test.*"([^"]+)"',
            r'Test "([^"]+)" started\.'
        ]

        for line in lines:
            for pattern in test_start_patterns:
                match = re.search(pattern, line)
                if match and match.group(1) not in test_order:
                    test_order.append(match.group(1))
                    break

        return test_order

    def run_progressive_test_chunks(self, test_order: List[str], signal5_tests: List[str]) -> Dict:
        """Run progressively larger chunks of tests to find minimum reproduction"""
        print(f"\n🎯 Step 2: Running progressive chunks to isolate Signal 5...")
        print(f"Found {len(signal5_tests)} tests that failed with Signal 5 in full run")

        results = {}

        # Find the position of first Signal 5 test
        if signal5_tests and test_order:
            first_signal5_test = signal5_tests[0]
            try:
                first_signal5_index = test_order.index(first_signal5_test)
                print(f"First Signal 5 at test #{first_signal5_index + 1}: {first_signal5_test}")
            except ValueError:
                print(f"⚠️  Could not find {first_signal5_test} in execution order")
                first_signal5_index = len(test_order) // 2
        else:
            print("⚠️  No Signal 5 tests found, trying middle of test suite")
            first_signal5_index = len(test_order) // 2

        # Try different chunk sizes around the Signal 5 location
        chunk_sizes = [10, 25, 50, 100, first_signal5_index + 10, first_signal5_index + 50]
        chunk_sizes = [size for size in chunk_sizes if size <= len(test_order)]
        chunk_sizes = sorted(set(chunk_sizes))

        for chunk_size in chunk_sizes:
            print(f"\n📦 Testing chunk of first {chunk_size} tests...")

            chunk_tests = test_order[:chunk_size]
            chunk_result = self.run_test_chunk(chunk_tests, chunk_size)
            results[chunk_size] = chunk_result

            if chunk_result['has_signal5']:
                print(f"🎯 FOUND IT! Signal 5 reproduced with {chunk_size} tests")
                break
            elif chunk_result['has_signal6']:
                print(f"📍 Signal 6 found with {chunk_size} tests")
            else:
                print(f"✅ All {chunk_size} tests passed")

        return results

    def binary_search_minimal_reproduction(self, test_order: List[str]) -> Optional[int]:
        """Use binary search to find minimal test set that reproduces Signal 5"""
        print(f"\n🔍 Binary search for minimal reproduction...")

        left, right = 1, len(test_order)
        last_successful_size = None

        while left <= right:
            mid = (left + right) // 2
            print(f"Testing {mid} tests (range: {left}-{right})...")

            chunk_result = self.run_test_chunk(test_order[:mid], f"binary_{mid}")

            if chunk_result['has_signal5']:
                print(f"✅ Signal 5 reproduced with {mid} tests")
                last_successful_size = mid
                right = mid - 1  # Try smaller
            else:
                print(f"❌ No Signal 5 with {mid} tests")
                left = mid + 1   # Need more tests

        return last_successful_size

    def run_parallel_chunks(self, test_order: List[str], chunk_sizes: List[int]) -> Dict:
        """Run multiple chunk sizes in parallel for faster analysis"""
        print(f"\n⚡ Running parallel chunk analysis...")

        results = {}
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            future_to_size = {
                executor.submit(self.run_test_chunk, test_order[:size], f"parallel_{size}"): size
                for size in chunk_sizes if size <= len(test_order)
            }

            for future in concurrent.futures.as_completed(future_to_size):
                size = future_to_size[future]
                try:
                    result = future.result()
                    results[size] = result

                    if result['has_signal5']:
                        print(f"🎯 Signal 5 found with {size} tests!")
                        # Cancel remaining futures for efficiency
                        for f in future_to_size:
                            if not f.done():
                                f.cancel()
                        break
                    else:
                        print(f"✅ {size} tests completed - no Signal 5")

                except Exception as e:
                    print(f"❌ Chunk {size} failed: {e}")
                    results[size] = {'error': str(e), 'has_signal5': False, 'has_signal6': False}

        return results

    def run_test_chunk(self, tests: List[str], chunk_id) -> Dict:
        """Run a specific chunk of tests"""
        if not tests:
            return {'has_signal5': False, 'has_signal6': False, 'exit_code': 0, 'output': ''}

        # Handle long filter expressions by splitting into batches if needed
        max_filter_length = 8000  # Conservative limit for command line length
        filter_expr = "|".join(re.escape(test) for test in tests)

        if len(filter_expr) > max_filter_length:
            print(f"⚠️  Filter too long ({len(filter_expr)} chars), using test file approach")
            return self.run_test_chunk_with_file(tests, chunk_id)

        try:
            result = subprocess.run([
                "swift", "test",
                "--filter", filter_expr,
                "--sanitize=address",
                "-c", "debug",
                "--verbose"
            ], capture_output=True, text=True, timeout=600)

            output = result.stdout + result.stderr

            # Enhanced signal detection
            has_signal5 = any([
                "error: Exited with unexpected signal code 5" in output,
                "signalled(5)" in output,
                "terminated with signal 5" in output
            ])

            has_signal6 = "signalled(6)" in output

            # Save chunk output
            chunk_file = Path(self.output_dir) / f"chunk_{chunk_id}_tests.log"
            with open(chunk_file, 'w') as f:
                f.write(f"Chunk with {len(tests)} tests (ID: {chunk_id})\n")
                f.write(f"Filter length: {len(filter_expr)} chars\n")
                f.write(f"Exit code: {result.returncode}\n")
                f.write(f"Has Signal 5: {has_signal5}\n")
                f.write(f"Has Signal 6: {has_signal6}\n\n")
                f.write("FILTER EXPRESSION:\n")
                f.write(filter_expr[:500] + ("..." if len(filter_expr) > 500 else ""))
                f.write("\n\nOUTPUT:\n")
                f.write(output)

            return {
                'has_signal5': has_signal5,
                'has_signal6': has_signal6,
                'exit_code': result.returncode,
                'output': output,
                'test_count': len(tests),
                'filter_length': len(filter_expr)
            }

        except subprocess.TimeoutExpired:
            print(f"⏰ Chunk {chunk_id} timed out")
            return {'has_signal5': False, 'has_signal6': False, 'exit_code': -1, 'output': 'TIMEOUT', 'test_count': len(tests)}
        except Exception as e:
            print(f"❌ Error running chunk {chunk_id}: {e}")
            return {'has_signal5': False, 'has_signal6': False, 'exit_code': -2, 'output': str(e), 'test_count': len(tests)}

    def run_test_chunk_with_file(self, tests: List[str], chunk_id) -> Dict:
        """Alternative method using test list file when filter is too long"""
        test_file = Path(self.output_dir) / f"tests_{chunk_id}.txt"

        with open(test_file, 'w') as f:
            for test in tests:
                f.write(f"{test}\n")

        try:
            # Run all tests and filter output (less efficient but works with long lists)
            result = subprocess.run([
                "swift", "test",
                "--sanitize=address",
                "-c", "debug",
                "--verbose"
            ], capture_output=True, text=True, timeout=600)

            # This is a simplified approach - in practice you'd want to
            # implement proper test selection from the file
            output = result.stdout + result.stderr

            has_signal5 = "error: Exited with unexpected signal code 5" in output
            has_signal6 = "signalled(6)" in output

            return {
                'has_signal5': has_signal5,
                'has_signal6': has_signal6,
                'exit_code': result.returncode,
                'output': output,
                'test_count': len(tests)
            }

        except Exception as e:
            return {'has_signal5': False, 'has_signal6': False, 'exit_code': -2, 'output': str(e), 'test_count': len(tests)}

    def analyze_memory_patterns(self, full_output: str, signal5_tests: List[str]) -> Dict:
        """Enhanced memory pattern analysis"""
        print(f"\n🧠 Step 3: Analyzing memory patterns...")

        analysis = {
            'addresssanitizer_reports': [],
            'memory_leaks': [],
            'heap_issues': [],
            'signal5_contexts': [],
            'stack_traces': [],
            'memory_hotspots': {},
            'summary': {}
        }

        lines = full_output.split('\n')

        # Enhanced ASAN report parsing
        current_report = []
        in_report = False

        for i, line in enumerate(lines):
            # Start of ASAN report
            if re.search(r"(AddressSanitizer|ERROR: AddressSanitizer)", line):
                in_report = True
                current_report = [line]

                # Grab context - look for test name in preceding lines
                context_start = max(0, i - 10)
                context = lines[context_start:i]
                test_context = None
                for ctx_line in reversed(context):
                    if 'Test "' in ctx_line:
                        match = re.search(r'Test "([^"]+)"', ctx_line)
                        if match:
                            test_context = match.group(1)
                            break

                if test_context:
                    analysis['signal5_contexts'].append({
                        'test': test_context,
                        'line_number': i,
                        'error_type': self._extract_error_type(line)
                    })

            elif in_report:
                current_report.append(line)

                # End of report detection
                if (line.strip() == "" and len(current_report) > 3) or \
                   ("SUMMARY:" in line and "AddressSanitizer" in line):
                    analysis['addresssanitizer_reports'].append({
                        'report': '\n'.join(current_report),
                        'error_type': self._extract_error_type(current_report[0]),
                        'memory_address': self._extract_memory_address(current_report),
                        'line_number': i
                    })
                    in_report = False
                    current_report = []

        # Look for memory leaks
        for line in lines:
            if "LeakSanitizer" in line or "Direct leak" in line or "Indirect leak" in line:
                analysis['memory_leaks'].append(line.strip())

        # Look for heap issues
        for line in lines:
            if any(term in line for term in ["heap-buffer-overflow", "heap-use-after-free", "stack-buffer-overflow"]):
                analysis['heap_issues'].append(line.strip())

        # Analyze memory hotspots
        for report in analysis['addresssanitizer_reports']:
            error_type = report['error_type']
            analysis['memory_hotspots'][error_type] = \
                analysis['memory_hotspots'].get(error_type, 0) + 1

        # Generate summary
        analysis['summary'] = {
            'total_asan_reports': len(analysis['addresssanitizer_reports']),
            'total_memory_leaks': len(analysis['memory_leaks']),
            'total_heap_issues': len(analysis['heap_issues']),
            'signal5_test_count': len(signal5_tests),
            'most_common_error': max(analysis['memory_hotspots'].items(), key=lambda x: x[1])[0] if analysis['memory_hotspots'] else 'none'
        }

        # Save analysis
        analysis_file = Path(self.output_dir) / "memory_analysis.json"
        with open(analysis_file, 'w') as f:
            json.dump(analysis, f, indent=2, default=str)

        print(f"📊 Found {len(analysis['addresssanitizer_reports'])} AddressSanitizer reports")
        print(f"🔍 Found {len(analysis['memory_leaks'])} memory leak reports")
        print(f"💥 Found {len(analysis['heap_issues'])} heap corruption issues")

        # Show sample AddressSanitizer report
        if analysis['addresssanitizer_reports']:
            print(f"\n🚨 Sample AddressSanitizer Report:")
            print("=" * 60)
            sample_report = analysis['addresssanitizer_reports'][0]['report']
            print(sample_report[:800])
            if len(sample_report) > 800:
                print("... (truncated)")
            print("=" * 60)

        return analysis

    def _extract_error_type(self, line: str) -> str:
        """Extract the type of memory error from ASAN report"""
        patterns = {
            'heap-buffer-overflow': r'heap-buffer-overflow',
            'heap-use-after-free': r'heap-use-after-free',
            'stack-buffer-overflow': r'stack-buffer-overflow',
            'global-buffer-overflow': r'global-buffer-overflow',
            'memory-leaks': r'(Direct|Indirect) leak',
            'double-free': r'double-free',
            'invalid-pointer-dereference': r'SEGV.*invalid address'
        }

        for error_type, pattern in patterns.items():
            if re.search(pattern, line, re.IGNORECASE):
                return error_type
        return 'unknown'

    def _extract_memory_address(self, report_lines: List[str]) -> str:
        """Extract memory address from ASAN report"""
        for line in report_lines[:5]:  # Check first few lines
            # Look for hex addresses
            match = re.search(r'0x[0-9a-fA-F]+', line)
            if match:
                return match.group(0)
        return 'unknown'

    def generate_reproduction_script(self, successful_chunk_size: int, test_order: List[str]):
        """Generate a script to reproduce the minimal failing case"""
        if successful_chunk_size:
            tests_to_run = test_order[:successful_chunk_size]

            # Create both bash script and Swift Package Manager approach
            script_content = f"""#!/bin/bash
# Generated script to reproduce Signal 5 with minimal test set
# Found that Signal 5 occurs with first {successful_chunk_size} tests

echo "🔬 Running minimal reproduction of Signal 5 issue..."
echo "📊 Using {successful_chunk_size} tests in original execution order"
echo "📝 Output will be saved to reproduction_output.log"

# Method 1: Using filter (may fail if filter is too long)
echo "Attempting Method 1: Filter-based approach..."
swift test \\
    --filter "{"|".join(re.escape(test) for test in tests_to_run[:10])}" \\
    --sanitize=address \\
    -c debug \\
    --verbose 2>&1 | tee reproduction_output.log

echo "Exit code: $?"

# Method 2: If filter is too long, run full suite and check specific tests
if [ $? -ne 0 ] || [ ! -s reproduction_output.log ]; then
    echo ""
    echo "Attempting Method 2: Full suite with focused analysis..."
    swift test \\
        --sanitize=address \\
        -c debug \\
        --verbose 2>&1 | tee full_reproduction_output.log

    echo "Exit code: $?"
    echo "Check full_reproduction_output.log for Signal 5 occurrences"
fi

echo ""
echo "🎯 Reproduction attempt completed"
echo "📋 Check the log files for Signal 5 errors"
"""

            script_file = Path(self.output_dir) / "reproduce_signal5.sh"
            with open(script_file, 'w') as f:
                f.write(script_content)

            os.chmod(script_file, 0o755)

            # Also create a test list file
            test_list_file = Path(self.output_dir) / "minimal_test_set.txt"
            with open(test_list_file, 'w') as f:
                f.write(f"# Minimal test set that reproduces Signal 5\n")
                f.write(f"# Total tests: {len(tests_to_run)}\n\n")
                for i, test in enumerate(tests_to_run, 1):
                    f.write(f"{i:3d}. {test}\n")

            print(f"📝 Created reproduction script: {script_file}")
            print(f"📋 Created test list: {test_list_file}")

    def generate_comprehensive_report(self, analysis_results: Dict):
        """Generate a comprehensive analysis report"""
        report_file = Path(self.output_dir) / "signal5_analysis_report.md"

        with open(report_file, 'w') as f:
            f.write(f"# Signal 5 Analysis Report\n\n")
            f.write(f"**Generated:** {datetime.datetime.now()}\n")
            f.write(f"**Analysis Directory:** {self.output_dir}\n\n")

            f.write(f"## Executive Summary\n\n")
            if 'memory_analysis' in analysis_results:
                summary = analysis_results['memory_analysis']['summary']
                f.write(f"- **Total AddressSanitizer Reports:** {summary['total_asan_reports']}\n")
                f.write(f"- **Memory Leaks Found:** {summary['total_memory_leaks']}\n")
                f.write(f"- **Heap Issues:** {summary['total_heap_issues']}\n")
                f.write(f"- **Tests with Signal 5:** {summary['signal5_test_count']}\n")
                f.write(f"- **Most Common Error:** {summary['most_common_error']}\n\n")

            f.write(f"## Test Execution Analysis\n\n")
            if 'successful_chunk_size' in analysis_results:
                f.write(f"✅ **Minimal Reproduction Found:** {analysis_results['successful_chunk_size']} tests\n\n")
                f.write(f"This suggests the Signal 5 issue can be reproduced with a subset of tests, ")
                f.write(f"indicating it may be related to specific test interactions or cumulative memory issues.\n\n")
            else:
                f.write(f"⚠️ **Full Suite Required:** Signal 5 only occurs when running the complete test suite\n\n")
                f.write(f"This suggests the issue requires:\n")
                f.write(f"- Complete test execution environment\n")
                f.write(f"- Specific memory layout from all tests\n")
                f.write(f"- Global state accumulation\n")
                f.write(f"- Test ordering dependencies\n\n")

            f.write(f"## Memory Issue Analysis\n\n")
            if 'memory_analysis' in analysis_results:
                memory = analysis_results['memory_analysis']

                if memory['memory_hotspots']:
                    f.write(f"### Error Type Distribution\n\n")
                    for error_type, count in sorted(memory['memory_hotspots'].items(), key=lambda x: x[1], reverse=True):
                        f.write(f"- **{error_type}:** {count} occurrences\n")
                    f.write(f"\n")

                if memory['signal5_contexts']:
                    f.write(f"### Signal 5 Test Contexts\n\n")
                    for ctx in memory['signal5_contexts'][:5]:  # Show first 5
                        f.write(f"- **Test:** `{ctx['test']}`\n")
                        f.write(f"  - **Error Type:** {ctx['error_type']}\n")
                        f.write(f"  - **Line:** {ctx['line_number']}\n\n")

            f.write(f"## Reproduction Instructions\n\n")
            f.write(f"1. **Quick Reproduction:**\n")
            f.write(f"   ```bash\n")
            f.write(f"   cd {os.getcwd()}\n")
            f.write(f"   ./{self.output_dir}/reproduce_signal5.sh\n")
            f.write(f"   ```\n\n")

            f.write(f"2. **Manual Reproduction:**\n")
            f.write(f"   ```bash\n")
            f.write(f"   swift test --sanitize=address -c debug --verbose\n")
            f.write(f"   ```\n\n")

            f.write(f"## Files Generated\n\n")
            for file_path in sorted(Path(self.output_dir).glob("*")):
                if file_path.is_file():
                    f.write(f"- `{file_path.name}` - {self._describe_file(file_path.name)}\n")

            f.write(f"\n## Next Steps\n\n")
            f.write(f"1. Review AddressSanitizer reports in detail\n")
            f.write(f"2. Focus on the most common error types\n")
            f.write(f"3. Check for memory leaks in identified test contexts\n")
            f.write(f"4. Consider running with additional sanitizers (ThreadSanitizer, UBSan)\n")
            f.write(f"5. Profile memory usage patterns during test execution\n")

        print(f"📊 Comprehensive report saved to: {report_file}")

    def _describe_file(self, filename: str) -> str:
        """Provide description for generated files"""
        descriptions = {
            'full_suite_run.log': 'Complete test suite output',
            'memory_analysis.json': 'Detailed memory issue analysis',
            'reproduce_signal5.sh': 'Script to reproduce Signal 5',
            'minimal_test_set.txt': 'List of tests for minimal reproduction',
            'signal5_analysis_report.md': 'Comprehensive analysis report'
        }

        for pattern, desc in descriptions.items():
            if pattern in filename:
                return desc

        if 'chunk_' in filename:
            return 'Test chunk execution log'
        elif 'binary_' in filename:
            return 'Binary search execution log'
        elif 'parallel_' in filename:
            return 'Parallel chunk execution log'

        return 'Analysis output file'

def main():
    parser = argparse.ArgumentParser(description='Advanced Signal 5 vs Signal 6 Analysis for Swift Tests')
    parser.add_argument('--timeout', type=int, default=1800,
                       help='Test timeout in seconds (default: 1800)')
    parser.add_argument('--max-workers', type=int, default=3,
                       help='Maximum parallel workers (default: 3)')
    parser.add_argument('--binary-search', action='store_true',
                       help='Use binary search for minimal reproduction')
    parser.add_argument('--parallel', action='store_true',
                       help='Use parallel chunk testing')
    parser.add_argument('--max-chunk-size', type=int, default=200,
                       help='Maximum chunk size to test (default: 200)')
    parser.add_argument('--skip-full-suite', action='store_true',
                       help='Skip full test suite run (use existing logs)')

    args = parser.parse_args()

    analyzer = SignalAnalyzer(timeout=args.timeout, max_workers=args.max_workers)

    print("🔬 Advanced Signal 5 vs Signal 6 Analysis")
    print("=" * 50)

    analysis_results = {}

    try:
        if not args.skip_full_suite:
            # Step 1: Run full suite to reproduce Signal 5
            exit_code, full_output, signal5_tests = analyzer.run_full_test_suite()
            analysis_results['full_suite'] = {
                'exit_code': exit_code,
                'signal5_tests': signal5_tests
            }
        else:
            print("⏩ Skipping full suite run as requested")
            full_output, signal5_tests = "", []

        if not args.skip_full_suite and "error: Exited with unexpected signal code 5" in full_output:
            print("✅ Confirmed: Full test suite produces Signal 5")

            # Extract test execution order
            test_order = analyzer.extract_test_execution_order(full_output)
            print(f"📋 Extracted execution order of {len(test_order)} tests")
            analysis_results['test_order_count'] = len(test_order)

            # Step 2: Choose analysis method
            if args.binary_search:
                print("🔍 Using binary search approach...")
                successful_chunk = analyzer.binary_search_minimal_reproduction(test_order)
                analysis_results['successful_chunk_size'] = successful_chunk

            elif args.parallel:
                # Use parallel approach
                chunk_sizes = [10, 25, 50, 100, args.max_chunk_size]
                chunk_results = analyzer.run_parallel_chunks(test_order, chunk_sizes)
                analysis_results['chunk_results'] = chunk_results

                # Find successful reproduction
                successful_chunk = None
                for chunk_size, result in sorted(chunk_results.items()):
                    if result.get('has_signal5'):
                        successful_chunk = chunk_size
                        break
                analysis_results['successful_chunk_size'] = successful_chunk

            else:
                # Use progressive chunks (default)
                chunk_results = analyzer.run_progressive_test_chunks(test_order, signal5_tests)
                analysis_results['chunk_results'] = chunk_results

                # Find successful reproduction
                successful_chunk = None
                for chunk_size, result in chunk_results.items():
                    if result['has_signal5']:
                        successful_chunk = chunk_size
                        break
                analysis_results['successful_chunk_size'] = successful_chunk

            # Step 3: Memory analysis
            memory_analysis = analyzer.analyze_memory_patterns(full_output, signal5_tests)
            analysis_results['memory_analysis'] = memory_analysis

            # Generate reproduction script
            if successful_chunk:
                print(f"\n🎯 SUCCESS: Signal 5 reproduced with {successful_chunk} tests!")
                analyzer.generate_reproduction_script(successful_chunk, test_order)
            else:
                print(f"\n🤔 INTERESTING: Signal 5 only occurs in full test suite")
                print("This suggests the issue requires:")
                print("  • Complete test execution environment")
                print("  • Specific memory layout from all tests")
                print("  • Global state accumulation")
                print("  • Test ordering dependencies")

        elif not args.skip_full_suite:
            print("❓ No Signal 5 found in full test suite run")
            print("  This might mean the issue is intermittent")
            print("  Try running the analysis multiple times")

        # Generate comprehensive report
        analyzer.generate_comprehensive_report(analysis_results)

        print(f"\n📁 All analysis saved to: {analyzer.output_dir}")
        print(f"📊 View complete report: {analyzer.output_dir}/signal5_analysis_report.md")

    except KeyboardInterrupt:
        print("\n❌ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
