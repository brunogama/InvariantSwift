import Testing
@testable import InvariantSwiftCore

@Suite("InvariantSwiftCore Basic Tests")
struct InvariantSwiftCoreBasicTests {
  @Test("Gen can create values")
  func genBasicCreation() {
    let gen = Gen<Int>.pure(42)
    let seed = Seed(value: 12345)
    let value = gen.sample(size: Size(value: 10), seed: seed)
    #expect(value == 42)
  }
}
