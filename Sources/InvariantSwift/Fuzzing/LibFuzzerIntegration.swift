/// LibFuzzer Integration for InvariantSwift
///
/// Provides a bridge between industrial fuzzing engines (LibFuzzer, AFL) and
/// Swift property-based testing. Enables high-throughput, coverage-guided fuzzing
/// of Swift properties using fuzz engine infrastructure.
///
/// **Architecture Overview:**
/// - `FuzzProvider`: Consumes raw bytes from fuzzing engine, produces typed values
/// - `FuzzTestRunner`: Orchestrates property execution with fuzzer input
/// - `FuzzableGenerator`: Adapts Gen<T> to consume fuzzer bytes deterministically
///
/// **Usage:**
/// ```swift
/// // Define a fuzz target
/// let target = FuzzTarget(
///   generator: Gen.array(Gen.int),
///   property: { array in array.sorted() == array.sorted().sorted() }
/// )
///
/// // Execute with LibFuzzer
/// FuzzTestRunner.registerTarget(target)
/// ```

import Foundation

// MARK: - Fuzz Data Provider

/// **Consumes bytes from fuzzing engine to produce typed values**
///
/// Implements a deterministic byte-to-value mapping that enables fuzzing engines
/// to explore the input space systematically. The fuzzer can mutate the byte buffer
/// to discover interesting test cases.
///
/// **External References:**
/// - [LibFuzzer FuzzedDataProvider](https://llvm.org/docs/LibFuzzer.html#fuzzed-data-provider)
/// - [AFL Technical Whitepaper](https://lcamtuf.coredump.cx/afl/technical_details.txt)
public struct FuzzDataProvider: Sendable {
  private var data: [UInt8]
  private var position: Int = 0

  /// Total bytes available
  public var totalBytes: Int { data.count }

  /// Remaining bytes available
  public var remainingBytes: Int { max(0, data.count - position) }

  /// Whether there are bytes remaining
  public var hasRemaining: Bool { remainingBytes > 0 }

  /// Creates a new fuzz data provider from raw bytes
  public init(data: [UInt8]) {
    self.data = data
  }

  /// Creates a new fuzz data provider from Data
  public init(data: Data) {
    self.data = Array(data)
  }

  /// Creates a new fuzz data provider from UnsafeBufferPointer
  public init(buffer: UnsafeBufferPointer<UInt8>) {
    self.data = Array(buffer)
  }

  // MARK: - Integer Consumption

  /// Consume a single byte
  public mutating func consumeByte() -> UInt8 {
    guard position < data.count else { return 0 }
    let value = data[position]
    position += 1
    return value
  }

  /// Consume bytes into buffer
  public mutating func consumeBytes(_ count: Int) -> [UInt8] {
    let available = min(count, remainingBytes)
    let result = Array(data[position..<(position + available)])
    position += available
    return result + Array(repeating: 0, count: count - available)
  }

  /// Consume a boolean
  public mutating func consumeBool() -> Bool {
    consumeByte() & 1 == 1
  }

  /// Consume a UInt8
  public mutating func consumeUInt8() -> UInt8 {
    consumeByte()
  }

  /// Consume a UInt16
  public mutating func consumeUInt16() -> UInt16 {
    let bytes = consumeBytes(2)
    return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
  }

  /// Consume a UInt32
  public mutating func consumeUInt32() -> UInt32 {
    let bytes = consumeBytes(4)
    return UInt32(bytes[0])
      | (UInt32(bytes[1]) << 8)
      | (UInt32(bytes[2]) << 16)
      | (UInt32(bytes[3]) << 24)
  }

  /// Consume a UInt64
  public mutating func consumeUInt64() -> UInt64 {
    let bytes = consumeBytes(8)
    return UInt64(bytes[0])
      | (UInt64(bytes[1]) << 8)
      | (UInt64(bytes[2]) << 16)
      | (UInt64(bytes[3]) << 24)
      | (UInt64(bytes[4]) << 32)
      | (UInt64(bytes[5]) << 40)
      | (UInt64(bytes[6]) << 48)
      | (UInt64(bytes[7]) << 56)
  }

  /// Consume an Int8
  public mutating func consumeInt8() -> Int8 {
    Int8(bitPattern: consumeUInt8())
  }

  /// Consume an Int16
  public mutating func consumeInt16() -> Int16 {
    Int16(bitPattern: consumeUInt16())
  }

  /// Consume an Int32
  public mutating func consumeInt32() -> Int32 {
    Int32(bitPattern: consumeUInt32())
  }

