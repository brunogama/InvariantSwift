extension ProtocolLawCatalog {
  static let appleFrameworkEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "Observable (Observation)",
      conformances: ["Observable"],
      module: "Observation",
      tier: .two,
      laws: [
        law(
          "observable.tracked-mutation",
          "A tracked mutation triggers onChange once for one tracking registration"
        ),
        law(
          "observable.untracked-read",
          "Reading an untracked property does not register observation"
        ),
        law(
          "observable.model-invariants",
          "Random model transitions preserve declared state invariants"
        ),
      ],
      capabilities: ["state-machine contracts", "invariant counting"]
    ),
    entry(
      "Publisher (Combine)",
      conformances: ["Publisher"],
      module: "Combine",
      tier: .one,
      laws: [
        law("publisher.functor-identity", "map(identity) preserves emitted events"),
        law(
          "publisher.functor-composition",
          "map(g composed with f) agrees with map(f).map(g)"
        ),
        law("publisher.flat-map-monad", "flatMap with Just as pure obeys monad laws"),
        law("publisher.filter-fusion", "Successive filters fuse with predicate conjunction"),
        law(
          "publisher.merge-zip",
          "merge preserves the value multiset and zip emits the shorter input count"
        ),
        law("publisher.scan", "scan emits the running states of the corresponding reduce"),
        law(
          "publisher.sequence-equivalence",
          "A deterministic sequence publisher agrees with Sequence operations"
        ),
      ],
      capabilities: ["Functor and Monad harness", "metamorphic equivalence", "permutation"],
      notes: "Use Publishers.Sequence and a collecting sink for deterministic suites."
    ),
    entry(
      "Subject / Subscriber / Scheduler",
      conformances: ["Subject", "Subscriber", "Scheduler"],
      module: "Combine",
      tier: .two,
      laws: [
        law("subject.post-completion", "Values sent after completion are not delivered"),
        law(
          "subscriber.demand",
          "A subscriber receives no more values than its available demand"
        ),
        law(
          "scheduler.ordering",
          "Scheduled work respects documented ordering and timing constraints"
        ),
        law(
          "scheduler-time.strideable",
          "SchedulerTimeType obeys applicable Strideable laws"
        ),
      ],
      capabilities: ["state-machine", "linearizability", "Strideable laws"]
    ),
    entry(
      "PersistentModel (SwiftData) / NSManagedObject",
      conformances: ["PersistentModel", "NSManagedObject"],
      module: "SwiftData / CoreData",
      tier: .two,
      laws: [
        law(
          "persistent-model.save-fetch",
          "Insert, save, and fetch reconstructs the persisted values"
        ),
        law("persistent-model.delete", "A deleted and saved object is absent from fetch"),
        law(
          "persistent-model.uniqueness",
          "Declared uniqueness constraints survive random command sequences"
        ),
        law(
          "persistent-model.predicate-equivalence",
          "A predicate fetch agrees with the matching in-memory filter"
        ),
      ],
      capabilities: ["dictionary reference model", "metamorphic equivalence"],
      notes: "Comparing #Predicate with a Swift closure is a strong metamorphic test."
    ),
    entry(
      "AppEnum / AppEntity / EntityQuery",
      conformances: ["AppEnum", "AppEntity", "EntityQuery"],
      module: "AppIntents",
      tier: .two,
      laws: [
        law("app-enum.base-laws", "AppEnum obeys CaseIterable and RawRepresentable laws"),
        law(
          "entity-query.id-membership",
          "entities(for: ids) returns only entities whose IDs were requested"
        ),
        law(
          "entity-string-query.relevance",
          "EntityStringQuery results satisfy the query's documented matching rule"
        ),
      ],
      capabilities: ["round-trip", "membership"]
    ),
    entry(
      "Plottable (Charts)",
      conformances: ["Plottable"],
      module: "Charts",
      tier: .two,
      laws: [
        law(
          "plottable.primitive-roundtrip",
          "init?(primitivePlottable: x.primitivePlottable) reconstructs x"
        )
      ],
      capabilities: ["prism round-trip"]
    ),
    entry(
      "Component (RealityKit) / Codable components",
      conformances: ["Component"],
      module: "RealityKit",
      tier: .three,
      laws: [
        law("reality-kit-component.codable-roundtrip", "Codable components round-trip")
      ],
      capabilities: ["round-trip"]
    ),
    entry(
      "GKRandom (GameplayKit)",
      conformances: ["GKRandom"],
      module: "GameplayKit",
      tier: .two,
      laws: [
        law(
          "gameplay-kit-random.upper-bound",
          "nextInt(upperBound:) returns a value below a positive bound"
        ),
        law(
          "gameplay-kit-random.seed-determinism",
          "Seeded random sources produce the same sequence for the same seed"
        ),
        law(
          "gameplay-kit-random.distribution",
          "Distribution samples approach documented streaming statistics"
        ),
      ],
      capabilities: ["bounds", "streaming statistics"],
      notes: "GKGaussianDistribution checks its mean and standard deviation statistically."
    ),
  ]
}
