extension ProtocolLawCatalog {
  static let concurrencyEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "Sendable",
      tier: .two,
      laws: [
        law(
          "sendable.concurrent-read-equivalence",
          "Deterministic concurrent reads of an immutable snapshot produce equal results"
        ),
        law(
          "sendable.race-freedom",
          "A declared thread-safe workload remains race-free under randomized TSan schedules"
        ),
      ],
      capabilities: ["randomized concurrent schedules"],
      notes: "Sendable is a marker used to select concurrency suites, not a law by itself. "
        + "Mutable or nondeterministic values need a type-specific workload and oracle."
    ),
    entry(
      "Actor / GlobalActor",
      conformances: ["Actor", "GlobalActor"],
      tier: .one,
      laws: [
        law(
          "actor.linearizability",
          "Operations declared atomic are linearizable at their documented linearization points"
        ),
        law(
          "actor.reentrancy-invariants",
          "Declared externally observable invariants hold at documented suspension boundaries"
        ),
        law(
          "actor.reference-model",
          "An actor exposing counter or set semantics agrees with its declared reference model"
        ),
      ],
      capabilities: ["linearizability checker", "happens-before", "state-machine contracts"],
      notes: "Actor isolation does not make a whole reentrant method linearizable across await. "
        + "Generate histories with TaskGroup only for APIs that declare atomic behavior or a "
        + "reference model."
    ),
    entry(
      "DistributedActor",
      module: "Distributed",
      tier: .three,
      laws: [
        law(
          "distributed-actor.local-linearizability",
          "Declared atomic local operations are linearizable under the testing actor system"
        ),
        law(
          "distributed-actor.codable-roundtrip",
          "Value-preserving distributed arguments and returns survive Codable round-trips"
        ),
      ],
      capabilities: ["linearizability", "round-trip"],
      notes: "DistributedActor conformance alone supplies neither operation-level atomicity nor "
        + "value-preserving Codable semantics. Both contracts are opt-in."
    ),
    entry(
      "AsyncSequence / AsyncIteratorProtocol",
      conformances: ["AsyncSequence", "AsyncIteratorProtocol"],
      tier: .one,
      laws: [
        law(
          "async-sequence.functor-identity",
          "For a replayable deterministic source, map(identity) preserves collected elements"
        ),
        law(
          "async-sequence.functor-composition",
          "For equivalent replayable sources, total maps obey functor composition"
        ),
        law(
          "async-sequence.sync-equivalence",
          "A finite deterministic source agrees with synchronous filter and compactMap"
        ),
        law(
          "async-sequence.stream-collection",
          "A finished, non-dropping AsyncStream created from an array reconstructs the array"
        ),
        law(
          "async-iterator.nil-is-terminal",
          "After next() returns nil, later calls remain nil when documented"
        ),
        law(
          "async-sequence.cancellation",
          "A sequence documenting cooperative cancellation terminates within a test deadline"
        ),
      ],
      capabilities: ["Functor and Monad harness", "equivalence relation", "state-machine"],
      notes: "AsyncSequence does not require cancellation to terminate iteration. Replay-based "
        + "laws need fresh equivalent finite sources without external side effects. For "
        + "swift-async-algorithms, apply collection laws to finite nonthrowing sources without "
        + "cancellation or dropped buffered elements."
    ),
    entry(
      "Clock / InstantProtocol / DurationProtocol",
      conformances: ["Clock", "InstantProtocol", "DurationProtocol"],
      tier: .two,
      laws: [
        law(
          "instant.distance-advance-roundtrip",
          "For representable instants, a.advanced(by: a.duration(to: b)) == b"
        ),
        law(
          "instant.duration-antisymmetry",
          "For representable durations, a.duration(to: b) == -b.duration(to: a)"
        ),
        law(
          "clock.now-monotonic",
          "ContinuousClock.now is monotonically nondecreasing"
        ),
        law(
          "duration.arithmetic",
          "Duration obeys AdditiveArithmetic and documented scaling laws"
        ),
      ],
      capabilities: ["Strideable-like laws", "monotonicity", "arithmetic"]
    ),
    entry(
      "AtomicRepresentable (Synchronization)",
      conformances: ["AtomicRepresentable"],
      module: "Synchronization",
      tier: .two,
      laws: [
        law(
          "atomic-representable.roundtrip",
          "Decoding an encoded atomic representation reconstructs the value"
        ),
        law(
          "atomic.counter-linearizability",
          "Atomic counter operations are linearizable under valid memory orderings"
        ),
      ],
      capabilities: ["round-trip", "linearizability counter specification"],
      notes: "The counter law targets Atomic values used through a declared counter interface. "
        + "Swift Synchronization Mutex is also a linearizability target."
    ),
    entry(
      "RegexComponent / CustomConsumingRegexComponent",
      conformances: ["RegexComponent", "CustomConsumingRegexComponent"],
      module: "Swift (_StringProcessing / RegexBuilder)",
      tier: .two,
      laws: [
        law(
          "regex-component.parse-format-roundtrip",
          "A component paired with a formatter may opt into parse(format(x)) == x"
        ),
        law(
          "regex-component.concatenation",
          "Context-independent components match concatenated independently matching inputs"
        ),
        law(
          "regex-component.whole-first",
          "For a pure component, a whole match implies a first match on the same input"
        ),
      ],
      capabilities: ["round-trip", "implication", "metamorphic"],
      notes: "RegexComponent has no formatting requirement. Round-trip and concatenation laws "
        + "need explicitly paired, context-independent components."
    ),
  ]
}