  /// Consume an Int64
  public mutating func consumeInt64() -> Int64 {
    Int64(bitPattern: consumeUInt64())
  }

  /// Consume an Int
  public mutating func consumeInt() -> Int {
    Int(truncatingIfNeeded: consumeInt64())
  }

  /// Consume an integer in range
  public mutating func consumeInt(in range: ClosedRange<Int>) -> Int {
    guard !range.isEmpty else { return range.lowerBound }
    let spread = UInt64(range.upperBound - range.lowerBound)
    guard spread > 0 else { return range.lowerBound }
    return range.lowerBound + Int(consumeUInt64() % (spread + 1))
  }

  // MARK: - Floating Point Consumption

  /// Consume a Double in [0, 1)
  public mutating func consumeProbability() -> Double {
    Double(consumeUInt64()) / Double(UInt64.max)
  }

  /// Consume a Double
  public mutating func consumeDouble() -> Double {
    Double(bitPattern: consumeUInt64())
  }

  /// Consume a Float
  public mutating func consumeFloat() -> Float {
    Float(bitPattern: consumeUInt32())
  }

  /// Consume a regularized Double (not NaN or infinite)
  public mutating func consumeRegularDouble() -> Double {
    var result = consumeDouble()
    while !result.isFinite {
      result = consumeDouble()
    }
    return result
  }

  // MARK: - String Consumption

  /// Consume a string of given length
  public mutating func consumeString(length: Int) -> String {
    let bytes = consumeBytes(length)
    return String(bytes: bytes, encoding: .utf8)
      ?? String(bytes.map { Character(UnicodeScalar($0)) })
  }

  /// Consume a string up to maxLength using remaining bytes
  public mutating func consumeString(maxLength: Int = 1000) -> String {
    let length = consumeInt(in: 0...min(maxLength, remainingBytes))
    return consumeString(length: length)
  }

  /// Consume an ASCII string
  public mutating func consumeASCIIString(maxLength: Int = 1000) -> String {
    let length = consumeInt(in: 0...min(maxLength, remainingBytes))
    let bytes = consumeBytes(length).map { $0 % 128 }
    return String(bytes: bytes, encoding: .ascii) ?? ""
  }

  /// Consume an alphanumeric string
  public mutating func consumeAlphanumericString(maxLength: Int = 100) -> String {
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let charsArray = Array(chars)
    let length = consumeInt(in: 0...min(maxLength, remainingBytes))
    return String(
      (0..<length).map { _ in
        charsArray[Int(consumeByte()) % charsArray.count]
      }
    )
  }

  // MARK: - Character Consumption

  /// Consume a single Character
  public mutating func consumeCharacter() -> Character {
    let byte = consumeByte()
    return Character(UnicodeScalar(byte))
  }

  /// Consume a Character from ASCII printable range
  public mutating func consumePrintableCharacter() -> Character {
    // Printable ASCII: 32-126
    let byte = 32 + (consumeByte() % 95)
    return Character(UnicodeScalar(byte))
  }

  /// Consume a letter (a-z, A-Z)
  public mutating func consumeLetter() -> Character {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let index = Int(consumeByte()) % letters.count
    return letters[letters.index(letters.startIndex, offsetBy: index)]
  }

  // MARK: - UInt Consumption

  /// Consume a UInt
  public mutating func consumeUInt() -> UInt {
    UInt(truncatingIfNeeded: consumeUInt64())
  }

  /// Consume a UInt in range
  public mutating func consumeUInt(in range: ClosedRange<UInt>) -> UInt {
    guard !range.isEmpty else { return range.lowerBound }
    let spread = range.upperBound - range.lowerBound
    guard spread > 0 else { return range.lowerBound }
    return range.lowerBound + UInt(consumeUInt64() % UInt64(spread + 1))
  }

  // MARK: - Collection Consumption

  /// Consume an array by repeatedly consuming elements
  public mutating func consumeArray<T>(
    maxCount: Int = 100,
    consuming: (inout Self) -> T
  ) -> [T] {
    let count = consumeInt(in: 0...min(maxCount, remainingBytes))
    return (0..<count).map { _ in consuming(&self) }
  }

  /// Pick an element from an array
  public mutating func pickElement<T>(from array: [T]) -> T? {
    guard !array.isEmpty else { return nil }
    let index = consumeInt(in: 0...(array.count - 1))
    return array[index]
  }

