@PropertyTest
func testWithMultipleGen(
  @Gen(.int(in: 0...10)) small: Int,
  @Gen(.string(length: 5...10)) mediumString: String
) {
  small >= 0 && mediumString.count >= 5
}
