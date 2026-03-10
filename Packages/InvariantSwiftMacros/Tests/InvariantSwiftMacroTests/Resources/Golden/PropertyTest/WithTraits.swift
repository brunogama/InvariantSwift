@PropertyTest(
  tags: [.invariantSwiftPropertyReplay],
  bugs: [Bug.bug(id: "PBT-123")],
  serialized: true,
  timeLimit: .minutes(1),
  enabledIf: true
)
func testTraits(value: Int) {
  value >= 0
}