  /// Consume an optional value (nil or some)
  public mutating func consumeOptional<T>(
    consuming: (inout Self) -> T
  ) -> T? {
    consumeBool() ? consuming(&self) : nil
  }

  /// Consume a dictionary
  public mutating func consumeDictionary<K, V>(
    maxCount: Int = 50,
    consumingKey: (inout Self) -> K,
    consumingValue: (inout Self) -> V
  ) -> [K: V] where K: Hashable {
    let count = consumeInt(in: 0...min(maxCount, remainingBytes / 2))
    var dict: [K: V] = [:]
    for _ in 0..<count {
      let key = consumingKey(&self)
      let value = consumingValue(&self)
      dict[key] = value
    }
    return dict
  }

  /// Consume a set
  public mutating func consumeSet<T: Hashable>(
    maxCount: Int = 50,
    consuming: (inout Self) -> T
  ) -> Set<T> {
    let count = consumeInt(in: 0...min(maxCount, remainingBytes))
    var set = Set<T>()
    for _ in 0..<count {
      set.insert(consuming(&self))
    }
    return set
  }

  // MARK: - Foundation Type Consumption

  /// Consume Data
  public mutating func consumeData(maxLength: Int = 1000) -> Data {
    let length = consumeInt(in: 0...min(maxLength, remainingBytes))
    return Data(consumeBytes(length))
  }

  /// Consume a UUID
  public mutating func consumeUUID() -> UUID {
    let bytes = consumeBytes(16)
    // Create UUID from bytes (RFC 4122 compliant)
    var uuid = bytes
    uuid[6] = (uuid[6] & 0x0F) | 0x40  // Version 4
    uuid[8] = (uuid[8] & 0x3F) | 0x80  // Variant 1
    return UUID(
      uuid: (
        uuid[0], uuid[1], uuid[2], uuid[3],
        uuid[4], uuid[5], uuid[6], uuid[7],
        uuid[8], uuid[9], uuid[10], uuid[11],
        uuid[12], uuid[13], uuid[14], uuid[15]
      )
    )
  }

  /// Consume a Date within a range
  public mutating func consumeDate(
    from: Date = Date(timeIntervalSince1970: 0),
    to: Date = Date()
  ) -> Date {
    let fromInterval = from.timeIntervalSince1970
    let toInterval = to.timeIntervalSince1970
    let range = toInterval - fromInterval
    let offset = consumeProbability() * range
    return Date(timeIntervalSince1970: fromInterval + offset)
  }

  /// Consume a Date within last N years
  public mutating func consumeRecentDate(withinYears years: Int = 10) -> Date {
    let now = Date()
    let yearsAgo = now.addingTimeInterval(-Double(years) * 365.25 * 24 * 60 * 60)
    return consumeDate(from: yearsAgo, to: now)
  }

  // MARK: - Enum/Case Consumption

  /// Consume an enum case by index
  public mutating func consumeEnumCase<T: CaseIterable>() -> T {
    let allCases = Array(T.allCases)
    let index = Int(consumeUInt64()) % allCases.count
    return allCases[index]
  }

  /// Consume weighted choice from options
  public mutating func consumeWeighted<T>(
    _ options: [(weight: Int, value: T)]
  ) -> T? {
    guard !options.isEmpty else { return nil }
    let totalWeight = options.reduce(0) { $0 + $1.weight }
    guard totalWeight > 0 else { return options.first?.value }

    var remaining = consumeInt(in: 0...(totalWeight - 1))
    for option in options {
      if remaining < option.weight {
        return option.value
      }
      remaining -= option.weight
    }
    return options.last?.value
  }
}

// MARK: - Fuzzable Random Number Generator

/// **Random number generator backed by fuzz data**
///
/// Allows existing `Gen<T>` types to be driven by fuzzer input instead of
/// system randomness. This enables deterministic replay and fuzzer-guided
/// exploration of the generator's output space.
public struct FuzzableRNG: RandomNumberGenerator, Sendable {
  private var provider: FuzzDataProvider

  /// Creates a fuzzable RNG from a data provider
  public init(provider: FuzzDataProvider) {
    self.provider = provider
  }

  /// Creates a fuzzable RNG from raw bytes
  public init(data: [UInt8]) {
    self.provider = FuzzDataProvider(data: data)
  }

  /// Generate next random UInt64
  public mutating func next() -> UInt64 {
    provider.consumeUInt64()
  }

  /// Remaining bytes in underlying provider
  public var remainingBytes: Int {
    provider.remainingBytes
  }
}

// MARK: - Fuzz Target

