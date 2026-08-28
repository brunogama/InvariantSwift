# Ralph Loop Matt Issues CLI

Runs sequential GitHub implementation issues through Pi RPC, verifies each result, and applies the tracker transition only after a clean completion report.

## Requirements

- Bash
- Git
- GitHub CLI (`gh`), authenticated for the target repository
- `jq`
- Node.js 20 or newer
- Pi with RPC support

The required `implement`, `tdd`, and `code-review` skills are included under `skills-main/skills/engineering`.

## Run

Run from a clean checkout of the repository whose issues should be implemented:

```sh
START_AT_ISSUE=2 STOP_AFTER_ISSUE=5 /path/to/RalphLoopMattIssuesCLI/loop.sh
```

By default, the loop runs `npm test` after each ticket. Override it for the target repository when needed:

```sh
RALPH_VERIFY_COMMAND='make check' /path/to/RalphLoopMattIssuesCLI/loop.sh
```

## Development

```sh
npm test
prek validate-config
prek run --all-files
```
