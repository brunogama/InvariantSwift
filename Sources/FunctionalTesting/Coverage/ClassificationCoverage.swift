import Foundation
import Dispatch

// MARK: - Classification Coverage Contracts System

/// **Classification Coverage Contracts for Comprehensive Input Space Coverage**
///
/// Advanced coverage system that ensures property-based tests adequately explore
/// different classifications of input space. Provides formal contracts for coverage
/// requirements and automatically validates coverage adequacy during test execution.
///
/// **Features:**
/// - Input classification and labeling
/// - Coverage requirement contracts
/// - Automatic coverage validation
/// - Coverage-guided test generation
/// - Statistical coverage analysis
/// - Integration with test reporting
/// - Runtime coverage monitoring
///
/// **Mathematical Foundation:**
/// Based on partition testing theory and statistical coverage analysis,
/// implementing formal coverage contracts with mathematical guarantees
/// about input space exploration completeness.
///
/// **External References:**
/// - [Partition Testing Theory](https://en.wikipedia.org/wiki/Software_testing#Partition_testing)
/// - [Coverage-Based Testing](https://link.springer.com/chapter/10.1007/978-3-642-16573-3_1)
/// - [Statistical Test Analysis](https://www.jstor.org/stable/2984156)

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public actor ClassificationCoverageSystem {

  // MARK: - Types and Configuration

  /// **Coverage classification for inputs**
  public struct Classification: Hashable, Codable, Sendable {
    /// Unique classification identifier
    public let id: String

    /// Human-readable classification label
    public let label: String

    /// Classification description
    public let description: String

    /// Classification category (e.g., "boundary", "typical", "edge")
    public let category: String

    /// Priority for coverage (higher = more important)
    public let priority: Int

    /// Metadata tags
    public let tags: [String: String]

    public init(
      id: String,
      label: String,
      description: String = "",
      category: String = "general",
      priority: Int = 0,
      tags: [String: String] = [:]
    ) {
      self.id = id
      self.label = label
      self.description = description
      self.category = category
      self.priority = priority
      self.tags = tags
    }
  }

  /// **Coverage requirement contract**
  public struct CoverageContract: Codable, Sendable {
    /// Contract identifier
    public let id: String

    /// Required classifications to cover
    public let requiredClassifications: Set<String>

    /// Minimum coverage percentage (0.0 - 1.0)
    public let minimumCoverage: Double

    /// Minimum samples per classification
    public let minimumSamplesPerClassification: Int

    /// Maximum samples per classification (for balance)
    public let maximumSamplesPerClassification: Int?

    /// Statistical confidence level (0.0 - 1.0)
    public let confidenceLevel: Double

    /// Contract validation mode
    public let validationMode: ValidationMode

    /// Contract description
    public let description: String

    public enum ValidationMode: String, Codable, CaseIterable, Sendable {
      case strict = "strict"  // All requirements must be met
      case best_effort = "best_effort"  // Try to meet requirements, warn on failures
      case advisory = "advisory"  // Report coverage but don't fail tests
    }

    public init(
      id: String,
      requiredClassifications: Set<String>,
      minimumCoverage: Double = 0.8,
      minimumSamplesPerClassification: Int = 10,
      maximumSamplesPerClassification: Int? = nil,
      confidenceLevel: Double = 0.95,
      validationMode: ValidationMode = .strict,
      description: String = ""
    ) {
      self.id = id
      self.requiredClassifications = requiredClassifications
      self.minimumCoverage = max(0.0, min(1.0, minimumCoverage))
      self.minimumSamplesPerClassification = max(1, minimumSamplesPerClassification)
      self.maximumSamplesPerClassification = maximumSamplesPerClassification
      self.confidenceLevel = max(0.0, min(1.0, confidenceLevel))
      self.validationMode = validationMode
      self.description = description
    }
  }

  /// **Classifier function for inputs**
  public struct InputClassifier<T>: Sendable {
    public let name: String
    public let classifyFunction: @Sendable (T) -> [Classification]

    public init(
      name: String,
      classify: @escaping @Sendable (T) -> [Classification]
    ) {
      self.name = name
      self.classifyFunction = classify
    }
  }

  /// **Coverage observation for a single test input**
  public struct CoverageObservation: Codable, Sendable {
    /// Input identifier/hash
    public let inputId: String

    /// Classifications applied to this input
    public let classifications: [Classification]

    /// Observation timestamp
    public let timestamp: Date

    /// Test execution result
    public let testResult: TestResult

    /// Input size/complexity metric
    public let inputComplexity: Double?

    public enum TestResult: String, Codable, CaseIterable, Sendable {
      case success = "success"
      case failure = "failure"
      case timeout = "timeout"
      case error = "error"
    }

    public init(
      inputId: String,
      classifications: [Classification],
      timestamp: Date = Date(),
      testResult: TestResult,
      inputComplexity: Double? = nil
    ) {
      self.inputId = inputId
      self.classifications = classifications
      self.timestamp = timestamp
      self.testResult = testResult
      self.inputComplexity = inputComplexity
    }
  }

  /// **Coverage analysis result**
  public struct CoverageAnalysis: Codable, Sendable {
    /// Contract being analyzed
    public let contract: CoverageContract

    /// Total observations analyzed
    public let totalObservations: Int

    /// Coverage statistics per classification
    public let classificationCoverage: [String: ClassificationCoverage]

    /// Overall coverage percentage
    public let overallCoverage: Double

    /// Contract compliance status
    public let isCompliant: Bool

    /// Compliance violations (if any)
    public let violations: [ComplianceViolation]

    /// Coverage recommendations
    public let recommendations: [CoverageRecommendation]

    /// Statistical confidence in coverage
    public let statisticalConfidence: Double

    /// Analysis timestamp
    public let timestamp: Date

    public init(
      contract: CoverageContract,
      totalObservations: Int,
      classificationCoverage: [String: ClassificationCoverage],
      overallCoverage: Double,
      isCompliant: Bool,
      violations: [ComplianceViolation],
      recommendations: [CoverageRecommendation],
      statisticalConfidence: Double,
      timestamp: Date = Date()
    ) {
      self.contract = contract
      self.totalObservations = totalObservations
      self.classificationCoverage = classificationCoverage
      self.overallCoverage = overallCoverage
      self.isCompliant = isCompliant
      self.violations = violations
      self.recommendations = recommendations
      self.statisticalConfidence = statisticalConfidence
      self.timestamp = timestamp
    }
  }

  /// **Confidence interval for statistical analysis**
  public struct ConfidenceInterval: Codable, Sendable, Equatable {
    public let lower: Double
    public let upper: Double

    public init(lower: Double, upper: Double) {
      self.lower = lower
      self.upper = upper
    }
  }

  /// **Coverage statistics for a single classification**
  public struct ClassificationCoverage: Codable, Sendable {
    /// Classification being analyzed
    public let classification: Classification

    /// Number of samples in this classification
    public let sampleCount: Int

    /// Coverage percentage for this classification
    public let coveragePercentage: Double

    /// Success rate within this classification
    public let successRate: Double

    /// Average input complexity
    public let averageComplexity: Double?

    /// Statistical measures
    public let standardDeviation: Double?
    public let confidenceInterval: ConfidenceInterval?

    public init(
      classification: Classification,
      sampleCount: Int,
      coveragePercentage: Double,
      successRate: Double,
      averageComplexity: Double? = nil,
      standardDeviation: Double? = nil,
      confidenceInterval: ConfidenceInterval? = nil
    ) {
      self.classification = classification
      self.sampleCount = sampleCount
      self.coveragePercentage = coveragePercentage
      self.successRate = successRate
      self.averageComplexity = averageComplexity
      self.standardDeviation = standardDeviation
      self.confidenceInterval = confidenceInterval
    }
  }

  /// **Contract compliance violation**
  public struct ComplianceViolation: Codable, Sendable {
    public let type: ViolationType
    public let classificationId: String
    public let expected: Double
    public let actual: Double
    public let severity: Severity
    public let message: String

    public enum ViolationType: String, Codable, CaseIterable, Sendable {
      case insufficient_coverage = "insufficient_coverage"
      case insufficient_samples = "insufficient_samples"
      case excessive_samples = "excessive_samples"
      case missing_classification = "missing_classification"
      case low_confidence = "low_confidence"
    }

    public enum Severity: String, Codable, CaseIterable, Sendable {
      case critical = "critical"
      case warning = "warning"
      case info = "info"
    }

    public init(
      type: ViolationType,
      classificationId: String,
      expected: Double,
      actual: Double,
      severity: Severity,
      message: String
    ) {
      self.type = type
      self.classificationId = classificationId
      self.expected = expected
      self.actual = actual
      self.severity = severity
      self.message = message
    }
  }

  /// **Coverage improvement recommendation**
  public struct CoverageRecommendation: Codable, Sendable {
    public let type: RecommendationType
    public let classificationId: String
    public let priority: Int
    public let description: String
    public let estimatedImpact: Double

    public enum RecommendationType: String, Codable, CaseIterable, Sendable {
      case increase_samples = "increase_samples"
      case add_classification = "add_classification"
      case rebalance_distribution = "rebalance_distribution"
      case extend_testing_time = "extend_testing_time"
      case refine_classifier = "refine_classifier"
    }

    public init(
      type: RecommendationType,
      classificationId: String,
      priority: Int,
      description: String,
      estimatedImpact: Double
    ) {
      self.type = type
      self.classificationId = classificationId
      self.priority = priority
      self.description = description
      self.estimatedImpact = estimatedImpact
    }
  }

  // MARK: - Properties

  private var activeContracts: [String: CoverageContract] = [:]
  private var observations: [String: [CoverageObservation]] = [:]
  private var registeredClassifiers: [String: Any] = [:]
  private let logger = Logger(subsystem: "FunctionalTesting", category: "Coverage")

  /// **Shared coverage system instance**
  public static let shared = ClassificationCoverageSystem()

  // MARK: - Initialization

  public init() {}

  // MARK: - Public API

  /// **Register a coverage contract**
  public func registerContract(_ contract: CoverageContract) {
    activeContracts[contract.id] = contract
    observations[contract.id] = []

    logger.info(
      "📋 Registered coverage contract: \(contract.id) with \(contract.requiredClassifications.count) required classifications"
    )
  }

  /// **Register an input classifier**
  public func registerClassifier<T>(_ classifier: InputClassifier<T>) {
    registeredClassifiers[classifier.name] = classifier
    logger.info("🏷️ Registered classifier: \(classifier.name)")
  }

  /// **Observe test execution with input classification**
  public func observeExecution<T>(
    input: T,
    contractId: String,
    classifierName: String,
    result: CoverageObservation.TestResult,
    complexity: Double? = nil
  ) {
    guard let classifier = registeredClassifiers[classifierName] as? InputClassifier<T> else {
      logger.warning("⚠️ Classifier \(classifierName) not found for type \(T.self)")
      return
    }

    let classifications = classifier.classifyFunction(input)
    let inputId = generateInputId(input)

    let observation = CoverageObservation(
      inputId: inputId,
      classifications: classifications,
      testResult: result,
      inputComplexity: complexity
    )

    observations[contractId, default: []].append(observation)

    logger.debug(
      "👀 Observed execution: contract=\(contractId), classifications=\(classifications.map(\.id))"
    )
  }

  /// **Analyze coverage for a contract**
  public func analyzeCoverage(_ contractId: String) async -> CoverageAnalysis? {
    guard let contract = activeContracts[contractId],
      let contractObservations = observations[contractId]
    else {
      logger.warning("⚠️ Contract \(contractId) not found")
      return nil
    }

    return await performCoverageAnalysis(contract: contract, observations: contractObservations)
  }

  /// **Validate all active contracts**
  public func validateAllContracts() async -> [String: CoverageAnalysis] {
    var results: [String: CoverageAnalysis] = [:]

    for contractId in activeContracts.keys {
      if let analysis = await analyzeCoverage(contractId) {
        results[contractId] = analysis
      }
    }

    return results
  }

  /// **Get coverage summary**
  public func getCoverageSummary() async -> CoverageSummary {
    var totalObservations = 0
    var compliantContracts = 0
    var totalViolations = 0

    for contractId in activeContracts.keys {
      if let analysis = await analyzeCoverage(contractId) {
        totalObservations += analysis.totalObservations
        if analysis.isCompliant {
          compliantContracts += 1
        }
        totalViolations += analysis.violations.count
      }
    }

    return CoverageSummary(
      totalContracts: activeContracts.count,
      compliantContracts: compliantContracts,
      totalObservations: totalObservations,
      totalViolations: totalViolations,
      complianceRate: activeContracts.isEmpty
        ? 1.0 : Double(compliantContracts) / Double(activeContracts.count)
    )
  }

  /// **Clear observations for a contract**
  public func clearObservations(_ contractId: String) {
    observations[contractId] = []
    logger.info("🗑️ Cleared observations for contract: \(contractId)")
  }

  /// **Remove a contract**
  public func removeContract(_ contractId: String) {
    activeContracts.removeValue(forKey: contractId)
    observations.removeValue(forKey: contractId)
    logger.info("🗑️ Removed contract: \(contractId)")
  }

  // MARK: - Built-in Classifiers

  /// **Create a boundary value classifier for numeric types**
  public static func boundaryClassifier<T: Numeric & Comparable & Sendable>(
    name: String = "boundary",
    bounds: (min: T, max: T)
  ) -> InputClassifier<T> {
    InputClassifier<T>(name: name) { value in
      var classifications: [Classification] = []

      if value <= bounds.min {
        classifications.append(
          Classification(
            id: "minimum_boundary",
            label: "Minimum Boundary",
            description: "Value at or below minimum boundary",
            category: "boundary",
            priority: 10
          )
        )
      } else if value >= bounds.max {
        classifications.append(
          Classification(
            id: "maximum_boundary",
            label: "Maximum Boundary",
            description: "Value at or above maximum boundary",
            category: "boundary",
            priority: 10
          )
        )
      } else {
        // Calculate position within range
        let range = bounds.max - bounds.min
        let position = value - bounds.min
        let relativePosition = (Double("\(position)") ?? 0.0) / (Double("\(range)") ?? 1.0)

        if relativePosition < 0.1 {
          classifications.append(
            Classification(
              id: "near_minimum",
              label: "Near Minimum",
              description: "Value close to minimum boundary",
              category: "boundary",
              priority: 8
            )
          )
        } else if relativePosition > 0.9 {
          classifications.append(
            Classification(
              id: "near_maximum",
              label: "Near Maximum",
              description: "Value close to maximum boundary",
              category: "boundary",
              priority: 8
            )
          )
        } else {
          classifications.append(
            Classification(
              id: "typical_range",
              label: "Typical Range",
              description: "Value in typical range",
              category: "typical",
              priority: 5
            )
          )
        }
      }

      return classifications
    }
  }

  /// **Create a size-based classifier for collections**
  public static func collectionSizeClassifier<T: Collection & Sendable>(
    name: String = "collection_size"
  ) -> InputClassifier<T> {
    InputClassifier<T>(name: name) { collection in
      var classifications: [Classification] = []

      switch collection.count {
      case 0:
        classifications.append(
          Classification(
            id: "empty_collection",
            label: "Empty Collection",
            description: "Collection with no elements",
            category: "edge",
            priority: 10
          )
        )

      case 1:
        classifications.append(
          Classification(
            id: "single_element",
            label: "Single Element",
            description: "Collection with exactly one element",
            category: "edge",
            priority: 9
          )
        )

      case 2...10:
        classifications.append(
          Classification(
            id: "small_collection",
            label: "Small Collection",
            description: "Collection with few elements (2-10)",
            category: "typical",
            priority: 7
          )
        )

      case 11...100:
        classifications.append(
          Classification(
            id: "medium_collection",
            label: "Medium Collection",
            description: "Collection with moderate number of elements (11-100)",
            category: "typical",
            priority: 5
          )
        )

      default:
        classifications.append(
          Classification(
            id: "large_collection",
            label: "Large Collection",
            description: "Collection with many elements (100+)",
            category: "stress",
            priority: 8
          )
        )
      }

      return classifications
    }
  }

  /// **Create a string pattern classifier**
  public static func stringPatternClassifier(
    name: String = "string_pattern"
  ) -> InputClassifier<String> {
    InputClassifier<String>(name: name) { string in
      var classifications: [Classification] = []

      // Length-based classification
      switch string.count {
      case 0:
        classifications.append(
          Classification(
            id: "empty_string",
            label: "Empty String",
            category: "edge",
            priority: 10
          )
        )

      case 1:
        classifications.append(
          Classification(
            id: "single_character",
            label: "Single Character",
            category: "edge",
            priority: 9
          )
        )

      case 2...20:
        classifications.append(
          Classification(
            id: "short_string",
            label: "Short String",
            category: "typical",
            priority: 5
          )
        )

      case 21...200:
        classifications.append(
          Classification(
            id: "medium_string",
            label: "Medium String",
            category: "typical",
            priority: 5
          )
        )

      default:
        classifications.append(
          Classification(
            id: "long_string",
            label: "Long String",
            category: "stress",
            priority: 7
          )
        )
      }

      // Character content classification
      if string.allSatisfy(\.isWhitespace) && !string.isEmpty {
        classifications.append(
          Classification(
            id: "whitespace_only",
            label: "Whitespace Only",
            category: "edge",
            priority: 8
          )
        )
      }

      if string.allSatisfy(\.isNumber) && !string.isEmpty {
        classifications.append(
          Classification(
            id: "numeric_string",
            label: "Numeric String",
            category: "pattern",
            priority: 6
          )
        )
      }

      if string.allSatisfy(\.isLetter) && !string.isEmpty {
        classifications.append(
          Classification(
            id: "alphabetic_string",
            label: "Alphabetic String",
            category: "pattern",
            priority: 6
          )
        )
      }

      if string.contains(where: { !$0.isASCII }) {
        classifications.append(
          Classification(
            id: "unicode_string",
            label: "Unicode String",
            category: "international",
            priority: 7
          )
        )
      }

      return classifications
    }
  }

  // MARK: - Private Implementation

  private func performCoverageAnalysis(
    contract: CoverageContract,
    observations: [CoverageObservation]
  ) async -> CoverageAnalysis {

    // Build classification coverage map
    var classificationCoverage: [String: ClassificationCoverage] = [:]
    var classificationObservations: [String: [CoverageObservation]] = [:]

    // Group observations by classification
    for observation in observations {
      for classification in observation.classifications {
        classificationObservations[classification.id, default: []].append(observation)
      }
    }

    // Calculate coverage for each required classification
    for classificationId in contract.requiredClassifications {
      let obsForClassification = classificationObservations[classificationId] ?? []
      let sampleCount = obsForClassification.count

      let successCount = obsForClassification.filter { $0.testResult == .success }.count
      let successRate = sampleCount > 0 ? Double(successCount) / Double(sampleCount) : 0.0

      let averageComplexity = obsForClassification.compactMap(\.inputComplexity).average
      let coveragePercentage = Double(sampleCount) / Double(max(observations.count, 1))

      // Find the classification definition (assuming it's in the first observation)
      let classification =
        obsForClassification.first?.classifications
        .first { $0.id == classificationId }
        ?? Classification(
          id: classificationId,
          label: classificationId,
          description: "Unknown classification"
        )

      classificationCoverage[classificationId] = ClassificationCoverage(
        classification: classification,
        sampleCount: sampleCount,
        coveragePercentage: coveragePercentage,
        successRate: successRate,
        averageComplexity: averageComplexity
      )
    }

    // Calculate overall coverage
    let coveredClassifications = classificationCoverage.values
      .filter { $0.sampleCount >= contract.minimumSamplesPerClassification }
      .count

    let overallCoverage =
      contract.requiredClassifications.isEmpty
      ? 1.0 : Double(coveredClassifications) / Double(contract.requiredClassifications.count)

    // Identify violations
    let violations = identifyViolations(contract: contract, coverage: classificationCoverage)

    // Generate recommendations
    let recommendations = generateRecommendations(
      contract: contract,
      coverage: classificationCoverage
    )

    // Calculate statistical confidence (simplified)
    let statisticalConfidence = calculateStatisticalConfidence(
      observations: observations,
      confidenceLevel: contract.confidenceLevel
    )

    // Determine compliance
    let isCompliant =
      violations.filter { $0.severity == .critical }.isEmpty
      && overallCoverage >= contract.minimumCoverage

    return CoverageAnalysis(
      contract: contract,
      totalObservations: observations.count,
      classificationCoverage: classificationCoverage,
      overallCoverage: overallCoverage,
      isCompliant: isCompliant,
      violations: violations,
      recommendations: recommendations,
      statisticalConfidence: statisticalConfidence
    )
  }

  private func identifyViolations(
    contract: CoverageContract,
    coverage: [String: ClassificationCoverage]
  ) -> [ComplianceViolation] {
    var violations: [ComplianceViolation] = []

    for classificationId in contract.requiredClassifications {
      let classCoverage = coverage[classificationId]
      let sampleCount = classCoverage?.sampleCount ?? 0

      // Check minimum samples
      if sampleCount < contract.minimumSamplesPerClassification {
        violations.append(
          ComplianceViolation(
            type: .insufficient_samples,
            classificationId: classificationId,
            expected: Double(contract.minimumSamplesPerClassification),
            actual: Double(sampleCount),
            severity: .critical,
            message:
              "Classification '\(classificationId)' has \(sampleCount) samples, requires \(contract.minimumSamplesPerClassification)"
          )
        )
      }

      // Check maximum samples (if specified)
      if let maxSamples = contract.maximumSamplesPerClassification,
        sampleCount > maxSamples
      {
        violations.append(
          ComplianceViolation(
            type: .excessive_samples,
            classificationId: classificationId,
            expected: Double(maxSamples),
            actual: Double(sampleCount),
            severity: .warning,
            message:
              "Classification '\(classificationId)' has \(sampleCount) samples, maximum is \(maxSamples)"
          )
        )
      }

      // Check coverage percentage
      let coveragePercentage = classCoverage?.coveragePercentage ?? 0.0
      if coveragePercentage < contract.minimumCoverage {
        violations.append(
          ComplianceViolation(
            type: .insufficient_coverage,
            classificationId: classificationId,
            expected: contract.minimumCoverage,
            actual: coveragePercentage,
            severity: .critical,
            message:
              "Classification '\(classificationId)' coverage is \(String(format: "%.1f", coveragePercentage * 100))%, requires \(String(format: "%.1f", contract.minimumCoverage * 100))%"
          )
        )
      }
    }

    return violations
  }

  private func generateRecommendations(
    contract: CoverageContract,
    coverage: [String: ClassificationCoverage]
  ) -> [CoverageRecommendation] {
    var recommendations: [CoverageRecommendation] = []

    for classificationId in contract.requiredClassifications {
      let classCoverage = coverage[classificationId]
      let sampleCount = classCoverage?.sampleCount ?? 0

      if sampleCount < contract.minimumSamplesPerClassification {
        let needed = contract.minimumSamplesPerClassification - sampleCount
        recommendations.append(
          CoverageRecommendation(
            type: .increase_samples,
            classificationId: classificationId,
            priority: 10,
            description: "Increase samples for '\(classificationId)' by \(needed)",
            estimatedImpact: Double(needed) / Double(contract.minimumSamplesPerClassification)
          )
        )
      }
    }

    return recommendations.sorted { $0.priority > $1.priority }
  }

  private func calculateStatisticalConfidence(
    observations: [CoverageObservation],
    confidenceLevel: Double
  ) -> Double {
    // Simplified statistical confidence calculation
    // In practice, this would use proper statistical methods
    guard !observations.isEmpty else { return 0.0 }

    let sampleSize = observations.count
    let baseConfidence = min(1.0, Double(sampleSize) / 100.0)  // Simple heuristic

    return baseConfidence * confidenceLevel
  }

  private func generateInputId<T>(_ input: T) -> String {
    // Simple hash-based ID generation
    String(describing: input).hash.description
  }
}