/// **Fuzz target wrapping a property test**
///
/// Encapsulates a generator and property predicate for use with fuzzing engines.
/// The target consumes bytes to generate inputs and reports the property result.
public struct FuzzTarget<T: Sendable>: Sendable {
  /// The generator for input values
  public let generator: Gen<T>

  /// The property predicate to test
  public let property: @Sendable (T) -> Bool

  /// Target name for logging/identification
  public let name: String

  /// Creates a new fuzz target
  public init(
    name: String = "FuzzTarget",
    generator: Gen<T>,
    property: @escaping @Sendable (T) -> Bool
  ) {
    self.name = name
    self.generator = generator
    self.property = property
  }

  /// Execute the target with given fuzz data
  ///
  /// - Parameter data: Raw bytes from fuzzer
  /// - Returns: Result indicating pass/fail/error
  public func execute(data: [UInt8]) -> FuzzResult {
    var rng: any RandomNumberGenerator = FuzzableRNG(data: data)

    // Determine size based on available data
    let size = Size(value: max(1, min(100, data.count / 4)))

    // Generate input
    let input = generator.generate(&rng, size)

    // Test property
    let result = property(input)
    if result {
      return .pass
    } else {
      return .fail(input: "\(input)")
    }
  }
}

/// Result of a fuzz execution
public enum FuzzResult: Sendable, CustomStringConvertible {
  case pass
  case fail(input: String)
  case error(message: String)

  public var isFailure: Bool {
    switch self {
    case .pass: return false
    case .fail, .error: return true
    }
  }

  public var description: String {
    switch self {
    case .pass:
      return "PASS"

    case .fail(let input):
      return "FAIL: \(input)"

    case .error(let message):
      return "ERROR: \(message)"
    }
  }
}

// MARK: - Fuzz Test Runner

/// **Orchestrates fuzzing execution and reporting**
///
/// Manages fuzz target registration, execution tracking, and result aggregation.
/// Can be used standalone or integrated with LibFuzzer via C entry point.
public actor FuzzTestRunner {

  /// Registered fuzz targets by name
  private var targets: [String: any FuzzTargetProtocol] = [:]

  /// Execution statistics
  private var executionCount: Int = 0
  private var passCount: Int = 0
  private var failCount: Int = 0
  private var lastFailure: String?

  /// Shared runner instance
  public static let shared = FuzzTestRunner()

  /// Initialize a new runner
  public init() {}

  /// Register a fuzz target
  public func register<T>(_ target: FuzzTarget<T>) {
    targets[target.name] = target
  }

  /// Execute a target with given data
  public func execute(targetName: String, data: [UInt8]) -> FuzzResult {
    guard let target = targets[targetName] else {
      return .error(message: "Target '\(targetName)' not found")
    }

    executionCount += 1
    let result = target.executeAny(data: data)

    switch result {
    case .pass:
      passCount += 1

    case .fail(let input):
      failCount += 1
      lastFailure = input

    case .error:
      failCount += 1
    }

    return result
  }

  /// Execute the default (first registered) target
  public func executeDefault(data: [UInt8]) -> FuzzResult {
    guard let targetName = targets.keys.first else {
      return .error(message: "No targets registered")
    }
    return execute(targetName: targetName, data: data)
  }

  /// Get execution statistics
  public func getStatistics() -> FuzzStatistics {
    FuzzStatistics(
      executionCount: executionCount,
      passCount: passCount,
      failCount: failCount,
      lastFailure: lastFailure
    )
  }

  /// Reset statistics
  public func resetStatistics() {
    executionCount = 0
    passCount = 0
    failCount = 0
    lastFailure = nil
  }
}

/// Statistics from fuzz execution
public struct FuzzStatistics: Sendable {
  public let executionCount: Int
  public let passCount: Int
  public let failCount: Int
  public let lastFailure: String?

  public var successRate: Double {
    guard executionCount > 0 else { return 0 }
    return Double(passCount) / Double(executionCount)
  }
}

/// Protocol for type-erasing fuzz targets
public protocol FuzzTargetProtocol: Sendable {
  func executeAny(data: [UInt8]) -> FuzzResult
}

extension FuzzTarget: FuzzTargetProtocol {
  public func executeAny(data: [UInt8]) -> FuzzResult {
    execute(data: data)
  }
}

// MARK: - LibFuzzer C Interface

