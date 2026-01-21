# Design

## Key decisions
- Candidate ordering is deterministic and documented
- Dictionary shrinking uses sorted keys to avoid hash nondeterminism

## Open questions
- Do you want Set shrinking (requires deterministic ordering policy) now or later?
