// swiftlint:disable file_length
import Foundation

// MARK: - @Property Macro Declaration

/// A macro that generates Swift Testing-compatible property-based tests with automatic generation.
///
/// `@Property` transforms a function with parameters into a property-based test that:
/// 1. Infers generators for each parameter type (or uses explicit @Gen annotations)
/// 2. Creates a Property combining generators and test predicate
/// 3. Runs iterations with automatic shrinking on failure
/// 4. Reports results via Swift Testing's Issue API
///
/// **Philosophy**: "If you know how to write `@Test`, you know how to write `@Property`"
///
/// **Basic Usage:**
/// ```swift
/// @Test @Property
/// func additionCommutes(a: Int, b: Int) {
///     #expect(a + b == b + a)
/// }
/// ```
///
/// **With Configuration:**
/// ```swift
/// @Test @Property(iterations: 500, seed: 12345)
/// func sortingPreservesElements(array: [Int]) {
///     let sorted = array.sorted()
///     #expect(sorted.count == array.count)
///     #expect(Set(sorted) == Set(array))
/// }
/// ```
///
/// **With Explicit Generators:**
/// ```swift
/// @Test @Property
/// func boundedValues(
///     @Gen(.int(in: 1...100)) x: Int,
///     @Gen(.string(length: 1...20)) name: String
/// ) {
///     #expect(x > 0 && x <= 100)
///     #expect(name.count >= 1 && name.count <= 20)
/// }
/// ```
///
/// **With Custom Types:**
/// Custom types require `@Arbitrary` conformance or explicit `@Gen`:
/// ```swift
/// @Arbitrary
/// struct User {
///     let name: String
///     let age: Int
/// }
///
/// @Test @Property
/// func userValidation(user: User) {
///     #expect(user.age >= 0)
///     #expect(!user.name.isEmpty)
/// }
/// ```
///
/// - Parameters:
///   - iterations: Number of test iterations to run (default: 100)
///   - seed: Optional UInt64 seed for reproducible tests
///   - maxShrinks: Maximum shrinking attempts when failure is found (default: 1000)
///   - verbose: Enable verbose output for debugging (default: false)
///
/// - See Also: ``Gen``, ``Arbitrary``, ``PropertyTest``
@attached(peer, names: suffixed(_PropertyTest))
public macro Property(
  iterations: Int = 100,
  seed: UInt64? = nil,
  maxShrinks: Int = 1000,
  verbose: Bool = false
) = #externalMacro(module: "InvariantSwiftMacros", type: "PropertyMacro")

// MARK: - @AsyncPropertyTest Macro Declaration

/// A macro for testing concurrent Swift code with controlled scheduling.
///
/// `@AsyncPropertyTest` enables deterministic testing of race conditions by:
/// 1. Systematically exploring different interleavings of async operations
/// 2. Using property-based generation for test inputs
/// 3. Shrinking both inputs AND interleavings when failures are found
/// 4. Providing reproducible paths for exact failure replay
///
/// **Basic Usage:**
/// ```swift
/// @AsyncPropertyTest
/// func testCacheConcurrency(keys: [String]) async {
///     let cache = Cache()
///     await withTaskGroup(of: Void.self) { group in
///         for key in keys {
///             group.addTask { _ = await cache.get(key) }
///         }
///     }
///     #expect(await cache.isConsistent)
/// }
/// ```
///
/// **With Exhaustive Exploration:**
/// ```swift
/// @AsyncPropertyTest(scheduler: .exhaustive(depth: 5))
/// func testConcurrentDictionary(ops: [DictOperation]) async {
///     let dict = ConcurrentDictionary<String, Int>()
///     await withTaskGroup(of: Void.self) { group in
///         for op in ops {
///             group.addTask { await dict.apply(op) }
///         }
///     }
/// }
/// ```
///
/// **Scheduler Strategies:**
/// - `.random(seed:)` - Random interleaving (fast, default)
/// - `.exhaustive(depth:)` - Systematic exploration up to depth
/// - `.targeted(heuristic:)` - Prioritize bug-likely interleavings
/// - `.replay(path:)` - Replay exact interleaving for reproduction
///
/// - Parameters:
///   - scheduler: Strategy for exploring interleavings (default: .random)
///   - iterations: Number of input generations to test (default: 100)
///   - maxInterleavings: Maximum interleavings per input (default: 1000)
///   - timeout: Maximum time for test execution (default: 30 seconds)
///
/// - See Also: ``Scheduler``, ``InterleavingPath``, ``Property``
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
@attached(peer, names: suffixed(_AsyncPropertyTest))
public macro AsyncPropertyTest(
  scheduler: Scheduler.Strategy = .random(seed: nil),
  iterations: Int = 100,
  maxInterleavings: Int = 1000,
  timeout: Duration = .seconds(30)
) = #externalMacro(module: "InvariantSwiftMacros", type: "AsyncPropertyTestMacro")

