@PropertyTest(iterations: 500, seed: 42)
func testWithConfig(x: Int, y: String) {
  x >= Int.min && y.isEmpty
}
