// Benchmarks/main.swift
// InvariantSwift Performance Benchmark Suite
//
// Run with: swift run -c release Benchmarks
// JSON output: swift run -c release Benchmarks --format json

import Benchmark

// Register all benchmark suites
registerGeneratorBenchmarks()
registerShrinkBenchmarks()
registerReplayBenchmarks()

// Run the benchmark suite
Benchmark.main()
