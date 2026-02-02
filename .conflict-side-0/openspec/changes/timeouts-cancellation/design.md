# Design

## Key decisions
- Timeout is per evaluation by default; optional globalTimeout bounds the entire run
- Cancellation returns a deterministic 'cancelled' outcome (not success/failure)

## Open questions
- Do you want wall-clock timeouts for sync predicates too?
