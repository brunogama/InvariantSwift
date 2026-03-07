#!/bin/bash
set -e

if [ -f "Package.swift" ] && git diff --cached --name-only | grep -q "\.swift$"; then
  echo "🔍 Checking code coverage..."

  # Run tests with coverage, disable macro validation if needed
  if ! swift test --enable-code-coverage -Xswiftc -disable-macro-validation 2>/dev/null; then
    echo "⚠️ Macro validation disabled for coverage check"
    swift test --enable-code-coverage -Xswiftc -disable-macro-validation
  else
    swift test --enable-code-coverage
  fi

  # Generate coverage report and extract percentage
  if [ -f ".build/debug/codecov/default.profdata" ]; then
    # Find the test binary (adjust pattern if needed)
    TEST_BINARY=$(find .build/debug -name "*Tests" -type f | head -n1)
    if [ -n "$TEST_BINARY" ]; then
      COVERAGE_OUTPUT=$(xcrun llvm-cov report "$TEST_BINARY" -instr-profile .build/debug/codecov/default.profdata)
      COVERAGE_PERCENT=$(echo "$COVERAGE_OUTPUT" | tail -1 | awk '{print $NF}' | sed 's/%//')

      echo "📊 Current coverage: ${COVERAGE_PERCENT}%"

      # Check if coverage meets 99% requirement
      if [ "$(echo "$COVERAGE_PERCENT >= 99" | bc -l)" -eq 1 ]; then
        echo "✅ Coverage requirement met: ${COVERAGE_PERCENT}% >= 99%"
      else
        echo "❌ Coverage requirement not met: ${COVERAGE_PERCENT}% < 99%"
        echo "🎯 Please add tests to reach at least 99% coverage"
        exit 1
      fi
    else
      echo "⚠️ No test binary found, skipping coverage check"
    fi
  else
    echo "⚠️ No coverage data found, skipping coverage check"
  fi
else
  echo "ℹ️ No Swift package or Swift files changed, skipping coverage check"
fi
