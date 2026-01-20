#!/usr/bin/env python3
"""
Swift Test Crash Detector - Focused on Swift Runtime Errors
Detects fatalError, precondition, preconditionFailure, assert, etc.
"""

import argparse
import asyncio
import json
import os
import platform
import re
import subprocess
import sys
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class TestFramework(Enum):
    SWIFT_TESTING = "swift-testing"
    XCTEST = "xctest"
    AUTO = "auto"


class CrashType(Enum):
    FATAL_ERROR = "FATAL_ERROR"
    PRECONDITION_FAILURE = "PRECONDITION_FAILURE"
    ASSERTION_FAILURE = "ASSERTION_FAILURE"
    SIGTRAP = "SIGTRAP"
    SEGFAULT = "SEGFAULT"
    RUNTIME_ERROR = "RUNTIME_ERROR"
    UNKNOWN = "UNKNOWN"


@dataclass
class SwiftRuntimeCrash:
    crash_type: CrashType
    function_name: str  # fatalError, precondition, etc.
    message: str  # The error message
    file_location: Optional[str]  # File:line where the crash occurred
    method_context: Optional[str]  # Method/function context
    full_context: str  # Full context around the crash
    timestamp: str


@dataclass
class TestResult:
    success: bool
    exit_code: int
    duration: float
    crashes: List[SwiftRuntimeCrash]
    output: str
    framework: TestFramework


def safe_decode(data: bytes) -> str:
    """Safely decode bytes to string."""
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        return data.decode('utf-8', errors='replace')


