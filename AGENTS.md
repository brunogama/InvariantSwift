<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Agent Handoff

This repository uses OpenSpec for spec-driven development.

Read and follow:
- openspec/AGENTS.md

If you are asked to change behavior or implement features, use the OpenSpec workflow:
1) Create or update a change proposal in openspec/changes/<change-id>/
2) Refine spec deltas under openspec/changes/<change-id>/specs/
3) Implement tasks from openspec/changes/<change-id>/tasks.md
4) Archive the change into openspec/archive/ and update openspec/specs/
