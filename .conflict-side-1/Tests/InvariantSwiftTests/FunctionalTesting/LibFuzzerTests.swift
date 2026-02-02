/// LibFuzzerTests - Tests for LibFuzzer integration
///
/// Verifies FuzzDataProvider, FuzzableRNG, FuzzTarget, FuzzTestRunner,
/// and FuzzBridge functionality.

import Testing
import Foundation
import InvariantSwiftCore
@testable import InvariantSwift
@testable import InvariantSwiftExperimental

@Suite("LibFuzzer Integration")
struct LibFuzzerTests {

  // MARK: - FuzzDataProvider Tests

  @Test("FuzzDataProvider consumes bytes correctly")
  func testByteConsumption() {
    var provider = FuzzDataProvider(data: [0x01, 0x02, 0x03, 0x04])

    #expect(provider.totalBytes == 4)
    #expect(provider.remainingBytes == 4)

    let byte1 = provider.consumeByte()
    #expect(byte1 == 0x01)
    #expect(provider.remainingBytes == 3)

    let byte2 = provider.consumeByte()
    #expect(byte2 == 0x02)
  }

  @Test("FuzzDataProvider handles empty data")
  func testEmptyProvider() {
    var provider = FuzzDataProvider(data: [])

    #expect(!provider.hasRemaining)
    #expect(provider.consumeByte() == 0)
  }

  @Test("FuzzDataProvider consumeBytes returns correct array")
  func testConsumeBytes() {
    var provider = FuzzDataProvider(data: [1, 2, 3, 4, 5])

    let bytes = provider.consumeBytes(3)
    #expect(bytes == [1, 2, 3])
    #expect(provider.remainingBytes == 2)
  }

  @Test("FuzzDataProvider consumeBytes pads with zeros")
  func testConsumeBytesWithPadding() {
    var provider = FuzzDataProvider(data: [1, 2])

    let bytes = provider.consumeBytes(5)
    #expect(bytes == [1, 2, 0, 0, 0])
  }

  @Test("FuzzDataProvider consumeBool")
  func testConsumeBool() {
    var provider = FuzzDataProvider(data: [0, 1, 2, 3])

    let bool1 = provider.consumeBool()  // 0 & 1 == 0
    let bool2 = provider.consumeBool()  // 1 & 1 == 1
    let bool3 = provider.consumeBool()  // 2 & 1 == 0
    let bool4 = provider.consumeBool()  // 3 & 1 == 1

    #expect(!bool1)
    #expect(bool2)
    #expect(!bool3)
    #expect(bool4)
  }

  @Test("FuzzDataProvider consumeUInt16")
  func testConsumeUInt16() {
    var provider = FuzzDataProvider(data: [0x34, 0x12])

    let value = provider.consumeUInt16()
    #expect(value == 0x1234)
  }

  @Test("FuzzDataProvider consumeUInt32")
  func testConsumeUInt32() {
    var provider = FuzzDataProvider(data: [0x78, 0x56, 0x34, 0x12])

    let value = provider.consumeUInt32()
    #expect(value == 0x1234_5678)
  }

  @Test("FuzzDataProvider consumeUInt64")
  func testConsumeUInt64() {
    var provider = FuzzDataProvider(data: [
      0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01,
    ])

    let value = provider.consumeUInt64()
    #expect(value == 0x0123_4567_89AB_CDEF)
  }