// MARK: - @Gen Parameter Attribute

/// Specifies an explicit generator for a function parameter in a property-based test.
///
/// Use `@Gen` to override the default type-based generator inference with a custom
/// generator expression. This provides fine-grained control over test data generation.
///
/// **Generator DSL:**
///
/// **Primitives:**
/// ```swift
/// @Gen(.int)                       // Full range Int
/// @Gen(.int(in: 0...100))         // Bounded Int
/// @Gen(.int(.positive))           // Positive only
/// @Gen(.int(.negative))           // Negative only
/// @Gen(.int(.nonZero))            // Non-zero
///
/// @Gen(.string)                    // Alphanumeric string
/// @Gen(.string(length: 1...20))   // With length bounds
/// @Gen(.string(.ascii))           // ASCII only
/// @Gen(.string(.email))           // Email format
///
/// @Gen(.bool)                      // 50/50 true/false
/// @Gen(.double)                    // With special values (NaN, Inf)
/// @Gen(.double(in: 0.0...1.0))    // Bounded double
/// ```
///
/// **Collections:**
/// ```swift
/// @Gen(.array(of: .int))                    // Variable length array
/// @Gen(.array(of: .int, count: 5))          // Fixed length
/// @Gen(.array(of: .int, count: 1...10))     // Range length
/// @Gen(.set(of: .string))                   // Set generator
/// @Gen(.dictionary(keys: .string, values: .int))
/// ```
///
/// **Optionals:**
/// ```swift
/// @Gen(.optional(.string))    // Some or None
/// @Gen(.some(.string))        // Always Some
/// @Gen(.none)                 // Always nil
/// ```
///
/// **Combinators:**
/// ```swift
/// @Gen(.oneOf([.int(.positive), .int(.negative)]))
/// @Gen(.frequency([(3, .int(.positive)), (1, .int(.negative))]))
/// ```
///
/// **Usage Example:**
/// ```swift
/// @Test @Property
/// func boundedTest(
///     @Gen(.int(in: 1...100)) x: Int,
///     @Gen(.string(length: 5...10)) s: String,
///     @Gen(.array(of: .int(.positive), count: 1...5)) arr: [Int]
/// ) {
///     #expect(x >= 1 && x <= 100)
///     #expect(s.count >= 5 && s.count <= 10)
///     #expect(arr.allSatisfy { $0 > 0 })
/// }
/// ```
///
/// - Parameter generator: A generator expression from the DSL
///
/// - Note: When @Gen is not specified, the generator is inferred from the parameter type.
///
/// - See Also: ``Property``, ``Arbitrary``
@attached(peer)
public macro Gen(
  _ generator: GeneratorExpression
) = #externalMacro(module: "InvariantSwiftMacros", type: "GenMacro")

// MARK: - Generator Expression Type

/// A type representing generator expressions for the @Gen DSL.
///
/// This type is used by the `@Gen` macro to specify generator configurations.
/// The actual parsing and code generation happens at compile time via the macro.
///
/// **Note:** You don't construct these directly. Instead, use the DSL syntax:
/// ```swift
/// @Gen(.int(in: 0...100))
/// @Gen(.string(length: 5...20))
/// @Gen(.array(of: .bool))
/// ```
public struct GeneratorExpression: ExpressibleByNilLiteral, Sendable {
  public init(nilLiteral: ()) {}

  // MARK: - Primitives

  /// Generator for Int values
  public static var int: Self { Self(nilLiteral: ()) }

  /// Generator for Int values in a specific range
  public static func int(in range: ClosedRange<Int>) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for Int values with a modifier
  public static func int(_ modifier: IntModifier) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for UInt values
  public static var uint: Self { Self(nilLiteral: ()) }

  /// Generator for Bool values
  public static var bool: Self { Self(nilLiteral: ()) }

