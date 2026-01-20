# API Design

### 7.1 API Principles

- **Composability**: Generators and properties compose via functor laws
- **Type Safety**: Compile-time guarantees via generics and strong typing
- **Ergonomics**: Macros hide boilerplate, operators enable fluent composition
- **Determinism**: Seeds ensure reproducible test runs
- **Efficiency**: Lazy evaluation and zero-copy semantics where possible

### 7.2 Core API Specifications

| API | Signature | Purpose | Concurrency |
|-----|-----------|---------|-------------|
| `Gen.map` | `(T -> U) -> Gen<U>` | Transform generated values | Sync |
| `Gen.flatMap` | `((T) -> Gen<U>) -> Gen<U>` | Compose generators | Sync |
| `Gen.zip` | `(Gen<U>) -> Gen<(T,U)>` | Combine generators | Sync |
| `Property.init` | `(generator, predicate) -> Property` | Create testable property | Sync |
| `PropertyRunner.runProperty` | `async -> PropertyResult<T>` | Execute test | Async (actor-isolated) |
| `@PropertyTest` | Macro attribute | Generate test from function | Compile-time |
| `@BusinessRule` | Macro attribute | Business-friendly property test | Compile-time |

### 7.3 Versioning Strategy

- **Semantic Versioning**: MAJOR.MINOR.PATCH
- **API Stability**: Public APIs marked with `@available` for deprecation
- **Generator Versioning**: Generator behavior changes tracked in changelog
- **Macro Stability**: Macro-generated code maintains forward compatibility

### 7.4 Rate Limiting

Not applicable (framework library, not service)

---
