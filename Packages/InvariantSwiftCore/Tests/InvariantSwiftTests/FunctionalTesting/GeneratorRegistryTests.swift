// GeneratorRegistryTests.swift
// InvariantSwift Tests
//
// Tests for the GeneratorRegistry actor.

import Testing
import Foundation
@testable import InvariantSwift
@testable import InvariantSwiftAdvanced

// MARK: - Test Types

private struct TestUser: Equatable, Sendable {
  let id: Int
  let name: String
}

private struct TestConfig: Equatable, Sendable {
  let debug: Bool
  let timeout: Int
}

// MARK: - Generator Registry Tests

@Suite("GeneratorRegistry Tests")
struct GeneratorRegistryTests {

  // MARK: - Registration Tests

  @Test("Register and lookup generator")
  func testRegisterAndLookup() async {
    let registry = GeneratorRegistry()

    let userGen = Gen<TestUser> { rng, _ in
      TestUser(
        id: Int.random(in: 1...1000, using: &rng),
        name: "User\(Int.random(in: 1...100, using: &rng))"
      )
    }

    await registry.register(for: TestUser.self, generator: userGen)

    let lookedUp: Gen<TestUser>? = await registry.lookup(for: TestUser.self)
    #expect(lookedUp != nil)

    // Verify the generator works
    if let gen = lookedUp {
      let user = gen.sample(size: .medium, seed: .random)
      #expect(user.id >= 1 && user.id <= 1000)
    }
  }

  @Test("Lookup returns nil for unregistered type")
  func testLookupUnregistered() async {
    let registry = GeneratorRegistry()

    let result: Gen<TestUser>? = await registry.lookup(for: TestUser.self)
    #expect(result == nil)
  }

  @Test("Deregister removes generator")
  func testDeregister() async {
    let registry = GeneratorRegistry()

    let userGen = Gen<TestUser> { _, _ in
      TestUser(id: 1, name: "Test")
    }

    await registry.register(for: TestUser.self, generator: userGen)
    #expect(await registry.isRegistered(for: TestUser.self) == true)

    await registry.deregister(for: TestUser.self)
    #expect(await registry.isRegistered(for: TestUser.self) == false)
  }

  // MARK: - Scope Tests

  @Test("Test-local scope overrides global")
  func testScopeOverride() async {
    let registry = GeneratorRegistry()
    let testScope = RegistryScope.testLocal()

    // Register global generator
    let globalGen = Gen<TestUser> { _, _ in
      TestUser(id: 999, name: "Global")
    }
    await registry.register(for: TestUser.self, generator: globalGen, scope: .global)

    // Register test-local generator
    let localGen = Gen<TestUser> { _, _ in
      TestUser(id: 1, name: "Local")
    }
    await registry.register(for: TestUser.self, generator: localGen, scope: testScope)

    // Push test scope
    await registry.pushScope(testScope)

    // Lookup should return local
    let lookedUp: Gen<TestUser>? = await registry.lookup(for: TestUser.self)
    #expect(lookedUp != nil)

    if let gen = lookedUp {
      let user = gen.sample(size: .medium, seed: .random)
      #expect(user.name == "Local")
    }

    // Pop scope
    await registry.popScope()

    // Lookup should return global
    let globalLookedUp: Gen<TestUser>? = await registry.lookup(for: TestUser.self)
    if let gen = globalLookedUp {
      let user = gen.sample(size: .medium, seed: .random)
      #expect(user.name == "Global")
    }
  }

  @Test("withScope automatically manages scope")
  func testWithScope() async {
    let registry = GeneratorRegistry()
    let testScope = RegistryScope.testLocal()

    let localGen = Gen<TestConfig> { _, _ in
      TestConfig(debug: true, timeout: 1)
    }
    await registry.register(for: TestConfig.self, generator: localGen, scope: testScope)

    let result = await registry.withScope(testScope) {
      let gen: Gen<TestConfig>? = await registry.lookup(for: TestConfig.self)
      return gen?.sample(size: .medium, seed: .random)
    }

    #expect(result != nil)
    #expect(result?.debug == true)
  }

  // MARK: - Multiple Types Tests

  @Test("Register multiple types")
  func testMultipleTypes() async {
    let registry = GeneratorRegistry()

    let userGen = Gen<TestUser> { _, _ in TestUser(id: 1, name: "Test") }
    let configGen = Gen<TestConfig> { _, _ in TestConfig(debug: false, timeout: 30) }

    await registry.register(for: TestUser.self, generator: userGen)
    await registry.register(for: TestConfig.self, generator: configGen)

    #expect(await registry.registrationCount == 2)

    let userLookup: Gen<TestUser>? = await registry.lookup(for: TestUser.self)
    let configLookup: Gen<TestConfig>? = await registry.lookup(for: TestConfig.self)

    #expect(userLookup != nil)
    #expect(configLookup != nil)
  }

  // MARK: - Clear Tests

  @Test("Clear all registrations")
  func testClearAll() async {
    let registry = GeneratorRegistry()

    let userGen = Gen<TestUser> { _, _ in TestUser(id: 1, name: "Test") }
    let configGen = Gen<TestConfig> { _, _ in TestConfig(debug: false, timeout: 30) }

    await registry.register(for: TestUser.self, generator: userGen)
    await registry.register(for: TestConfig.self, generator: configGen)

    #expect(await registry.registrationCount == 2)

    await registry.clearAll()

    #expect(await registry.registrationCount == 0)
  }

  @Test("Clear specific scope")
  func testClearScope() async {
    let registry = GeneratorRegistry()
    let testScope = RegistryScope.testLocal()

    let globalGen = Gen<TestUser> { _, _ in TestUser(id: 1, name: "Global") }
    let localGen = Gen<TestUser> { _, _ in TestUser(id: 2, name: "Local") }

    await registry.register(for: TestUser.self, generator: globalGen, scope: .global)
    await registry.register(for: TestUser.self, generator: localGen, scope: testScope)

    await registry.clearAll(scope: testScope)

    // Global should still exist
    #expect(await registry.isRegistered(for: TestUser.self, scope: .global) == true)
    #expect(await registry.isRegistered(for: TestUser.self, scope: testScope) == false)
  }

  // MARK: - Gen Extension Tests

  @Test("Gen convenience register and lookup")
  func testGenConvenienceExtensions() async {
    let userGen = Gen<TestUser> { _, _ in TestUser(id: 42, name: "Convenience") }

    await userGen.register()

    let lookedUp = await Gen<TestUser>.fromRegistry()
    #expect(lookedUp != nil)

    if let gen = lookedUp {
      let user = gen.sample(size: .medium, seed: .random)
      #expect(user.id == 42)
    }

    // Cleanup
    await GeneratorRegistry.shared.clearAll()
  }

  // MARK: - Thread Safety Tests

  @Test("Concurrent registrations are thread-safe")
  func testConcurrentRegistrations() async {
    let registry = GeneratorRegistry()

    await withTaskGroup(of: Void.self) { group in
      for idx in 0..<100 {
        group.addTask {
          let gen = Gen<Int> { _, _ in idx }
          await registry.register(for: Int.self, generator: gen)
        }
      }
    }

    // Should have at least one registration
    let result: Gen<Int>? = await registry.lookup(for: Int.self)
    #expect(result != nil)
  }
}
