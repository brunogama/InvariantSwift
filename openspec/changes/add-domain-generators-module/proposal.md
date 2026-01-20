# Change: add-domain-generators-module

    ## Why
    Users expect realistic generators (emails, names, addresses) without bloating core or forcing heavy deps.

    ## What Changes
    - Split domain generators into a separate target/product (`InvariantSwiftDomainGenerators`).
- Provide deterministic, dependency-light generators for common domains.
- Make Fakery-based generators optional behind a separate target to avoid forced dependency.

    ## Impact
    - Improves adoption and keeps build graph sane. Requires Package.swift re-organization.

    ## Non-Goals
    - N/A

    ## Risks
    - API fragmentation; must keep discoverability with clear docs and re-export strategy.
