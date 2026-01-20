@PropertyTest
func testWithCustomGen(@Gen(.int(in: 1...100)) positiveNumber: Int) {
  positiveNumber > 0
}
