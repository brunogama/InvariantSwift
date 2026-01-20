# Plugins and Permissions

## Current issue
The `InvariantSwiftPlugin` requests network permission without implementing a networked feature.

## Policy
- Default: **no network permissions**.
- Any data upload must be:
  - explicit opt-in (`--upload`)
  - documented (what, where, why)
  - implemented in a separate command/target

## Additional hygiene
- Enforce no `.DS_Store` / `__MACOSX` in CI.
- Make generated output directories deterministic to prevent diff noise.