  /// Generator for Double values
  public static var double: Self { Self(nilLiteral: ()) }

  /// Generator for Double values in a specific range
  public static func double(in range: ClosedRange<Double>) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for Float values
  public static var float: Self { Self(nilLiteral: ()) }

  /// Generator for String values
  public static var string: Self { Self(nilLiteral: ()) }

  /// Generator for String values with specific length
  public static func string(length: ClosedRange<Int>) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for String values with a modifier
  public static func string(_ modifier: StringModifier) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for Character values
  public static var character: Self { Self(nilLiteral: ()) }

  /// Generator for UUID values
  public static var uuid: Self { Self(nilLiteral: ()) }

  /// Generator for Date values
  public static var date: Self { Self(nilLiteral: ()) }

  /// Generator for Data values
  public static var data: Self { Self(nilLiteral: ()) }

  /// Generator for URL values
  public static var url: Self { Self(nilLiteral: ()) }

  // MARK: - Collections

  /// Generator for arrays of a specific element type
  public static func array(of element: Self) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for arrays with fixed count
  public static func array(of element: Self, count: Int) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for arrays with count in range
  public static func array(
    of element: Self,
    count: ClosedRange<Int>
  ) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for sets of a specific element type
  public static func set(of element: Self) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator for dictionaries
  public static func dictionary(
    keys: Self,
    values: Self
  ) -> Self {
    Self(nilLiteral: ())
  }

  // MARK: - Optionals

  /// Generator for optional values (Some or None)
  public static func optional(_ inner: Self) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator that always produces Some
  public static func some(_ inner: Self) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator that always produces nil
  public static var none: Self { Self(nilLiteral: ()) }

  // MARK: - Combinators

  /// Generator that randomly selects from a list of generators
  public static func oneOf(_ generators: [Self]) -> Self {
    Self(nilLiteral: ())
  }

  /// Generator that selects based on frequency weights
  public static func frequency(_ weighted: [(Int, Self)]) -> Self {
    Self(nilLiteral: ())
  }

  /// Namespace for fake data generators
  public static var fake: FakeGeneratorNamespace { FakeGeneratorNamespace() }

  // MARK: - Fake Data Shorthand

  public static var firstName: Self { Self(nilLiteral: ()) }
  public static var lastName: Self { Self(nilLiteral: ()) }
  public static var fullName: Self { Self(nilLiteral: ()) }
  public static var namePrefix: Self { Self(nilLiteral: ()) }
  public static var nameSuffix: Self { Self(nilLiteral: ()) }
  public static var city: Self { Self(nilLiteral: ()) }
  public static var streetName: Self { Self(nilLiteral: ()) }
  public static var streetAddress: Self { Self(nilLiteral: ()) }
  public static var zipCode: Self { Self(nilLiteral: ()) }
  public static var state: Self { Self(nilLiteral: ()) }
  public static var country: Self { Self(nilLiteral: ()) }
  public static var latitude: Self { Self(nilLiteral: ()) }
  public static var longitude: Self { Self(nilLiteral: ()) }
  public static var username: Self { Self(nilLiteral: ()) }
  public static var domainName: Self { Self(nilLiteral: ()) }
  public static var ipV4Address: Self { Self(nilLiteral: ()) }
  public static var ipV6Address: Self { Self(nilLiteral: ()) }
  public static var password: Self { Self(nilLiteral: ()) }
  public static var companyName: Self { Self(nilLiteral: ()) }
  public static var companySuffix: Self { Self(nilLiteral: ()) }
  public static var catchPhrase: Self { Self(nilLiteral: ()) }
  public static var bs: Self { Self(nilLiteral: ()) }
  public static var productName: Self { Self(nilLiteral: ()) }
  public static var price: Self { Self(nilLiteral: ()) }
  public static var color: Self { Self(nilLiteral: ()) }
  public static var department: Self { Self(nilLiteral: ()) }
  public static var word: Self { Self(nilLiteral: ()) }
  public static var sentence: Self { Self(nilLiteral: ()) }
  public static var paragraph: Self { Self(nilLiteral: ()) }
}

public struct FakeGeneratorNamespace: Sendable {
  public var name: FakeNameGenerators { FakeNameGenerators() }
  public var address: FakeAddressGenerators { FakeAddressGenerators() }
  public var internet: FakeInternetGenerators { FakeInternetGenerators() }
  public var company: FakeCompanyGenerators { FakeCompanyGenerators() }
  public var commerce: FakeCommerceGenerators { FakeCommerceGenerators() }
  public var lorem: FakeLoremGenerators { FakeLoremGenerators() }
}