/// **LibFuzzer entry point**
///
/// This function is called by LibFuzzer with mutated input data.
/// Define `LLVMFuzzerTestOneInput` in your fuzz target to use this.
///
/// **Usage:**
/// Create a separate file for your fuzz target:
/// ```swift
/// import InvariantSwift
///
/// @_cdecl("LLVMFuzzerTestOneInput")
/// public func LLVMFuzzerTestOneInput(_ data: UnsafePointer<UInt8>, _ size: Int) -> Int32 {
///   let bytes = Array(UnsafeBufferPointer(start: data, count: size))
///   let result = FuzzBridge.testOneInput(bytes)
///   return result ? 0 : -1
/// }
/// ```
@MainActor
public enum FuzzBridge {

  /// Default fuzz target for LibFuzzer integration
  public static var defaultTarget: (any FuzzTargetProtocol)?

  /// Process one fuzzer input
  ///
  /// - Parameter data: Raw bytes from fuzzer
  /// - Returns: true if property holds, false if violation found
  public static func testOneInput(_ data: [UInt8]) -> Bool {
    guard let target = defaultTarget else {
      // No target registered - pass through
      return true
    }

    let result = target.executeAny(data: data)
    return !result.isFailure
  }

  /// Register the default fuzz target
  public static func setDefaultTarget<T>(_ target: FuzzTarget<T>) {
    defaultTarget = target
  }
}

// MARK: - Gen Extension for Fuzzing

extension Gen where T: Sendable {

  /// Execute this generator with fuzz data
  ///
  /// - Parameter data: Raw bytes from fuzzer
  /// - Returns: Generated value
  public func fuzz(with data: [UInt8]) -> T {
    var rng: any RandomNumberGenerator = FuzzableRNG(data: data)
    let size = Size(value: max(1, min(100, data.count / 4)))
    return generate(&rng, size)
  }

  /// Create a fuzz target from this generator
  ///
  /// - Parameters:
  ///   - name: Target name
  ///   - property: Property to test
  /// - Returns: Fuzz target ready for registration
  public func fuzzTarget(
    name: String = "PropertyFuzz",
    property: @escaping @Sendable (T) -> Bool
  ) -> FuzzTarget<T> {
    FuzzTarget(name: name, generator: self, property: property)
  }
}

// MARK: - Property Extension for Fuzzing

extension Property where T: Sendable {

  /// Execute this property with fuzz data
  ///
  /// - Parameter data: Raw bytes from fuzzer
  /// - Returns: Property result
  public func fuzz(with data: [UInt8]) -> Bool {
    var rng: any RandomNumberGenerator = FuzzableRNG(data: data)
    let size = Size(value: max(1, min(100, data.count / 4)))
    let input = generator.generate(&rng, size)
    return predicate(input)
  }
}

// MARK: - Fuzzing Mode

/// Determines how a fuzzable target should be executed.
///
/// **Usage:**
/// ```swift
/// @Fuzzable(mode: .hybrid(propertyIterations: 1000, fuzzRuns: 100_000))
/// func parseComplex(_ data: Data) { ... }
/// ```
public enum FuzzingMode: Sendable, Equatable {
  /// Property testing with random generation
  case propertyTest(iterations: Int)

  /// LibFuzzer mutation-based fuzzing
  case libfuzzer(runs: Int, timeout: Duration)

  /// Hybrid: property test then fuzz failures
  case hybrid(propertyIterations: Int, fuzzRuns: Int)

  /// OSS-Fuzz compatible mode
  case ossFuzz

  /// Default mode (property test with 100 iterations)
  public static var `default`: Self {
    .propertyTest(iterations: 100)
  }
}

// MARK: - Crash Type

/// Type of crash detected by fuzzer.
public enum CrashType: String, Sendable, CaseIterable {
  /// Segmentation fault (memory access violation)
  case segv = "SEGV"

  /// Abort (assertion failure or explicit abort)
  case abrt = "ABRT"

  /// Execution timeout
  case timeout = "TIMEOUT"

  /// Out of memory
  case oom = "OOM"

  /// Stack overflow
  case stackOverflow = "STACK_OVERFLOW"

  /// Undefined behavior (UBSan)
  case undefinedBehavior = "UBSAN"

  /// Address sanitizer violation
  case addressSanitizer = "ASAN"

  /// Unknown crash
  case unknown = "UNKNOWN"
}

// MARK: - Fuzzing Crash

/// Represents a crash discovered during fuzzing.
///
/// Contains all information needed to reproduce and analyze the crash.
public struct FuzzingCrash: Sendable, CustomStringConvertible {
  /// Raw input bytes that triggered the crash
  public let input: Data

