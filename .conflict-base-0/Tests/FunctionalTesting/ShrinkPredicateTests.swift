// ShrinkPredicateTests.swift
// InvariantSwift Tests
//
// Tests for the ShrinkPredicates system.

import Testing
import Foundation
@testable import InvariantSwift

@Suite("ShrinkPredicate Tests")
struct ShrinkPredicateTests {

  // MARK: - Basic Predicate Tests

  @Test("All predicate accepts everything")
  func testAllPredicate() {
    let predicate = ShrinkPredicate<Int>.all

    #expect(predicate.validate(original: 100, candidate: 0))
    #expect(predicate.validate(original: 100, candidate: 100))
    #expect(predicate.validate(original: 100, candidate: -100))
  }

  @Test("None predicate rejects everything")
  func testNonePredicate() {
    let predicate = ShrinkPredicate<Int>.none

    #expect(!predicate.validate(original: 100, candidate: 0))
    #expect(!predicate.validate(original: 100, candidate: 100))
  }

  @Test("NotEqual predicate")
  func testNotEqualPredicate() {
    let predicate = ShrinkPredicate<Int>.notEqual

    #expect(predicate.validate(original: 100, candidate: 50))
    #expect(!predicate.validate(original: 100, candidate: 100))
  }

  // MARK: - Numeric Predicates

  @Test("Smaller predicate")
  func testSmallerPredicate() {
    let predicate = ShrinkPredicate<Int>.smaller

    #expect(predicate.validate(original: 100, candidate: 50))
    #expect(predicate.validate(original: 100, candidate: 0))
    #expect(!predicate.validate(original: 100, candidate: 100))
    #expect(!predicate.validate(original: 100, candidate: 150))
  }

  @Test("InBounds predicate")
  func testInBoundsPredicate() {
    let predicate = ShrinkPredicate<Int>.inBounds(0...50)

    #expect(predicate.validate(original: 100, candidate: 0))
    #expect(predicate.validate(original: 100, candidate: 25))
    #expect(predicate.validate(original: 100, candidate: 50))
    #expect(!predicate.validate(original: 100, candidate: -1))
    #expect(!predicate.validate(original: 100, candidate: 51))
  }

  @Test("PreserveSign predicate")
  func testPreserveSignPredicate() {
    let predicate = ShrinkPredicate<Int>.preserveSign

    #expect(predicate.validate(original: 100, candidate: 50))
    #expect(predicate.validate(original: 100, candidate: 0))
    #expect(!predicate.validate(original: 100, candidate: -1))

    #expect(predicate.validate(original: -100, candidate: -50))
    #expect(!predicate.validate(original: -100, candidate: 50))
  }

  // MARK: - Collection Predicates

  @Test("NonEmpty predicate for arrays")
  func testNonEmptyPredicate() {
    let predicate = ShrinkPredicate<[Int]>.nonEmpty

    #expect(predicate.validate(original: [1, 2, 3], candidate: [1]))
    #expect(!predicate.validate(original: [1, 2, 3], candidate: []))
  }

  @Test("MaxReduction predicate")
  func testMaxReductionPredicate() {
    let predicate = ShrinkPredicate<[Int]>.maxReduction(2)

    #expect(predicate.validate(original: [1, 2, 3, 4, 5], candidate: [1, 2, 3]))  // Remove 2
    #expect(predicate.validate(original: [1, 2, 3, 4, 5], candidate: [1, 2, 3, 4]))  // Remove 1
    #expect(!predicate.validate(original: [1, 2, 3, 4, 5], candidate: [1, 2]))  // Remove 3
  }

  @Test("MinLength predicate")
  func testMinLengthPredicate() {
    let predicate = ShrinkPredicate<[Int]>.minLength(2)

    #expect(predicate.validate(original: [1, 2, 3], candidate: [1, 2]))
    #expect(!predicate.validate(original: [1, 2, 3], candidate: [1]))
  }

  // MARK: - String Predicates

  @Test("NonEmptyString predicate")
  func testNonEmptyStringPredicate() {
    let predicate = ShrinkPredicate<String>.nonEmptyString

    #expect(predicate.validate(original: "hello", candidate: "h"))
    #expect(!predicate.validate(original: "hello", candidate: ""))
  }

  @Test("PreservePrefix predicate")
  func testPreservePrefixPredicate() {
    let predicate = ShrinkPredicate<String>.preservePrefix("test_")

    #expect(predicate.validate(original: "test_hello", candidate: "test_h"))
    #expect(!predicate.validate(original: "test_hello", candidate: "hello"))
  }

  @Test("PreserveSuffix predicate")
  func testPreserveSuffixPredicate() {
    let predicate = ShrinkPredicate<String>.preserveSuffix(".txt")

    #expect(predicate.validate(original: "file.txt", candidate: "f.txt"))
    #expect(!predicate.validate(original: "file.txt", candidate: "file"))
  }

  // MARK: - Combinator Tests

  @Test("And combinator")
  func testAndCombinator() {
    let positive = ShrinkPredicate<Int> { _, c in c >= 0 }
    let small = ShrinkPredicate<Int> { _, c in c <= 10 }
    let combined = positive.and(small)

    #expect(combined.validate(original: 100, candidate: 5))
    #expect(!combined.validate(original: 100, candidate: -5))
    #expect(!combined.validate(original: 100, candidate: 15))
  }

  @Test("Or combinator")
  func testOrCombinator() {
    let zero = ShrinkPredicate<Int> { _, c in c == 0 }
    let ten = ShrinkPredicate<Int> { _, c in c == 10 }
    let combined = zero.or(ten)

    #expect(combined.validate(original: 100, candidate: 0))
    #expect(combined.validate(original: 100, candidate: 10))
    #expect(!combined.validate(original: 100, candidate: 5))
  }

  @Test("Not combinator")
  func testNotCombinator() {
    let positive = ShrinkPredicate<Int> { _, c in c >= 0 }
    let negative = positive.not

    #expect(!negative.validate(original: 100, candidate: 0))
    #expect(negative.validate(original: 100, candidate: -1))
  }

  // MARK: - Field Preservation Tests

  @Test("PreserveField predicate")
  func testPreserveFieldPredicate() {
    struct User: Sendable {
      let id: Int
      let name: String
    }

    let predicate = preserveField(\User.id)

    let original = User(id: 1, name: "Alice")
    #expect(predicate.validate(original: original, candidate: User(id: 1, name: "A")))
    #expect(!predicate.validate(original: original, candidate: User(id: 2, name: "Alice")))
  }
}
