@PropertyTest("Complex test")
func testComplex(
  @Gen(.int(in: 0...10)) count: Int,
  @Label("User name") name: String
) {
  count >= 0
}
