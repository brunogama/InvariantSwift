/// Protocol for types that can generate arbitrary instances.
///
/// Types conforming to `Generatable` can provide an arbitrary generator
/// that produces random values for property-based testing.
///
/// This is typically synthesized by the `@Arbitrary` macro, but can also
/// be manually implemented for custom types.
///
/// - Example:
///   ```swift
///   extension MyType: Generatable {
///     static var arbitrary: Gen<MyType> {
///       Gen.zip(Gen.int, Gen.string).map { MyType(id: $0, name: $1) }
///     }
///   }
///   ```
///
/// - See Also: ``Gen``
public protocol Generatable {
  associatedtype GeneratorType
  static var arbitrary: GeneratorType { get }
}
