import InvariantSwiftCore
import Testing

/// Regression tests for shrinking the minimum value of each signed integer type.
///
/// Every signed generator emits `T.min` as an edge case, so its shrinker must
/// accept `T.min`. Testing `abs(n) > 1` there traps, because `-T.min` is not
/// representable, which kills the whole test process with SIGTRAP.
@Suite("Signed Integer Shrink Tests")
struct SignedIntegerShrinkTests {

  @Test("Int shrinker accepts Int.min")
  func intShrinksMinimum() {
    let shrunk = Gen<Int>.int.shrink.shrink(Int.min)
    #expect(shrunk.contains(0))
    #expect(shrunk.contains(Int.min / 2))
  }

  @Test("Int8 shrinker accepts Int8.min")
  func int8ShrinksMinimum() {
    let shrunk = Gen<Int8>.int8.shrink.shrink(Int8.min)
    #expect(shrunk.contains(0))
    #expect(shrunk.contains(Int8.min / 2))
  }

  @Test("Int16 shrinker accepts Int16.min")
  func int16ShrinksMinimum() {
    let shrunk = Gen<Int16>.int16.shrink.shrink(Int16.min)
    #expect(shrunk.contains(0))
    #expect(shrunk.contains(Int16.min / 2))
  }

  @Test("Int32 shrinker accepts Int32.min")
  func int32ShrinksMinimum() {
    let shrunk = Gen<Int32>.int32.shrink.shrink(Int32.min)
    #expect(shrunk.contains(0))
    #expect(shrunk.contains(Int32.min / 2))
  }

  @Test("Int64 shrinker accepts Int64.min")
  func int64ShrinksMinimum() {
    let shrunk = Gen<Int64>.int64.shrink.shrink(Int64.min)
    #expect(shrunk.contains(0))
    #expect(shrunk.contains(Int64.min / 2))
  }

  @Test("Halving walk from Int.min reaches zero without trapping")
  func intMinShrinksAllTheWayDown() {
    // The shrink search applies the shrinker to its own output, so every value
    // along the walk must be one the shrinker survives, not just Int.min.
    // Follow the halving candidate: it is the one that actually converges.
    var current = Int.min
    var steps = 0
    while current != 0, steps < 200 {
      let candidates = Gen<Int>.int.shrink.shrink(current)
      guard let next = candidates.count > 1 ? candidates[1] : candidates.first else { break }
      current = next
      steps += 1
    }
    #expect(current == 0)
    #expect(steps < 200)
  }

  @Test("Shrink candidates are ordered most aggressive first, deterministically")
  func shrinkCandidateOrderIsStable() {
    // Shrinkers deduplicate their candidates, and that must keep the order
    // they were built in: the shrink search walks them in order, and a
    // recorded shrink path only replays if the order is reproducible.
    let shrunk = Gen<Int>.int.shrink.shrink(-4096)
    #expect(shrunk.first == 0)
    #expect(shrunk == Gen<Int>.int.shrink.shrink(-4096))
  }
}
