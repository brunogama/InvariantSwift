# Tasks

- [ ] Add RunnerConfig.parallelism (default 1)
- [ ] Implement deterministic seed splitting per worker + per iteration
- [ ] Aggregate results deterministically (by global iteration index, not completion order)
- [ ] Keep shrinking single-threaded for stability
- [ ] Add tests proving serial == parallel outcomes for same seed/config