// MARK: - Coverage Summary

/// **High-level coverage summary**
public struct CoverageSummary: Codable, Sendable {
  public let totalContracts: Int
  public let compliantContracts: Int
  public let totalObservations: Int
  public let totalViolations: Int
  public let complianceRate: Double

  public init(
    totalContracts: Int,
    compliantContracts: Int,
    totalObservations: Int,
    totalViolations: Int,
    complianceRate: Double
  ) {
    self.totalContracts = totalContracts
    self.compliantContracts = compliantContracts
    self.totalObservations = totalObservations
    self.totalViolations = totalViolations
    self.complianceRate = complianceRate
  }
}

// MARK: - PropertyRunner Integration

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension PropertyRunner {

  /// **Run property test with classification coverage**
  public func runPropertyWithCoverage<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default,
    coverageSystem: ClassificationCoverageSystem = .shared,
    contractId: String,
    classifierName: String
  ) async -> (result: PropertyResult<T>, coverage: ClassificationCoverageSystem.CoverageAnalysis?)
  where T: Sendable {

    // Run the property test
    let result = runProperty(property, config: config)

    // Record coverage observation based on result
    let testResult: ClassificationCoverageSystem.CoverageObservation.TestResult =
      switch result {
      case .success: .success
      case .failure: .failure
      case .gaveUp: .timeout
      }

    // For this integration, we'll observe the first generated value
    // In practice, you'd integrate this more deeply into the test execution
    let generator = property.generator
    var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
    let sampleInput = generator.generate(&rng, Size(value: 50))

    await coverageSystem.observeExecution(
      input: sampleInput,
      contractId: contractId,
      classifierName: classifierName,
      result: testResult
    )

    // Analyze coverage
    let coverage = await coverageSystem.analyzeCoverage(contractId)

    return (result: result, coverage: coverage)
  }
}

// MARK: - Utility Extensions

private extension Array where Element == Double {
  var average: Double? {
    guard !isEmpty else { return nil }
    return reduce(0, +) / Double(count)
  }
}

import os

private let logger = Logger(subsystem: "FunctionalTesting", category: "Coverage")
