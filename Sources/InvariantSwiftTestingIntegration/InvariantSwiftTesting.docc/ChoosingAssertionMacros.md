# Choosing Assertion Macros

@Metadata {
  @PageKind(article)
}

``Idempotent``, ``Deterministic``, and ``Pure`` all generate property-based tests, but they answer different questions.

## Start with the Property You Need

- Use ``Idempotent`` when the output should reach a fixed point after one pass.
- Use ``Deterministic`` when the same input must always return the same output.
- Use ``Pure`` when you want the function declaration to advertise a side-effect-free contract in addition to checking repeatability.

## Practical Heuristic

Ask these questions in order:

1. Should applying the function again leave the result unchanged?
2. If not, does the same input still need to produce the same output every time?
3. If yes, do you want the test declaration to explicitly document a purity expectation?

That maps cleanly to:

- question 1: ``Idempotent``
- question 2: ``Deterministic``
- question 3: ``Pure``

## Important Limitation

``Pure`` is stronger as documentation, not as runtime proof.

The macro can detect non-deterministic behavior such as random numbers or time-dependent output, but it cannot prove that the implementation avoids hidden mutation, logging, persistence, or network calls. Treat it as a contract marker plus a determinism test.