class SwiftRuntimeCrashDetector:
    """Detects Swift runtime crashes (fatalError, precondition, etc.)"""

    # Patterns for Swift runtime error functions
    SWIFT_RUNTIME_PATTERNS = {
        CrashType.FATAL_ERROR: [
            # Direct fatal error calls
            r'fatal error:\s*(.+?)(?:\n|$)',
            r'Fatal error:\s*(.+?)(?:\n|$)',

            # Stack trace indicators
            r'Swift\._fatalErrorMessage',
            r'_swift_stdlib_reportFatalError',
            r'swift_fatalError',

            # Runtime crash with fatal error context
            r'Current stack trace:\s*.*?fatal.*?error',
        ],

        CrashType.PRECONDITION_FAILURE: [
            # Direct precondition failures
            r'precondition failed:\s*(.+?)(?:\n|$)',
            r'Precondition failed:\s*(.+?)(?:\n|$)',

            # Stack trace indicators
            r'Swift\._preconditionFailure',
            r'swift_preconditionFailure',

            # Precondition with message
            r'precondition\(\)\s*failed.*?:\s*(.+?)(?:\n|$)',
        ],

        CrashType.ASSERTION_FAILURE: [
            # Direct assertion failures
            r'assertion failed:\s*(.+?)(?:\n|$)',
            r'Assertion failed:\s*(.+?)(?:\n|$)',

            # Stack trace indicators
            r'Swift\._assertionFailure',
            r'swift_assertionFailure',

            # Assert with message
            r'assert\(\)\s*failed.*?:\s*(.+?)(?:\n|$)',
        ],

        CrashType.SIGTRAP: [
            # Actual SIGTRAP crashes (not LLDB setup)
            r'Process \d+ stopped.*?signal SIGTRAP',
            r'Thread \d+.*?stopped.*?signal SIGTRAP',
            r'received signal SIGTRAP',

            # Swift trap calls
            r'swift_trap\(\)',
            r'Trace/BPT trap:',
        ],

        CrashType.RUNTIME_ERROR: [
            # Other Swift runtime errors
            r'swift_abortRetainUnowned',
            r'swift_unexpectedError',
            r'swift_unreachable',
            r'Runtime error:',
        ]
    }

    # Location extraction patterns
    LOCATION_PATTERNS = [
        # Standard format: "MyFile.swift:42: fatal error: message"
        r'([A-Za-z_][A-Za-z0-9_]*\.swift):(\d+):\s*(?:fatal error|precondition failed|assertion failed)',

        # In method context: "MyClass.method() -> MyFile.swift:42"
        r'([A-Za-z_][A-Za-z0-9_.]+\([^)]*\))\s*.*?\s*([A-Za-z_][A-Za-z0-9_]*\.swift):(\d+)',

        # Stack frame: "  at MyFile.swift:42"
        r'at\s+([A-Za-z_][A-Za-z0-9_]*\.swift):(\d+)',

        # Direct reference: "MyFile.swift:42"
        r'([A-Za-z_][A-Za-z0-9_]*\.swift):(\d+)',

        # With method: "in MyClass.method() (MyFile.swift:42)"
        r'in\s+([A-Za-z_][A-Za-z0-9_.]+\([^)]*\))\s*\(([A-Za-z_][A-Za-z0-9_]*\.swift):(\d+)\)',
    ]

    def __init__(self, verbose: bool = False):
        self.verbose = verbose

    def detect_crashes(self, output: str, exit_code: int) -> List[SwiftRuntimeCrash]:
        """Main crash detection method."""
        crashes = []
        lines = output.split('\n')

        # Skip LLDB setup phase - look for actual test execution
        execution_start = self._find_test_execution_start(lines)
        if execution_start > 0:
            lines = lines[execution_start:]
            if self.verbose:
                print(f"Skipped {execution_start} LLDB setup lines")

        # Detect crashes in the actual test output
        i = 0
        while i < len(lines):
            line = lines[i]

            # Check if this line indicates a Swift runtime crash
            crash_type, function_name = self._detect_swift_runtime_error(line)

            if crash_type != CrashType.UNKNOWN:
                # Extract crash information with context
                crash = self._extract_crash_details(
                    lines, i, crash_type, function_name
                )

                if crash:
                    crashes.append(crash)
                    if self.verbose:
                        print(f"🚨 Detected {crash_type.value}: {function_name}")
                        if crash.file_location:
                            print(f"   📍 {crash.file_location}")
                        if crash.message:
                            print(f"   💬 {crash.message[:100]}...")

            i += 1

        return crashes

    def _find_test_execution_start(self, lines: List[str]) -> int:
        """Find where actual test execution starts (after LLDB setup)."""
        # Look for indicators that LLDB setup is done and tests are running
        test_start_indicators = [
            r'Test Suite.*started',
            r'Testing\.main\(\)',
            r'Running.*tests?',
            r'Test Case.*started',
            r'Build complete!',
            r'swift-testing version',
            r'xctest version',
        ]

        for i, line in enumerate(lines):
            # Skip obvious LLDB setup lines
            if self._is_lldb_setup_line(line):
                continue

            # Check for test execution indicators
            for pattern in test_start_indicators:
                if re.search(pattern, line, re.IGNORECASE):
                    return i

            # If we see actual program output (not LLDB), assume execution started
            if (line.strip() and
                not self._is_lldb_setup_line(line) and
                not line.startswith('(lldb)') and
                'breakpoint' not in line.lower() and
                'warning' not in line.lower()):
                return i

        return 0

    def _is_lldb_setup_line(self, line: str) -> bool:
        """Check if line is part of LLDB setup (should be ignored)."""
        setup_patterns = [
            r'^\(lldb\)',
            r'Current executable set to',
            r'Executing commands in',
            r'Breakpoint \d+:.*no locations',
            r'WARNING:.*Unable to resolve',
            r'command source',
            r'settings set',
            r'process handle',
            r'breakpoint set',
            r'stop-hook add',
            r'^\s*NAME\s+PASS\s+STOP',
            r'^\s*=+\s+=+\s+=+',
            r'^\s*SIG\w+\s+true\s+true\s+true',
        ]

        return any(re.search(pattern, line) for pattern in setup_patterns)

    def _detect_swift_runtime_error(self, line: str) -> Tuple[CrashType, str]:
        """Detect if line contains a Swift runtime error."""

        # Check each crash type pattern
        for crash_type, patterns in self.SWIFT_RUNTIME_PATTERNS.items():
            for pattern in patterns:
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    # Try to extract function name from the pattern
                    function_name = self._extract_function_name(line, crash_type)
                    return crash_type, function_name

        return CrashType.UNKNOWN, ""

    def _extract_function_name(self, line: str, crash_type: CrashType) -> str:
        """Extract the Swift function name that caused the crash."""

        # Direct function name patterns
        function_patterns = {
            CrashType.FATAL_ERROR: [r'fatal[Ee]rror', r'_fatalErrorMessage'],
            CrashType.PRECONDITION_FAILURE: [r'precondition', r'_preconditionFailure'],
            CrashType.ASSERTION_FAILURE: [r'assert', r'_assertionFailure'],
            CrashType.SIGTRAP: [r'swift_trap'],
            CrashType.RUNTIME_ERROR: [r'swift_\w+'],
        }

        if crash_type in function_patterns:
            for pattern in function_patterns[crash_type]:
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    return match.group(0)

        return crash_type.value.lower().replace('_', '')

    def _extract_crash_details(self, lines: List[str], crash_line_idx: int,
                             crash_type: CrashType, function_name: str) -> Optional[SwiftRuntimeCrash]:
        """Extract detailed crash information with context."""

        # Get context around the crash (5 lines before, 10 lines after)
        start_idx = max(0, crash_line_idx - 5)
        end_idx = min(len(lines), crash_line_idx + 10)
        context_lines = lines[start_idx:end_idx]

        crash_line = lines[crash_line_idx]

        # Extract error message
        message = self._extract_error_message(crash_line, context_lines, crash_type)

        # Extract file location
        file_location = self._extract_file_location(context_lines)

        # Extract method context
        method_context = self._extract_method_context(context_lines)

        # Build full context
        full_context = '\n'.join(context_lines).strip()

        return SwiftRuntimeCrash(
            crash_type=crash_type,
            function_name=function_name,
            message=message,
            file_location=file_location,
            method_context=method_context,
            full_context=full_context,
            timestamp=datetime.now().isoformat()
        )

    def _extract_error_message(self, crash_line: str, context_lines: List[str],
                             crash_type: CrashType) -> str:
        """Extract the error message from crash context."""

        # Message extraction patterns based on crash type
        message_patterns = {
            CrashType.FATAL_ERROR: [
                r'fatal error:\s*(.+)',
                r'Fatal error:\s*(.+)',
            ],
            CrashType.PRECONDITION_FAILURE: [
                r'precondition failed:\s*(.+)',
                r'Precondition failed:\s*(.+)',
            ],
            CrashType.ASSERTION_FAILURE: [
                r'assertion failed:\s*(.+)',
                r'Assertion failed:\s*(.+)',
            ]
        }

        # Try to extract message from crash line first
        if crash_type in message_patterns:
            for pattern in message_patterns[crash_type]:
                match = re.search(pattern, crash_line, re.IGNORECASE)
                if match:
                    return match.group(1).strip()

        # Try to extract from context
        for line in context_lines:
            if crash_type in message_patterns:
                for pattern in message_patterns[crash_type]:
                    match = re.search(pattern, line, re.IGNORECASE)
                    if match:
                        return match.group(1).strip()

        # Fallback to cleaned crash line
        return crash_line.strip()

    def _extract_file_location(self, context_lines: List[str]) -> Optional[str]:
        """Extract file:line location from context."""

        for line in context_lines:
            for pattern in self.LOCATION_PATTERNS:
                match = re.search(pattern, line)
                if match:
                    groups = match.groups()

                    # Find filename and line number in groups
                    filename = None
                    line_num = None
                    method = None

                    for group in groups:
                        if group and group.endswith('.swift'):
                            filename = group
                        elif group and group.isdigit():
                            line_num = group
                        elif group and '(' in group and ')' in group:
                            method = group

                    if filename and line_num:
                        # Clean filename (remove path)
                        if '/' in filename:
                            filename = filename.split('/')[-1]

                        if method:
                            return f"{method} ({filename}:{line_num})"
                        else:
                            return f"{filename}:{line_num}"

        return None

    def _extract_method_context(self, context_lines: List[str]) -> Optional[str]:
        """Extract method/function context from crash."""

        method_patterns = [
            r'in\s+([A-Za-z_][A-Za-z0-9_.]+\([^)]*\))',
            r'([A-Za-z_][A-Za-z0-9_.]+\([^)]*\))\s*\(',
            r'func\s+([A-Za-z_][A-Za-z0-9_]+)',
        ]

        for line in context_lines:
            for pattern in method_patterns:
                match = re.search(pattern, line)
                if match:
                    return match.group(1)

        return None