  /// Input as hexadecimal string
  public var inputHex: String {
    input.map { String(format: "%02x", $0) }.joined()
  }

  /// Type of crash
  public let crashType: CrashType

  /// Stack trace at crash point
  public let stackTrace: String

  /// Minimized input (if crash minimization was performed)
  public let minimized: Data?

  /// Timestamp of crash discovery
  public let timestamp: Date

  /// Target function name
  public let targetName: String

  public init(
    input: Data,
    crashType: CrashType,
    stackTrace: String = "",
    minimized: Data? = nil,
    timestamp: Date = Date(),
    targetName: String = ""
  ) {
    self.input = input
    self.crashType = crashType
    self.stackTrace = stackTrace
    self.minimized = minimized
    self.timestamp = timestamp
    self.targetName = targetName
  }

  public var description: String {
    """
    FuzzingCrash[\(crashType.rawValue)]
    Target: \(targetName)
    Input: \(input.count) bytes
    Hex: \(inputHex.prefix(64))...
    """
  }

  /// Convert to property test reproduction.
  ///
  /// Generates Swift code that can reproduce this crash as a unit test.
  ///
  /// - Returns: Swift test function code
  public func toPropertyTest() -> String {
    let hexPrefix = inputHex.prefix(8)
    let dataLiteral = input.map { "0x\(String(format: "%02x", $0))" }.joined(separator: ", ")

    return """
      @Test
      func testCrash_\(hexPrefix)() {
          let input = Data([\(dataLiteral)])
          // Expected to crash or be fixed
          _ = try? \(targetName)(input)
      }
      """
  }

  /// Convert to @Reproduce annotation.
  ///
  /// - Returns: @Reproduce annotation for the failing input
  public func toReproduceAnnotation() -> String {
    "@Reproduce(input: \"\(input.base64EncodedString())\")"
  }

  /// Save crash to file for corpus.
  ///
  /// - Parameter directory: Directory to save crash file
  /// - Returns: Path to saved file
  public func save(to directory: URL) throws -> URL {
    let filename = "crash_\(crashType.rawValue.lowercased())_\(inputHex.prefix(16)).bin"
    let path = directory.appendingPathComponent(filename)
    try input.write(to: path)
    return path
  }
}

// MARK: - Sanitizer

/// Compiler sanitizers for fuzzing.
public struct Sanitizer: OptionSet, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  /// Address Sanitizer (memory errors)
  public static let address = Self(rawValue: 1 << 0)

  /// Undefined Behavior Sanitizer
  public static let undefined = Self(rawValue: 1 << 1)

  /// Thread Sanitizer (data races)
  public static let thread = Self(rawValue: 1 << 2)

  /// Memory Sanitizer (uninitialized reads)
  public static let memory = Self(rawValue: 1 << 3)

  /// Fuzzer sanitizer (coverage instrumentation)
  public static let fuzzer = Self(rawValue: 1 << 4)

  /// All sanitizers enabled
  public static let all: Sanitizer = [.address, .undefined, .thread, .memory, .fuzzer]

  /// Standard fuzzing sanitizers (address + undefined + fuzzer)
  public static let standard: Sanitizer = [.address, .undefined, .fuzzer]

  /// Convert to compiler flags
  public var compilerFlags: [String] {
    var flags: [String] = []
    if contains(.address) { flags.append("-sanitize=address") }
    if contains(.undefined) { flags.append("-sanitize=undefined") }
    if contains(.thread) { flags.append("-sanitize=thread") }
    if contains(.memory) { flags.append("-sanitize=memory") }
    if contains(.fuzzer) { flags.append("-sanitize=fuzzer") }
    return flags
  }
}

// MARK: - Fuzzable Target Configuration

/// Configuration for a fuzzable target.
public struct FuzzableConfig: Sendable {
  /// Maximum input length in bytes
  public let maxLength: Int

  /// Execution timeout per input
  public let timeout: Duration

  /// Corpus directory path
  public let corpusDir: String?

  /// Fuzzing mode
  public let mode: FuzzingMode

  /// Sanitizers to enable
  public let sanitizers: Sanitizer

  public init(
    maxLength: Int = 4096,
    timeout: Duration = .seconds(30),
    corpusDir: String? = nil,
    mode: FuzzingMode = .default,
    sanitizers: Sanitizer = .standard
  ) {
    self.maxLength = maxLength
    self.timeout = timeout
    self.corpusDir = corpusDir
    self.mode = mode
    self.sanitizers = sanitizers
  }
  // swiftlint:disable:next file_length
}