  @Test("FuzzDataProvider consumeInt in range")
  func testConsumeIntInRange() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x05, count: 16))

    let value = provider.consumeInt(in: 0...100)
    #expect(value >= 0 && value <= 100)
  }

  @Test("FuzzDataProvider consumeProbability in [0, 1)")
  func testConsumeProbability() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x80, count: 8))

    let prob = provider.consumeProbability()
    #expect(prob >= 0.0 && prob < 1.0)
  }

  @Test("FuzzDataProvider consumeString")
  func testConsumeString() {
    var provider = FuzzDataProvider(data: [0x48, 0x69])  // "Hi"

    let str = provider.consumeString(length: 2)
    #expect(str == "Hi")
  }

  @Test("FuzzDataProvider consumeArray")
  func testConsumeArray() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x01, count: 100))

    let array = provider.consumeArray(maxCount: 5) { p in
      p.consumeByte()
    }

    #expect(array.count <= 5)
  }

  @Test("FuzzDataProvider pickElement")
  func testPickElement() {
    var provider = FuzzDataProvider(data: [0x02, 0, 0, 0, 0, 0, 0, 0])

    let element = provider.pickElement(from: ["a", "b", "c", "d"])
    #expect(element != nil)
  }

  // MARK: - FuzzableRNG Tests

  @Test("FuzzableRNG generates from provided bytes")
  func testFuzzableRNGGeneration() {
    var rng = FuzzableRNG(data: Array(repeating: 0x42, count: 8))

    let value = rng.next()
    #expect(value != 0)  // Should produce a deterministic value
  }

  @Test("FuzzableRNG is deterministic")
  func testFuzzableRNGDeterminism() {
    let data: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]

    var rng1 = FuzzableRNG(data: data)
    var rng2 = FuzzableRNG(data: data)

    #expect(rng1.next() == rng2.next())
    #expect(rng1.next() == rng2.next())
  }

  // MARK: - FuzzTarget Tests

  @Test("FuzzTarget creation")
  func testFuzzTargetCreation() {
    let target = FuzzTarget(
      name: "TestTarget",
      generator: Gen<Int>.int,
      property: { $0 >= Int.min }
    )

    #expect(target.name == "TestTarget")
  }

  @Test("FuzzTarget execution with passing property")
  func testFuzzTargetPass() {
    let target = FuzzTarget(
      generator: Gen<Int>.int,
      property: { _ in true }
    )

    let result = target.execute(data: Array(repeating: 0x42, count: 16))

    switch result {
    case .pass:
      break  // Expected
    default:
      Issue.record("Expected pass")
    }
  }

  @Test("FuzzTarget execution with failing property")
  func testFuzzTargetFail() {
    let target = FuzzTarget(
      generator: Gen<Int>.int,
      property: { _ in false }
    )

    let result = target.execute(data: Array(repeating: 0x42, count: 16))

    #expect(result.isFailure)
  }

  // MARK: - FuzzResult Tests

  @Test("FuzzResult pass case")
  func testFuzzResultPass() {
    let result = FuzzResult.pass

    #expect(!result.isFailure)
    #expect(result.description == "PASS")
  }

  @Test("FuzzResult fail case")
  func testFuzzResultFail() {
    let result = FuzzResult.fail(input: "test input")

    #expect(result.isFailure)
    #expect(result.description.contains("FAIL"))
    #expect(result.description.contains("test input"))
  }

  @Test("FuzzResult error case")
  func testFuzzResultError() {
    let result = FuzzResult.error(message: "some error")

    #expect(result.isFailure)
    #expect(result.description.contains("ERROR"))
  }

  // MARK: - FuzzStatistics Tests

  @Test("FuzzStatistics success rate calculation")
  func testFuzzStatisticsSuccessRate() {
    let stats = FuzzStatistics(
      executionCount: 100,
      passCount: 75,
      failCount: 25,
      lastFailure: nil
    )

    #expect(stats.successRate == 0.75)
  }

  @Test("FuzzStatistics zero execution handling")
  func testFuzzStatisticsZeroExecution() {
    let stats = FuzzStatistics(
      executionCount: 0,
      passCount: 0,
      failCount: 0,
      lastFailure: nil
    )

    #expect(stats.successRate == 0.0)
  }

  // MARK: - FuzzTestRunner Tests

  @Test("FuzzTestRunner initial state")
  func testFuzzTestRunnerInitialState() async {
    let runner = FuzzTestRunner()
    let stats = await runner.getStatistics()

    #expect(stats.executionCount == 0)
    #expect(stats.passCount == 0)
    #expect(stats.failCount == 0)
  }

  @Test("FuzzTestRunner target registration")
  func testFuzzTestRunnerRegistration() async {
    let runner = FuzzTestRunner()
    let target = FuzzTarget(
      name: "TestTarget",
      generator: Gen<Int>.int,
      property: { _ in true }
    )

    await runner.register(target)
    let result = await runner.execute(targetName: "TestTarget", data: [0x42])

    #expect(!result.isFailure)
  }

  @Test("FuzzTestRunner missing target")
  func testFuzzTestRunnerMissingTarget() async {
    let runner = FuzzTestRunner()
    let result = await runner.execute(targetName: "NonExistent", data: [])

    switch result {
    case .error(let message):
      #expect(message.contains("not found"))

    default:
      Issue.record("Expected error for missing target")
    }
  }

  // MARK: - FuzzBridge Tests

  @MainActor
  @Test("FuzzBridge with no target")
  func testFuzzBridgeNoTarget() {
    FuzzBridge.defaultTarget = nil

    let result = FuzzBridge.testOneInput([0x01, 0x02])
    #expect(result == true)  // Pass through when no target
  }

  @MainActor
  @Test("FuzzBridge with registered target")
  func testFuzzBridgeWithTarget() {
    let target = FuzzTarget(
      generator: Gen<Int>.int,
      property: { _ in true }
    )

    FuzzBridge.setDefaultTarget(target)

    let result = FuzzBridge.testOneInput(Array(repeating: 0x42, count: 16))
    #expect(result == true)

    // Cleanup
    FuzzBridge.defaultTarget = nil
  }

  // MARK: - Gen Extension Tests

  @Test("Gen.fuzz produces value from bytes")
  func testGenFuzz() {
    let data: [UInt8] = Array(repeating: 0x55, count: 32)
    let value = Gen<Int>.int.fuzz(with: data)

    // Value should be deterministic
    let value2 = Gen<Int>.int.fuzz(with: data)
    #expect(value == value2)
  }

  @Test("Gen.fuzzTarget creates valid target")
  func testGenFuzzTarget() {
    let target = Gen<Int>.int.fuzzTarget(name: "IntProperty") { _ in true }

    #expect(target.name == "IntProperty")
  }

  // MARK: - Property Extension Tests

  @Test("Property.fuzz executes with bytes")
  func testPropertyFuzz() {
    let property = Property<Int>(
      generator: Gen<Int>.int,
      predicate: { _ in true }
    )

    let result = property.fuzz(with: Array(repeating: 0x42, count: 16))
    #expect(result == true)
  }

  // MARK: - New FuzzDataProvider Tests

  @Test("FuzzDataProvider consumeAlphanumericString")
  func testConsumeAlphanumericString() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x05, count: 50))

    let str = provider.consumeAlphanumericString(maxLength: 10)
    #expect(str.count <= 10)
    #expect(str.allSatisfy { $0.isLetter || $0.isNumber })
  }

  @Test("FuzzDataProvider consumeCharacter")
  func testConsumeCharacter() {
    var provider = FuzzDataProvider(data: [65])  // 'A'

    let char = provider.consumeCharacter()
    #expect(char == "A")
  }

  @Test("FuzzDataProvider consumePrintableCharacter")
  func testConsumePrintableCharacter() {
    var provider = FuzzDataProvider(data: [0, 50, 100])

    for _ in 0..<3 {
      let char = provider.consumePrintableCharacter()
      #expect(char.asciiValue! >= 32 && char.asciiValue! <= 126)
    }
  }

  @Test("FuzzDataProvider consumeLetter")
  func testConsumeLetter() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x10, count: 10))

    for _ in 0..<5 {
      let letter = provider.consumeLetter()
      #expect(letter.isLetter)
    }
  }

  @Test("FuzzDataProvider consumeUInt")
  func testConsumeUInt() {
    var provider = FuzzDataProvider(data: Array(repeating: 0xFF, count: 8))

    let value = provider.consumeUInt()
    #expect(value > 0)
  }

  @Test("FuzzDataProvider consumeUInt in range")
  func testConsumeUIntInRange() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x10, count: 16))

    let value = provider.consumeUInt(in: 0...100)
    #expect(value >= 0 && value <= 100)
  }

  @Test("FuzzDataProvider consumeOptional returns nil or some")
  func testConsumeOptional() {
    // Data starting with 0 -> consumeBool() returns false -> nil
    var provider1 = FuzzDataProvider(data: [0, 42])
    let optNil: Int? = provider1.consumeOptional { $0.consumeInt() }
    #expect(optNil == nil)

    // Data starting with 1 -> consumeBool() returns true -> some
    var provider2 = FuzzDataProvider(data: [1] + Array(repeating: 0x42, count: 16))
    let optSome: Int? = provider2.consumeOptional { $0.consumeInt() }
    #expect(optSome != nil)
  }

  @Test("FuzzDataProvider consumeDictionary")
  func testConsumeDictionary() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x02, count: 100))

    let dict: [Int: String] = provider.consumeDictionary(
      maxCount: 5,
      consumingKey: { $0.consumeInt() },
      consumingValue: { $0.consumeString(length: 3) }
    )

    #expect(dict.count <= 5)
  }

  @Test("FuzzDataProvider consumeSet")
  func testConsumeSet() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x03, count: 100))

    let set: Set<Int> = provider.consumeSet(maxCount: 10) { $0.consumeInt() }

    #expect(set.count <= 10)
  }

  @Test("FuzzDataProvider consumeData")
  func testConsumeData() {
    var provider = FuzzDataProvider(data: [0x05, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5])

    let data = provider.consumeData(maxLength: 10)
    #expect(data.count <= 10)
  }

  @Test("FuzzDataProvider consumeUUID")
  func testConsumeUUID() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x42, count: 16))

    let uuid = provider.consumeUUID()
    #expect(uuid.uuidString.count == 36)  // UUID format: 8-4-4-4-12
  }

  @Test("FuzzDataProvider consumeDate")
  func testConsumeDate() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x80, count: 8))

    let from = Date(timeIntervalSince1970: 0)
    let to = Date(timeIntervalSince1970: 1_000_000)
    let date = provider.consumeDate(from: from, to: to)

    #expect(date >= from && date <= to)
  }

  @Test("FuzzDataProvider consumeRecentDate")
  func testConsumeRecentDate() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x50, count: 8))

    let date = provider.consumeRecentDate(withinYears: 5)
    let now = Date()
    let fiveYearsAgo = now.addingTimeInterval(-5 * 365.25 * 24 * 60 * 60)

    #expect(date >= fiveYearsAgo && date <= now)
  }

  @Test("FuzzDataProvider consumeEnumCase")
  func testConsumeEnumCase() {
    enum TestEnum: CaseIterable {
      case a, b, c
    }

    var provider = FuzzDataProvider(data: Array(repeating: 0x00, count: 8))

    let enumCase: TestEnum = provider.consumeEnumCase()
    #expect([TestEnum.a, .b, .c].contains(enumCase))
  }

  @Test("FuzzDataProvider consumeWeighted")
  func testConsumeWeighted() {
    var provider = FuzzDataProvider(data: Array(repeating: 0x00, count: 16))

    let options: [(weight: Int, value: String)] = [
      (weight: 10, value: "common"),
      (weight: 1, value: "rare"),
    ]

    let choice = provider.consumeWeighted(options)
    #expect(choice != nil)
    #expect(choice == "common" || choice == "rare")
  }

  @Test("FuzzDataProvider consumeWeighted empty options")
  func testConsumeWeightedEmpty() {
    var provider = FuzzDataProvider(data: [1, 2, 3])

    let options: [(weight: Int, value: Int)] = []
    let choice = provider.consumeWeighted(options)
    #expect(choice == nil)
  }
}
