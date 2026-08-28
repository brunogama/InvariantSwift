# Project Context

---

## Characterization testing

Characterization testing records the current behavior of an existing system under test as checked-in, replayable fixtures. A characterization fixture contains explicit input cases and the observed result for each case. Verification treats the recorded behavior as the expected baseline and reports all observed differences.

A characterization case has a stable human-named identifier, a Codable input, and a Codable observation. Successful return values are observations; throwing operations use a stable error envelope selected by the test. Canonical JSON is the default comparison representation, with optional user-supplied observation and error-projection closures for normalization.

Recording is an explicit operation that rewrites fixtures. Ordinary verification never rewrites them.

A characterization report is the ordered aggregate of all case differences from one run.