public struct FakeNameGenerators: Sendable {
  public var firstName: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var lastName: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var fullName: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var prefix: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var suffix: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
}

public struct FakeAddressGenerators: Sendable {
  public var city: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var streetName: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var streetAddress: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var zipCode: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var state: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var country: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var latitude: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var longitude: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
}

public struct FakeInternetGenerators: Sendable {
  public var email: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var username: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var domainName: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var url: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var ipV4Address: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var ipV6Address: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var password: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
}

public struct FakeCompanyGenerators: Sendable {
  public var name: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var suffix: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var catchPhrase: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var bs: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
}

public struct FakeCommerceGenerators: Sendable {
  public var productName: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var price: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var color: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var department: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
}

public struct FakeLoremGenerators: Sendable {
  public var word: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var sentence: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
  public var paragraph: GeneratorExpression { GeneratorExpression(nilLiteral: ()) }
}

// MARK: - Modifiers

/// Modifiers for Int generation
public enum IntModifier: Sendable {
  case positive
  case negative
  case nonZero
}

/// Modifiers for String generation
public enum StringModifier: Sendable {
  case ascii
  case alphanumeric
  case email
  case uuid
}

/// Adds a diagnostic label to a property test parameter.
///
/// Labels appear in failure messages instead of parameter names for clearer diagnostics.
///
/// Usage:
/// ```swift
/// @Property
/// func testUserValidation(
///     @Label("user age") age: Int,
///     @Label("account balance") balance: Decimal
/// ) {
///     #expect(age >= 0)
/// }
/// ```
///
/// When a test fails, the label appears in the output:
/// ```
/// Shrunk to minimal case:
///    user age = 0
///    account balance = -0.01
/// ```
///
/// - Parameter label: Human-readable description for the parameter
@attached(peer)
public macro Label(
  _ label: String
) = #externalMacro(module: "InvariantSwiftMacros", type: "LabelMacro")

// MARK: - @Composite Macro Declaration

/// Transforms a function using `#draw` into a generator with proper monadic binding.
///
/// `@Composite` enables declarative construction of dependent generators where
/// later values can depend on earlier ones, while preserving shrinking.
///
/// **Before (verbose monadic style):**
/// ```swift
/// let gen = Int.arbitrary.flatMap { a in
///     Int.arbitrary.suchThat { $0 > a }.map { b in (a, b) }
/// }
/// ```
///
/// **After (declarative style):**
/// ```swift
/// @Composite
/// func orderedPair() -> Gen<(Int, Int)> {
///     let a = #draw(Int.self)
///     let b = #draw(Int.self, .greaterThan(a))
///     return (a, b)
/// }
/// ```
///
/// **Features:**
/// - Dependencies are expressed via normal variables
/// - Shrinking is preserved automatically
/// - Works with constraints from `GeneratorConstraint`
///
/// **Complex Example:**
/// ```swift
/// @Composite
/// func validUser() -> Gen<User> {
///     let age = #draw(Int.self, .between(0...120))
///     let canDrink = age >= 21
///     let favoriteBar = canDrink ? #draw(String.self) : nil
///     return User(age: age, canDrink: canDrink, favoriteBar: favoriteBar)
/// }
/// ```
///
/// - See Also: ``draw(from:)``, ``GeneratorConstraint``
@attached(body)
public macro Composite() =
  #externalMacro(
    module: "InvariantSwiftMacros",
    type: "CompositeMacro"
  )

// MARK: - #draw Expression Macro

