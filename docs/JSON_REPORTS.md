# Using JSON Reports in CI

## Overview

InvariantSwift can emit structured JSON reports for each property test run, enabling easy integration with CI/CD pipelines, test result aggregators, and analytics dashboards.

## Quick Start

### Generating JSON Reports

#### From Swift Testing

```swift
import Testing
import InvariantSwift

@Test("Array reverse properties")
func testArrayReverse() async throws {
  let property = Property(
    generator: Gen.array(Gen.int),
    predicate: { array in
      array.reversed().reversed() == array
    }
  )
  
  let config = PropertyConfig(iterations: 1000)
  let runner = PropertyRunner()
  let startTime = Date()
  let result = await runner.runProperty(property, config: config)
  let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
  
  let report = RunReport.from(
    result,
    propertyName: "Array Reverse Involution",
    durationMs: durationMs,
    config: config
  )
  
  try report.writeJSON(to: "test-report.json", prettyPrinted: true)
  
  try await checkProperty(property, config: config)
}
```

#### From Command Line

```bash
# Generate JSON report during test run
functest run --iterations 1000 --report results.json --report-format json

# Generate report after test completion
functest report --output results --format json
```

## JSON Schema v1

### Success Report Example

```json
{
  "version": 1,
  "propertyName": "Array Reverse Involution",
  "outcome": "success",
  "statistics": {
    "totalIterations": 100,
    "successfulIterations": 100,
    "failedIterations": 0,
    "discardedCases": 0,
    "durationMs": 1234
  }
}
```

### Failure Report Example

```json
{
  "version": 1,
  "propertyName": "Sort Preserves Length",
  "outcome": "failed",
  "statistics": {
    "totalIterations": 42,
    "successfulIterations": 41,
    "failedIterations": 1,
    "discardedCases": 0,
    "durationMs": 523,
    "shrinkSteps": 5
  },
  "failure": {
    "failedAtIteration": 42,
    "reason": "Predicate failed",
    "originalCounterexample": "[3, 1, 4, 1, 5, 9, 2, 6]",
    "minimalCounterexample": "[1]",
    "replayToken": {
      "seed": 42,
      "iterations": 100,
      "size": 100,
      "maxDiscarded": 500
    },
    "shrinkTrace": [
      { "candidate": "[3, 1, 4]", "stillFails": true },
      { "candidate": "[1, 4]", "stillFails": true },
      { "candidate": "[1]", "stillFails": true }
    ]
  }
}
```

## CI Integration Examples

### GitHub Actions

```yaml
name: Property Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run property tests with JSON reports
        run: |
          swift test --filter PropertyTests | tee test-output.txt
          
      - name: Parse test results
        if: always()
        run: |
          # Parse JSON reports and upload to your analytics platform
          for report in test-reports/*.json; do
            echo "Processing $report"
            jq '.' "$report"
          done
          
      - name: Upload test artifacts
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-reports
          path: test-reports/*.json
```

### GitLab CI

```yaml
property-tests:
  script:
    - swift test --filter PropertyTests
    - functest report --format json --output coverage/report
  artifacts:
    reports:
      junit: coverage/report.json
    paths:
      - coverage/
```

### Jenkins

```groovy
pipeline {
  agent any
  
  stages {
    stage('Property Tests') {
      steps {
        sh 'swift test --filter PropertyTests'
        sh 'functest report --format json --output reports/property-tests'
      }
    }
  }
  
  post {
    always {
      archiveArtifacts artifacts: 'reports/*.json', fingerprint: true
      junit 'reports/property-tests.json'
    }
  }
}
```

## Parsing Reports

### Python

```python
import json

with open('test-report.json') as f:
    report = json.load(f)
    
if report['outcome'] == 'failed':
    failure = report['failure']
    print(f"Test failed at iteration {failure['failedAtIteration']}")
    print(f"Minimal counterexample: {failure['minimalCounterexample']}")
    print(f"Replay with seed: {failure['replayToken']['seed']}")
```

### JavaScript

```javascript
const fs = require('fs');

const report = JSON.parse(fs.readFileSync('test-report.json'));

if (report.outcome === 'failed') {
  console.log(`Failed: ${report.failure.reason}`);
  console.log(`Counterexample: ${report.failure.minimalCounterexample}`);
  console.log(`Replay token: ${report.failure.replayToken.seed}`);
}
```

### Shell (jq)

```bash
# Extract failure information
jq '.failure | select(.!= null) | {
  iteration: .failedAtIteration,
  reason: .reason,
  counterexample: .minimalCounterexample,
  seed: .replayToken.seed
}' test-report.json

# Get test statistics
jq '.statistics | {
  total: .totalIterations,
  passed: .successfulIterations,
  failed: .failedIterations,
  duration_seconds: (.durationMs / 1000)
}' test-report.json
```

## Schema Fields Reference

| Field | Type | Description |
|-------|------|-------------|
| `version` | Int | Schema version (currently 1) |
| `propertyName` | String? | Property identifier |
| `outcome` | Enum | `"success"`, `"failed"`, or `"gaveUp"` |
| `statistics` | Object | Execution metrics |
| `statistics.totalIterations` | Int | Total test iterations |
| `statistics.successfulIterations` | Int | Successful checks |
| `statistics.failedIterations` | Int | Failed checks |
| `statistics.discardedCases` | Int | Discarded due to assumptions |
| `statistics.durationMs` | Int | Execution time in milliseconds |
| `statistics.shrinkSteps` | Int? | Shrinking steps (if failed) |
| `failure` | Object? | Present only if outcome is `"failed"` or `"gaveUp"` |
| `failure.failedAtIteration` | Int | Iteration number of failure |
| `failure.reason` | String | Human-readable failure reason |
| `failure.originalCounterexample` | String | Initial failing input |
| `failure.minimalCounterexample` | String | Shrunk failing input |
| `failure.replayToken` | Object | Token for reproducing failure |
| `failure.shrinkTrace` | Array? | Step-by-step shrinking log |
| `classification` | Object? | Label distribution (if using ClassifyingProperty) |

## Best Practices

1. **Store reports as artifacts**: Always upload JSON reports in CI for debugging
2. **Track trends**: Aggregate reports over time to detect flaky tests
3. **Use replay tokens**: Include seed values in bug reports for reproducibility
4. **Monitor duration**: Track `durationMs` to detect performance regressions
5. **Version control**: The `version` field enables schema evolution - check it before parsing

## Troubleshooting

### Reports not generated

- Ensure you call `RunReport.from()` or `report.writeJSON()`
- Check file permissions on the output directory
- Verify the report path is correct

### Invalid JSON

- Use `prettyPrinted: false` for compact output if parsing fails
- Validate with `jq` or `python -m json.tool`

### Missing fields

- Optional fields (`failure`, `classification`) may be null
- Always check for presence before accessing

## Next Steps

- See `RunReport.swift` for full API documentation
- See `RunReportJSONSchemaTests.swift` for usage examples
- See [Proposals](../../proposals/) for schema evolution plans
