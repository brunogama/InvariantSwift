# Design Notes

- Prefer explicit diffs (arrays/dicts) over generic reflection first.
- Reflection for structs:
  - stable field ordering via `Mirror.children` order, with fallback to alphabetical labels.
- Keep ANSI optional and disabled by default; provide a flag to enable colors in terminals.
