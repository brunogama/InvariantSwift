# Security Architecture

### 8.1 Authentication

Not applicable (framework library, not service)

### 8.2 Authorization

Not applicable (framework library, not service)

### 8.3 Data Protection

| Data Category | Classification | Protection |
|---------------|---------------|------------|
| Generated Test Data | Internal | No encryption needed (ephemeral) |
| Coverage Maps | Internal | Optional file export if enabled |
| Test Results | Internal | Memory-resident only |
| Source Code (via macros) | User-controlled | Macro system preserves user code integrity |

### 8.4 Threat Model

| Threat | Impact | Likelihood | Mitigation |
|--------|--------|------------|------------|
| Malicious Generator | High (test failure) | Low | No untrusted generators by design |
| Integer Overflow in Size | Medium (crash) | Low | Size bounded to 0-100 range |
| Infinite Shrinking Loop | Medium (hang) | Low | maxShrinks limit enforced |
| Actor Isolation Violation | High (race condition) | Low | Compiler enforces actor safety |
| Macro Injection Attack | High (code execution) | Very Low | SwiftSyntax validates syntax |

---
