@PropertyTest
func testUserValidation(
  @Label("User's Age") age: Int,
  @Label("Account Balance") balance: Double
) {
  age >= 0 && balance >= 0.0
}
