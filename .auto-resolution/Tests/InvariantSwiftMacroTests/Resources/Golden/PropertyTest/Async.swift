@PropertyTest
func testAsync(value: Int) async -> Bool {
  await someAsyncCheck(value)
}
