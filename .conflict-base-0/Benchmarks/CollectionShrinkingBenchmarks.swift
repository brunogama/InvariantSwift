import Benchmark
import InvariantSwift

let benchmarks = {
  Benchmark("Array shrinking - small (10 elements)") { benchmark in
    let gen = Gen.array(Gen<Int>.int(in: 0...100))
    let array = Array(0..<10)
    for _ in benchmark.scaledIterations {
      blackHole(gen.shrink.shrink(array))
    }
  }

  Benchmark("Array shrinking - medium (100 elements)") { benchmark in
    let gen = Gen.array(Gen<Int>.int(in: 0...100))
    let array = Array(0..<100)
    for _ in benchmark.scaledIterations {
      blackHole(gen.shrink.shrink(array))
    }
  }

  Benchmark("Array shrinking - large (1000 elements)") { benchmark in
    let gen = Gen.array(Gen<Int>.int(in: 0...100))
    let array = Array(0..<1000)
    for _ in benchmark.scaledIterations {
      blackHole(gen.shrink.shrink(array))
    }
  }

  Benchmark("Dictionary shrinking - small (10 pairs)") { benchmark in
    let gen = Gen.dictionary(Gen<String>.string, Gen<Int>.int(in: 0...100))
    let dict = Dictionary(uniqueKeysWithValues: (0..<10).map { ("\($0)", $0) })
    for _ in benchmark.scaledIterations {
      blackHole(gen.shrink.shrink(dict))
    }
  }

  Benchmark("Dictionary shrinking - medium (100 pairs)") { benchmark in
    let gen = Gen.dictionary(Gen<String>.string, Gen<Int>.int(in: 0...100))
    let dict = Dictionary(uniqueKeysWithValues: (0..<100).map { ("\($0)", $0) })
    for _ in benchmark.scaledIterations {
      blackHole(gen.shrink.shrink(dict))
    }
  }

  Benchmark("Shrink.removeElements - chunk removal") { benchmark in
    let array = Array(0..<100)
    for _ in benchmark.scaledIterations {
      blackHole(Shrink.removeElements(from: array))
    }
  }

  Benchmark("Shrink.shrinkElements - element shrinking") { benchmark in
    let shrinker: (Int) -> [Int] = { n in n > 0 ? [0, n / 2] : [] }
    let array = Array(0..<100)
    for _ in benchmark.scaledIterations {
      blackHole(Shrink.shrinkElements(in: array, using: shrinker))
    }
  }
}
