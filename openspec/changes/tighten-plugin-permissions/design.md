# Design: Plugin permissions

## Policy
- Default: no network access.
- If a future feature needs networking (e.g., uploading coverage), it MUST be explicit, off by default, and documented.

## Implementation Notes
- SwiftPM plugin permissions are declared in `Package.swift`.
- Keep `writeToPackageDirectory` only if the plugin writes artifacts into the repo.

## Acceptance
- `swift build` still succeeds.
- Running plugin does not prompt for network permissions.
