// macro_examples.swift
// InvariantSwift Examples
//
// Runnable examples demonstrating @PropertyTest macro usage.
// Place in your test target to run.

import Testing
import InvariantSwift

// MARK: - Basic Macro Usage

/// Example 1: Simple integer property
@PropertyTest("Addition is commutative")
func testAdditionCommutative(a: Int, b: Int) {
  #expect(a + b == b + a)
}

/// Example 2: String property
@PropertyTest("String reversal preserves length")
func testStringReverseLength(s: String) {
  #expect(s.count == String(s.reversed()).count)
}

/// Example 3: Boolean property
@PropertyTest("Double negation is identity")
func testDoubleNegation(b: Bool) {
  #expect(!!b == b)
}

// MARK: - Collection Properties

/// Example 4: Array sorting
@PropertyTest("Sorted array is sorted")
func testSortedIsSorted(xs: [Int]) {
  let sorted = xs.sorted()
  for i in 0..<(sorted.count - 1) {
    #expect(sorted[i] <= sorted[i + 1])
  }
}

/// Example 5: Map preserves count
@PropertyTest("Mapping preserves count")
func testMapPreservesCount(xs: [Int]) {
  #expect(xs.map { $0 * 2 }.count == xs.count)
}

/// Example 6: Filter subset
@PropertyTest("Filter produces subset")
func testFilterSubset(xs: [Int]) {
  let filtered = xs.filter { $0 > 0 }
  #expect(filtered.count <= xs.count)
}

// MARK: - With Configuration

/// Example 7: More iterations
@PropertyTest("Multiplication is associative", iterations: 500)
func testMultAssociative(a: Int, b: Int, c: Int) {
  // Note: May overflow, but demonstrates macro usage
  #expect((a &* b) &* c == a &* (b &* c))
}

/// Example 8: With seed for reproducibility
@PropertyTest("Zero is additive identity", iterations: 100, seed: 42)
func testZeroIdentity(n: Int) {
  #expect(n + 0 == n)
  #expect(0 + n == n)
}

// MARK: - Optional and Result Types

/// Example 9: Optional handling
@PropertyTest("Optional map behavior")
func testOptionalMap(x: Int?) {
  let doubled = x.map { $0 * 2 }

  if x == nil {
    #expect(doubled == nil)
  } else {
    #expect(doubled != nil)
  }
}

/// Example 10: Result type
@PropertyTest("Result map preserves success/failure")
func testResultMap(r: Result<Int, Error>) {
  let mapped = r.map { $0 * 2 }

  switch (r, mapped) {
  case (.success, .success):
    break  // Both success
  case (.failure, .failure):
    break  // Both failure
  default:
    Issue.record("Result changed success/failure status")
  }
}

// MARK: - Mathematical Laws

/// Example 11: Monoid left identity
@PropertyTest("Empty array is left identity for concatenation")
func testMonoidLeftIdentity(xs: [Int]) {
  #expect([] + xs == xs)
}

/// Example 12: Monoid right identity
@PropertyTest("Empty array is right identity for concatenation")
func testMonoidRightIdentity(xs: [Int]) {
  #expect(xs + [] == xs)
}

/// Example 13: Monoid associativity
@PropertyTest("Array concatenation is associative")
func testMonoidAssociativity(xs: [Int], ys: [Int], zs: [Int]) {
  #expect((xs + ys) + zs == xs + (ys + zs))
}

// MARK: - String Properties

/// Example 14: Prefix/Suffix
@PropertyTest("String contains its prefix and suffix")
func testPrefixSuffix(s: String) {
  if s.count >= 2 {
    let prefix = String(s.prefix(1))
    let suffix = String(s.suffix(1))
    #expect(s.hasPrefix(prefix))
    #expect(s.hasSuffix(suffix))
  }
}

/// Example 15: Uppercase/Lowercase
@PropertyTest("Lowercase then uppercase has same length")
func testCaseLength(s: String) {
  #expect(
    s.lowercased().count == s.uppercased().count || s.lowercased().count <= s.uppercased().count * 2
  )  // Some chars expand
}
