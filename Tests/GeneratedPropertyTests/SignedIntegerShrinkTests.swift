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

  @Test("Shrinking Int.min repeatedly reaches zero without trapping")
  func intMinShrinksAllTheWayDown() {
    // The shrinker drives a search loop, so it is applied to its own output
    // until a minimum is reached; that walk must stay total.
    var current = Int.min
    var steps = 0
    while current != 0, steps < 100 {
      guard let next = Gen<Int>.int.shrink.shrink(current).last else { break }
      current = next
      steps += 1
    }
    #expect(steps < 100)
  }
}
