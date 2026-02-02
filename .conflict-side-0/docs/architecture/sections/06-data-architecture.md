# Data Architecture

### 6.1 Data Models

```mermaid
erDiagram
    PROPERTY ||--o| GENERATOR : uses
    PROPERTY ||--o| CONFIG : configured_with
    PROPERTY ||--o| RESULT : produces

    GENERATOR ||--o| VALUE : generates
    VALUE ||--o| SHRUNK : shrinks_to

    CONFIG ||--o| SEED : optionally_uses

    RESULT {
        string status "success|failure|gaveUp"
        int iterations "completed iterations"
        object counterexample "failing value"
        object shrunk "minimized counterexample"
    }

    GENERATOR {
        string type_name "Type being generated"
        int size_parameter "0-100 generation size"
    }

    VALUE {
        string id "unique identifier"
        object data "actual generated value"
        int size "size of value"
    }
```

### 6.2 Data Storage

| Data Type | Storage | Retention | Backup |
|-----------|---------|-----------|--------|
| Generated Values | In-memory (ephemeral) | Single test run | Not applicable |
| Coverage Maps | In-memory with file export | Per test session | Optional JSON export |
| Test Results | Struct instances | In-memory | Optional CI reporter integration |
| Seeds (Reproducible) | User-provided via Config | As specified in config | Version control (hardcoded in tests) |
| Telemetry Events | Streaming to TelemetrySystem | As configured | File-based if enabled |

### 6.3 Data Consistency

- **Consistency Model**: Strong (deterministic with seeding)
- **Transaction Boundaries**: Single property test execution is atomic
- **Conflict Resolution**: N/A (single-threaded within property, parallel across properties via actors)

### 6.4 Data Migration Strategy

InvariantSwift is a framework (not a persistent storage system), so data migration focuses on:

1. **API Evolution**: Backwards-compatible property interface
2. **Generator Evolution**: New generators added without breaking existing ones
3. **Config Evolution**: New fields added with sensible defaults
4. **Result Format**: Versioned PropertyResult enums

---
