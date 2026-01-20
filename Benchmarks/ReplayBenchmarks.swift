// Benchmarks/ReplayBenchmarks.swift
// Replay and reproduction overhead benchmarks for InvariantSwift

import Benchmark
import InvariantCore

// MARK: - Configuration

private let benchmarkSeed = Seed(value: 42)
private let benchmarkSize = Size(value: 10)

// MARK: - Registration

func registerReplayBenchmarks() {
  registerSeedBenchmarks()
  registerTokenBenchmarks()
  registerRegressionBankBenchmarks()
}

// MARK: - Fixed Seed Benchmarks

private func registerSeedBenchmarks() {
  benchmark("Replay: fixed seed sequence (100 values)") {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
    let gen = Gen<[Int]>.array(Gen.int)
    for _ in 0..<100 {
      _ = gen.generate(&rng, benchmarkSize)
    }
  }

  benchmark("Replay: seed reset overhead") {
    for _ in 0..<100 {
      var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
      _ = Gen.int.generate(&rng, benchmarkSize)
    }
  }
}

// MARK: - Token Benchmarks

private func registerTokenBenchmarks() {
  benchmark("Replay: token creation") {
    let token = ReplayToken(
      seed: 42,
      iterations: 100,
      size: 10,
      maxDiscarded: 1000,
      counterexample: "123"
    )
    _ = token
  }

  benchmark("Replay: property with fixed seed") {
    let property = Property<Int>(generator: Gen.int) { n in
      n != 0
    }
    let config = PropertyConfig(
      iterations: 100,
      seed: benchmarkSeed
    )
    _ = runPropertySynchronously(property, config: config)
  }
}

// MARK: - Regression Bank Benchmarks

private func registerRegressionBankBenchmarks() {
  benchmark("Replay: regression bank (10 seeds)") {
    let seeds: [UInt64] = [42, 123, 456, 789, 1011, 1213, 1415, 1617, 1819, 2021]
    for seedValue in seeds {
      var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
        seed: Seed(value: seedValue)
      )
      let gen = Gen<[Int]>.array(Gen.int)
      _ = gen.generate(&rng, benchmarkSize)
    }
  }

  benchmark("Replay: regression bank (50 seeds)") {
    for seedValue: UInt64 in 1...50 {
      var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
        seed: Seed(value: seedValue)
      )
      let gen = Gen<[Int]>.array(Gen.int)
      _ = gen.generate(&rng, benchmarkSize)
    }
  }

  benchmark("Replay: determinism check (same seed, 50 runs)") {
    let gen = Gen<[Int]>.array(Gen.int)
    var results: [[Int]] = []
    for _ in 0..<50 {
      var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: benchmarkSeed)
      results.append(gen.generate(&rng, benchmarkSize))
    }
    let first = results.first!
    let allSame = results.allSatisfy { $0 == first }
    _ = allSame
  }
}
