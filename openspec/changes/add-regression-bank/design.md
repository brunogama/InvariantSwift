# Design Notes

- Storage location:
  - Default: `.invariant/regressions/<property-id>.json` under package/test working directory
  - Allow overriding base directory.

- Stored record:
  - propertyId
  - timestamp
  - replayToken (text)
  - minimalCounterexample (string rendering)
  - config hash/version

- Execution order:
  - stable: oldest-first or newest-first (choose and document)