class TestRunner:
    """Simple test runner focused on crash detection."""

    def __init__(self, project_path: Path, verbose: bool = False):
        self.project_path = project_path
        self.verbose = verbose
        self.crash_detector = SwiftRuntimeCrashDetector(verbose=verbose)

    async def run_tests(self, test_filter: Optional[str] = None, timeout: int = 300) -> TestResult:
        """Run tests and detect Swift runtime crashes."""

        cmd = ["swift", "test", "--sanitize=address", "-c", "debug", "--verbose"]
        # ❯ swift test --sanitize=address -c debug --verbose
        if test_filter:
            cmd.extend(["--filter", test_filter])

        if self.verbose:
            print(f"Running: {' '.join(cmd)}")

        start_time = time.time()

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd, cwd=self.project_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            )

            stdout, _ = await asyncio.wait_for(
                process.communicate(), timeout=timeout
            )

            duration = time.time() - start_time
            output = safe_decode(stdout)

            if self.verbose:
                print(f"Test completed in {duration:.2f}s with exit code {process.returncode}")

            # Detect Swift runtime crashes
            crashes = self.crash_detector.detect_crashes(output, process.returncode)

            return TestResult(
                success=process.returncode == 0 and len(crashes) == 0,
                exit_code=process.returncode,
                duration=duration,
                crashes=crashes,
                output=output,
                framework=TestFramework.SWIFT_TESTING  # Default
            )

        except asyncio.TimeoutError:
            if process:
                process.kill()
            raise RuntimeError(f"Test execution timed out after {timeout}s")


