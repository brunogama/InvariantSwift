# ONBOARDING

Please perform a **comprehensive onboarding analysis** for a new developer joining this project.

Follow the steps below and extract all relevant details for each section.

## Context

- Codebase structure git accessible: !`git ls-files`
- Codebase structure all: !`eza . --tree`

______________________________________________________________________

## 1. Project Overview

- Project name, purpose, and main functionality
- Tech stack (languages, frameworks, databases, tools)
- Architecture pattern (e.g., MVC, layered, microservices, CQRS, event-driven)
- Key dependencies and their purposes
- Distinguish between runtime dependencies, devDependencies, and build tools
- Note version constraints or compatibility issues

______________________________________________________________________

## 2. Repository Structure

- List all top-level directories with their purposes
- Identify sub-packages, submodules, or monorepo setups
- Clarify where business logic, UI, configs, assets, and tests are located
- Highlight any **non-standard** or unique organizational patterns
- Document presence of scripts, tooling, infra, or deployment subfolders

______________________________________________________________________

## 3. Getting Started

Step-by-step setup instructions:

- Prerequisites (software, SDKs, versions, package managers)
- Environment setup commands
- Installing dependencies
- Configurations required (local `.env`, secrets, keys)
- Running the project locally (dev server, simulator, CLI)
- Running tests
- Building for production
- Debugging common setup issues

______________________________________________________________________

## 4. Key Components

Identify and explain important modules:

- Entry points (e.g., `main.js`, `index.py`, `App.swift`)
- Core business logic
- Database models and schemas
- API endpoints and route definitions
- Configuration management
- Authentication and authorization system
- External services integration points

______________________________________________________________________

## 5. Development Workflow

Document the **standard flow** for contribution:

- Git branch naming conventions
- Commit message format
- How to start a new feature or bugfix
- Testing requirements (unit, integration, E2E)
- Code style, linting, and formatting rules
- PR process (creation, reviewers, checks)
- CI/CD pipeline overview (build, tests, deployment stages)
- Release strategy (tags, semantic versioning, changelog)

______________________________________________________________________

## 6. Architecture Decisions

Capture critical architectural choices:

- Design patterns (e.g., dependency injection, repository pattern)
- State management approach
- Error handling strategy
- Logging and monitoring setup
- Security measures (auth, encryption, secret management)
- Performance optimizations (caching, batching, indexes)

______________________________________________________________________

## 7. Common Tasks

Provide **practical examples** for frequent operations:

- Adding a new API endpoint
- Creating a new database model
- Writing a new unit/integration test
- Debugging common runtime errors
- Updating dependencies and handling breaking changes
- Running migrations or schema updates

______________________________________________________________________

## 8. Potential Gotchas

List known issues that may block progress:

- Hidden or non-obvious configs
- Required environment variables
- External service dependencies (APIs, databases, queues)
- Known bugs or edge cases
- Performance bottlenecks
- Technical debt hotspots

______________________________________________________________________

## 9. Documentation and Resources

Locate all project-related references:

- README, CONTRIBUTING, or other markdown docs
- Internal/external wiki
- API documentation (Swagger, Postman, GraphQL playground)
- Database schemas and ER diagrams
- Deployment guides
- Style guides and coding standards

______________________________________________________________________

## 10. Next Steps

Create an **onboarding checklist** for the new developer:

1. Set up development environment
1. Run the project locally
1. Make a test change
1. Run the full test suite
1. Walk through the main user flow
1. Select a small area for first contribution

______________________________________________________________________

## Output Deliverables

Produce three artifacts:

1. `ONBOARDING.md` → Full comprehensive onboarding document
1. `QUICKSTART.md` → Minimal setup instructions only
1. Suggested improvements to `README.md` if missing critical info (do not edit directly)

______________________________________________________________________

## Guidelines

- Focus on **clarity, actionability, reproducibility**
- Assume the developer is **senior but new to this codebase**
- Ensure instructions are **step-driven** with explicit commands and file paths
- Mark all external requirements and non-standard steps
