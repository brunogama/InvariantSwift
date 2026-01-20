// Benchmarks/GeneratorBenchmarks.swift
// Generator throughput benchmarks for InvariantSwift

import Benchmark
import InvariantCore

// MARK: - Configuration

private let benchmarkSeed = Seed(value: 42)
private let benchmarkSize = Size(value: 10)

// MARK: - Registration

func registerGeneratorBenchmarks() {
  // MARK: - Primitives

  benchmark("Gen.int") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    _ = Gen.int.generate(&rng, benchmarkSize)
  }

  benchmark("Gen.bool") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    _ = Gen.bool.generate(&rng, benchmarkSize)
  }

  benchmark("Gen.double") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    _ = Gen.double.generate(&rng, benchmarkSize)
  }

  // MARK: - Strings

  benchmark("Gen.string (default)") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    _ = Gen.string.generate(&rng, benchmarkSize)
  }

  benchmark("Gen.string (size 50)") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let largeSize = Size(value: 50)
    _ = Gen.string.generate(&rng, largeSize)
  }

  // MARK: - Collections

  benchmark("Gen.array(Gen.int)") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let gen = Gen<[Int]>.array(Gen.int)
    _ = gen.generate(&rng, benchmarkSize)
  }

  benchmark("Gen.array(Gen.int) size 100") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let largeSize = Size(value: 100)
    let gen = Gen<[Int]>.array(Gen.int)
    _ = gen.generate(&rng, largeSize)
  }

  benchmark("Gen.dictionary(Gen.string, Gen.int)") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let gen = Gen<[String: Int]>.dictionary(Gen.string, Gen.int)
    _ = gen.generate(&rng, benchmarkSize)
  }

  // MARK: - Combinators

  benchmark("Gen.int.map") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let gen = Gen.int.map { $0 * 2 }
    _ = gen.generate(&rng, benchmarkSize)
  }

  benchmark("Gen.int.flatMap") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let gen = Gen.int.flatMap { n in Gen.constant(n * 2) }
    _ = gen.generate(&rng, benchmarkSize)
  }

  benchmark("Gen.zip (2 generators)") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let gen = Gen<(Int, String)>.zip(Gen.int, Gen.string)
    _ = gen.generate(&rng, benchmarkSize)
  }

  benchmark("Gen.oneOf (3 options)") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let gen = Gen.oneOf([Gen.constant(1), Gen.constant(2), Gen.constant(3)])
    _ = gen.generate(&rng, benchmarkSize)
  }
}
