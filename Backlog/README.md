# LLM Backlog for InvariantSwift Rebuild

This directory is intended to be consumed by LLM-based coding agents.

## Workflow
1. Pick the next story by `priority` and `dependencies`.
2. Implement only what the story specifies.
3. Update/ add tests and docs referenced by the story.
4. Ensure `swift test` passes for all targets.

## Conventions
- Treat **core semantics** as API contracts; do not change them without updating `Docs/RebuildPlan/*`.
- Do not add new “advanced” modules until Epics E001 and E002 are complete.
- Keep plugin permissions minimal.

## Story schema
Each story is a Markdown file with YAML frontmatter:
- `id`, `title`, `epic`, `priority`, `status`, `dependencies`
- `scope`, `acceptance_criteria`, `files_to_touch`, `tests_to_add`