/// Draws a value from a generator within a `@Composite` function.
///
/// `#draw` is an expression macro that extracts a value from a generator,
/// allowing you to write dependent generator logic imperatively.
///
/// **Draw from a generator:**
/// ```swift
/// let value = #draw(from: Gen<Int>.int)
/// let item = #draw(from: validItems)
/// ```
///
/// **Draw from a type (uses Type.arbitrary):**
/// ```swift
/// let a = #draw(Int.self)
/// let user = #draw(User.self)
/// ```
///
/// **Draw with constraints:**
/// ```swift
/// let b = #draw(Int.self, .greaterThan(a))
/// let name = #draw(String.self, .nonEmpty)
/// let items = #draw([Product].self, .count(1...5))
/// ```
///
/// **Available Constraints:**
/// - Numeric: `.greaterThan`, `.lessThan`, `.between`, `.notEqual`
/// - Collection: `.nonEmpty`, `.count`, `.containing`, `.unique`
/// - String: `.alphabetic`, `.alphanumeric`, `.length`, `.matching`
/// - Custom: `.satisfying { predicate }`
///
/// - Important: `#draw` can only be used inside `@Composite` functions.
///
/// - See Also: ``Composite``, ``GeneratorConstraint``
@freestanding(expression)
public macro draw<T>(
  from generator: Gen<T>
) -> T = #externalMacro(module: "InvariantSwiftMacros", type: "DrawMacro")

/// Draws a value of the specified type (uses Type.arbitrary).
@freestanding(expression)
public macro draw<T: Generatable>(
  _ type: T.Type
) -> T = #externalMacro(module: "InvariantSwiftMacros", type: "DrawMacro")

/// Draws a value of the specified type with a constraint.
@freestanding(expression)
public macro draw<T: Generatable>(
  _ type: T.Type,
  _ constraint: GeneratorConstraint<T>
) -> T = #externalMacro(module: "InvariantSwiftMacros", type: "DrawMacro")

// MARK: - @RuleBasedTest Macro Declaration (ISP-0003)

/// Marks a struct as a rule-based state machine test.
///
/// `@RuleBasedTest` transforms a struct with `@Rule`, `@Bundle`, and `@Invariant`
/// annotations into a runnable state machine test. Rules define valid operations,
/// bundles accumulate values, and invariants are checked after each step.
///
/// **Basic Usage:**
/// ```swift
/// @RuleBasedTest
/// struct CounterSpec {
///     var expected = 0
///     let counter = Counter()
///
///     @Rule
///     mutating func increment() {
///         counter.increment()
///         expected += 1
///     }
///
///     @Rule
///     @Precondition { $0.expected > 0 }
///     mutating func decrement() {
///         counter.decrement()
///         expected -= 1
///     }
///
///     @Invariant
///     func valueMatches() -> Bool {
///         counter.value == expected
///     }
/// }
/// ```
///
/// **With Bundles:**
/// ```swift
/// @RuleBasedTest
/// struct DatabaseSpec {
///     @Bundle var keys: [String]
///     @Bundle var values: [Data]
///
///     @Rule(into: \.keys)
///     func generateKey() -> String { ... }
///
///     @Rule
///     @Precondition { !$0.keys.isEmpty }
///     func write(key: KeyRef, value: ValueRef) { ... }
/// }
/// ```
///
/// - Parameters:
///   - maxSteps: Maximum steps per example (default: 100)
///   - maxExamples: Maximum examples to run (default: 100)
///
/// - See Also: ``Rule``, ``Bundle``, ``Invariant``, ``Precondition``
@attached(member, names: named(rules), named(invariants), named(bundles), named(runTest))
@attached(extension, conformances: RuleBasedStateMachine)
public macro RuleBasedTest(
  maxSteps: Int = 100,
  maxExamples: Int = 100
) = #externalMacro(module: "InvariantSwiftMacros", type: "RuleBasedTestMacro")

// MARK: - @Rule Macro Declaration

/// Marks a method as a rule that can be executed in a state machine test.
///
/// Rules are the operations that the test runner can execute. Each rule can have
/// a weight (higher = more likely to be selected) and optionally produce values
/// into a bundle.
///
/// **Basic Rule:**
/// ```swift
/// @Rule
/// mutating func increment() {
///     counter.increment()
/// }
/// ```
///
/// **Weighted Rule:**
/// ```swift
/// @Rule(weight: 3)  // 3x more likely than default
/// mutating func commonOperation() { }
/// ```
///
/// **Rule with Bundle Output:**
/// ```swift
/// @Rule(into: \.users)
/// func createUser() -> User {
///     let user = User(...)
///     database.insert(user)
///     return user
/// }
/// ```
///
/// - Parameters:
///   - into: Optional bundle keypath for storing returned values
///   - weight: Selection weight (default: 1)
///
/// - See Also: ``RuleBasedTest``, ``Precondition``
@attached(peer)
public macro Rule(
  into bundle: AnyKeyPath? = nil,
  weight: Int = 1
) = #externalMacro(module: "InvariantSwiftMacros", type: "RuleMacro")