def generate_report(result: TestResult, package_name: str) -> str:
    """Generate crash report."""

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    report = f"""
Swift Runtime Crash Report
==========================

Package: {package_name}
Timestamp: {timestamp}
Duration: {result.duration:.2f}s
Exit Code: {result.exit_code}
Success: {result.success}
Crashes Detected: {len(result.crashes)}

"""

    if result.crashes:
        report += "SWIFT RUNTIME CRASHES:\n"
        report += "=" * 50 + "\n\n"

        for i, crash in enumerate(result.crashes, 1):
            report += f"Crash #{i}: {crash.crash_type.value}\n"
            report += f"  Function: {crash.function_name}\n"
            report += f"  Message: {crash.message}\n"
            report += f"  Location: {crash.file_location or 'Unknown'}\n"
            if crash.method_context:
                report += f"  Method: {crash.method_context}\n"
            report += f"  Time: {crash.timestamp}\n"
            report += "\n  Context:\n"
            for line in crash.full_context.split('\n')[:10]:  # First 10 lines
                if line.strip():
                    report += f"    {line}\n"
            report += "\n" + "-" * 50 + "\n\n"
    else:
        report += "✅ No Swift runtime crashes detected.\n\n"

    report += "FULL OUTPUT:\n"
    report += "=" * 20 + "\n"
    report += result.output

    return report


async def main():
    parser = argparse.ArgumentParser(
        description="Swift Runtime Crash Detector"
    )
    parser.add_argument("package_name", help="Swift package name")
    parser.add_argument("--filter", "-f", help="Test filter")
    parser.add_argument("--timeout", "-t", type=int, default=300, help="Timeout in seconds")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--output", "-o", help="Output file for report")

    args = parser.parse_args()

    try:
        runner = TestRunner(Path.cwd(), verbose=args.verbose)

        if args.verbose:
            print(f"🔍 Testing {args.package_name} for Swift runtime crashes...")

        result = await runner.run_tests(test_filter=args.filter, timeout=args.timeout)

        # Generate report
        report = generate_report(result, args.package_name)

        if args.output:
            with open(args.output, 'w') as f:
                f.write(report)
            print(f"📄 Report saved to: {args.output}")
        else:
            print(report)

        # Summary
        status = "✅ PASSED" if result.success else "❌ FAILED"
        print(f"\n{status} - {len(result.crashes)} Swift runtime crashes detected")

        if result.crashes:
            print("\n🔥 CRASHES:")
            for i, crash in enumerate(result.crashes, 1):
                location_info = f" at {crash.file_location}" if crash.file_location else ""
                print(f"  {i}. {crash.function_name}(): {crash.message[:100]}...{location_info}")

    except Exception as e:
        print(f"❌ Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
