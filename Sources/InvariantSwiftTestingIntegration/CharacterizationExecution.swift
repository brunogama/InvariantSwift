struct CharacterizationExecutionRequest<Input, Output, Observation>: Sendable
where
  Input: Codable & Sendable,
  Output: Sendable,
  Observation: Codable & Sendable
{
  let configuration: CharacterizationConfiguration<Input>
  let observe: @Sendable (Output) throws -> Observation
  let observeError: (@Sendable (any Error) throws -> CharacterizationError)?
  let operation: @Sendable (Input) async throws -> Output
}

struct CharacterizationExecution: Sendable {
  static func run<Input, Output, Observation>(
    _ request: CharacterizationExecutionRequest<Input, Output, Observation>
  ) async throws -> CharacterizationReport
  where
    Input: Codable & Sendable,
    Output: Sendable,
    Observation: Codable & Sendable
  {
    try await run(
      request,
      modeSelector: EnvironmentCharacterizationModeSelector(),
      fixtures: FileSystemSnapshotTestingFixtures(
        configuration: request.configuration
      ),
      reporter: SwiftTestingDifferenceReporter()
    )
  }

  static func run<Input, Output, Observation>(
    _ request: CharacterizationExecutionRequest<Input, Output, Observation>,
    modeSelector: some CharacterizationModeSelecting,
    fixtures: some CharacterizationFixtures,
    reporter: some CharacterizationDifferenceReporting
  ) async throws -> CharacterizationReport
  where
    Input: Codable & Sendable,
    Output: Sendable,
    Observation: Codable & Sendable
  {
    let mode = modeSelector.select(explicitMode: request.configuration.mode)
    let recordedCases: [CharacterizationCase<Input, Observation>] =
      mode == .verify ? try fixtures.load() : []
    let inputs = try replayInputs(
      recordedCases,
      configuration: request.configuration,
      mode: mode
    )
    try validateCaseIDs(inputs)
    let cases = try await executeCases(
      inputs,
      request: request
    )
    try prepareRecordingIfNeeded(cases, fixtures: fixtures, mode: mode)
    let differences = fixtures.verify(cases, mode: mode)
    reporter.record(name: request.configuration.name, differences: differences)
    return makeReport(mode, caseCount: cases.count, differences: differences)
  }
}

protocol CharacterizationModeSelecting: Sendable {
  func select(explicitMode: CharacterizationMode?) -> CharacterizationMode
}

struct EnvironmentCharacterizationModeSelector: CharacterizationModeSelecting {
  func select(explicitMode: CharacterizationMode?) -> CharacterizationMode {
    explicitMode ?? CharacterizationMode.fromEnvironment
  }
}

struct FixedCharacterizationModeSelector: CharacterizationModeSelecting {
  let mode: CharacterizationMode

  func select(explicitMode: CharacterizationMode?) -> CharacterizationMode {
    explicitMode ?? mode
  }
}

private func makeReport(
  _ mode: CharacterizationMode,
  caseCount: Int,
  differences: [CharacterizationDifference]
) -> CharacterizationReport {
  CharacterizationReport(
    mode: mode,
    caseCount: caseCount,
    differences: differences
  )
}

private func prepareRecordingIfNeeded<Input, Observation>(
  _ cases: [CharacterizationCase<Input, Observation>],
  fixtures: some CharacterizationFixtures,
  mode: CharacterizationMode
)
  throws where Input: Codable & Sendable, Observation: Codable & Sendable
{
  guard mode == .record else { return }
  try preflightEncoding(cases)
  try fixtures.prepareForRecording()
}

private func replayInputs<Input, Observation>(
  _ recordedCases: [CharacterizationCase<Input, Observation>],
  configuration: CharacterizationConfiguration<Input>,
  mode: CharacterizationMode
) throws -> [CharacterizationInput<Input>]
where
  Input: Codable & Sendable,
  Observation: Codable & Sendable
{
  if mode == .record || recordedCases.isEmpty && !configuration.inputs.isEmpty {
    return configuration.inputs
  }
  guard !recordedCases.isEmpty else {
    throw CharacterizationTestingError.fixtureMissing(configuration.fixture)
  }
  return recordedCases.map { CharacterizationInput(id: $0.id, value: $0.input) }
}

private func validateCaseIDs<Input>(
  _ inputs: [CharacterizationInput<Input>]
)
  throws where Input: Codable & Sendable
{
  var knownIDs = Set<String>()
  var knownSnapshotIDs: [String: String] = [:]

  for input in inputs {
    try validateCaseID(
      input.id,
      knownIDs: &knownIDs,
      knownSnapshotIDs: &knownSnapshotIDs
    )
  }
}

private func validateCaseID(
  _ id: String,
  knownIDs: inout Set<String>,
  knownSnapshotIDs: inout [String: String]
) throws {
  guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    throw CharacterizationTestingError.invalidCaseID(id)
  }
  guard knownIDs.insert(id).inserted else {
    throw CharacterizationTestingError.duplicateCaseID(id)
  }

  let snapshotID = snapshotIdentifier(id)
  if let existingID = knownSnapshotIDs[snapshotID] {
    throw CharacterizationTestingError.collidingSnapshotIDs(existingID, id)
  }
  knownSnapshotIDs[snapshotID] = id
}

private func executeCases<Input, Output, Observation>(
  _ inputs: [CharacterizationInput<Input>],
  request: CharacterizationExecutionRequest<Input, Output, Observation>
) async throws -> [CharacterizationCase<Input, Observation>]
where
  Input: Codable & Sendable,
  Output: Sendable,
  Observation: Codable & Sendable
{
  var cases: [CharacterizationCase<Input, Observation>] = []
  cases.reserveCapacity(inputs.count)
  for input in inputs {
    let outcome = try await runOperation(
      input.value,
      request: request
    )
    cases.append(
      CharacterizationCase(
        id: input.id,
        input: input.value,
        expected: outcome
      )
    )
  }
  return cases
}

private func runOperation<Input, Output, Observation>(
  _ input: Input,
  request: CharacterizationExecutionRequest<Input, Output, Observation>
) async throws -> CharacterizationOutcome<Observation>
where Input: Sendable, Output: Sendable, Observation: Codable & Sendable {
  let output: Output
  do {
    output = try await request.operation(input)
  } catch {
    let projectedError =
      try request.observeError?(error)
      ?? CharacterizationError(error: error)
    return .threw(projectedError)
  }
  return .returned(try request.observe(output))
}