// MARK: - @Bundle Macro Declaration

/// Marks a property as a bundle that accumulates values across rules.
///
/// Bundles are collections that grow as rules produce values. Rules can then
/// draw from bundles using `BundleRef<T>` parameters to ensure they always
/// reference valid, previously-generated values.
///
/// **Usage:**
/// ```swift
/// @Bundle var users: [User]
/// @Bundle var keys: [String]
/// @Bundle var posts: [Post]
/// ```
@attached(accessor)
public macro Bundle() = #externalMacro(module: "InvariantSwiftMacros", type: "BundleMacro")

// MARK: - @Precondition Macro Declaration

/// Adds a precondition that must be true for a rule to be considered.
///
/// When selecting the next rule to execute, only rules whose preconditions
/// are satisfied are considered. This ensures valid operation sequences.
///
/// **Usage:**
/// ```swift
/// @Rule
/// @Precondition { $0.users.count > 0 }
/// func deleteUser(user: UserRef) {
///     database.delete(user.value.id)
/// }
///
/// @Rule
/// @Precondition { !$0.keys.isEmpty && !$0.values.isEmpty }
/// func write(key: KeyRef, value: ValueRef) { ... }
/// ```
///
/// - Parameter check: Closure that takes the current state and returns true if valid
@attached(peer)
public macro Precondition(
  _ check: @escaping (Any) -> Bool
) = #externalMacro(module: "InvariantSwiftMacros", type: "PreconditionMacro")

// MARK: - @Invariant Macro Declaration

/// Marks a method as an invariant that is checked after every rule execution.
///
/// Invariants are properties that must always hold. After each rule executes,
/// all invariants are checked. If any returns false, the test fails and the
/// step sequence is shrunk to find the minimal failing sequence.
///
/// **Usage:**
/// ```swift
/// @Invariant
/// func modelMatchesDatabase() -> Bool {
///     model.allSatisfy { key, value in
///         database.read(key: key) == value
///     }
/// }
///
/// @Invariant
/// func counterIsNonNegative() -> Bool {
///     counter.value >= 0
/// }
/// ```
///
/// - Note: Invariants should be pure and not mutate state.
@attached(peer)
public macro Invariant() = #externalMacro(module: "InvariantSwiftMacros", type: "InvariantMacro")

// MARK: - @Reproduce Macro Declaration

/// Replay a specific failing example deterministically.
///
/// Use `@Reproduce` alongside `@PropertyTest` to fix the generation parameters
/// for exact reproduction of a failure. This is useful for debugging, regression
/// testing, and sharing failures with teammates.
///
/// **With Seed and Size:**
/// ```swift
/// @PropertyTest
/// @Reproduce(seed: 0xDEADBEEF, size: 42)
/// func testSorting(array: [Int]) {
///     // Will generate exact same array every time
/// }
/// ```
///
/// **With Shrink Path:**
/// ```swift
/// @PropertyTest
/// @Reproduce(seed: 12345, size: 50, path: "0:1:3:0:2")
/// func testComplex(data: ComplexStruct) {
///     // Replays the minimal shrunk example
/// }
/// ```
///
/// When a test fails, InvariantSwift outputs the exact `@Reproduce` annotation
/// to add for debugging:
/// ```
/// ❌ Property failed: testSorting
/// To reproduce this exact failure, add:
///     @Reproduce(seed: 0xDEADBEEF, size: 42, path: "0:1:3")
/// ```
///
/// - Parameters:
///   - seed: The random seed to use for generation
///   - size: Optional fixed size for generation
///   - path: Optional shrink path as colon-separated integers (e.g., "0:1:3")
@attached(peer)
public macro Reproduce(
  seed: UInt64,
  size: Int? = nil,
  path: String? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "ReproduceMacro")

/// Replay from serialized input directly.
///
/// Use when you want to replay with exact input data rather than regenerating.
///
/// **Usage:**
/// ```swift
/// @PropertyTest
/// @Reproduce(input: "eyJuYW1lIjoiSm9obiIsImFnZSI6MzB9")
/// func testUser(user: User) {
///     // Uses exact serialized User struct
/// }
/// ```
///
/// - Parameter input: Base64-encoded Codable input data
@attached(peer)
public macro Reproduce(
  input: String
) = #externalMacro(module: "InvariantSwiftMacros", type: "ReproduceMacro")
