import Foundation

// MARK: - Domain-Specific Generators for Advanced Testing

/// **Domain-Specific Generators for Real-World Data Structures**
///
/// Advanced generators for common domain objects including graphs, JSON schemas,
/// and structured data formats. These generators are essential for testing
/// systems that operate on complex, real-world data structures.
///
/// **Mathematical Foundation:**
/// Based on combinatorial generation theory and domain-specific modeling
/// patterns from practical software testing research.
///
/// **External References:**
/// - [Graph Theory Fundamentals](https://en.wikipedia.org/wiki/Graph_theory)
/// - [JSON Schema Specification](https://json-schema.org/specification.html)
/// - [Model-Based Testing](https://en.wikipedia.org/wiki/Model-based_testing)

// MARK: - Graph Generators

/// **Vertex in a directed graph**
public struct Vertex: Hashable, Codable, Sendable {
  public let id: String
  public let label: String?
  public let metadata: [String: String]

  public init(id: String, label: String? = nil, metadata: [String: String] = [:]) {
    self.id = id
    self.label = label
    self.metadata = metadata
  }
}

/// **Edge in a directed graph**
public struct Edge: Hashable, Codable, Sendable {
  public let from: String
  public let to: String
  public let weight: Double?
  public let label: String?
  public let metadata: [String: String]

  public init(
    from: String,
    to: String,
    weight: Double? = nil,
    label: String? = nil,
    metadata: [String: String] = [:]
  ) {
    self.from = from
    self.to = to
    self.weight = weight
    self.label = label
    self.metadata = metadata
  }
}

/// **Directed graph structure for testing graph algorithms**
public struct DirectedGraph: Hashable, Codable, Sendable {
  public let vertices: Set<Vertex>
  public let edges: Set<Edge>

  public init(vertices: Set<Vertex>, edges: Set<Edge>) {
    self.vertices = vertices
    self.edges = edges
  }

  /// Validate that all edges reference existing vertices
  public var isValid: Bool {
    let vertexIds = Set(vertices.map { $0.id })
    return edges.allSatisfy { edge in
      vertexIds.contains(edge.from) && vertexIds.contains(edge.to)
    }
  }
}

extension Gen where T == DirectedGraph {
  /// **Generate directed graphs with comprehensive coverage**
  ///
  /// Generates graphs covering important structural patterns:
  /// - Empty graphs and single vertices
  /// - Trees, cycles, and DAGs
  /// - Connected and disconnected components
  /// - Various connectivity patterns
  ///
  /// **Graph Theory Coverage:**
  /// - Acyclic graphs (trees, forests, DAGs)
  /// - Cyclic graphs (simple cycles, complex cycles)
  /// - Connected vs disconnected components
  /// - Various vertex degrees and connectivity patterns
  // swiftlint:disable:next cyclomatic_complexity
  public static func directedGraph(
    maxVertices: Int = 10,
    maxEdges: Int = 15,
    allowSelfLoops: Bool = true,
    allowMultipleEdges: Bool = false
  ) -> Gen<DirectedGraph> {
    Gen<DirectedGraph>(
      generate: { rng, size in
        let vertexCount = Int.random(in: 0...min(maxVertices, max(size.value, 1)), using: &rng)

        // Edge cases for small sizes
        if size.value <= 3 {
          let edgeCases: [DirectedGraph] = [
            DirectedGraph(vertices: [], edges: []),  // Empty graph
            DirectedGraph(vertices: [Vertex(id: "v0")], edges: []),  // Single vertex
            DirectedGraph(
              vertices: [Vertex(id: "v0"), Vertex(id: "v1")],
              edges: [Edge(from: "v0", to: "v1")]
            ),  // Single edge
          ]
          if Bool.random(using: &rng) && !edgeCases.isEmpty {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        // Generate vertices
        var vertices: Set<Vertex> = []
        for i in 0..<vertexCount {
          let vertex = Vertex(
            id: "v\(i)",
            label: Bool.random(using: &rng) ? "Label\(i)" : nil,
            metadata: Bool.random(using: &rng) ? ["type": "node", "weight": "\(i)"] : [:]
          )
          vertices.insert(vertex)
        }

        guard !vertices.isEmpty else {
          return DirectedGraph(vertices: [], edges: [])
        }

        let vertexIds = Array(vertices.map { $0.id })
        let edgeCount = Int.random(
          in: 0...min(maxEdges, vertexIds.count * vertexIds.count),
          using: &rng
        )
        var edges: Set<Edge> = []

        // Generate edges with structural patterns
        for _ in 0..<edgeCount {
          let fromId = vertexIds.randomElement(using: &rng)!
          let toId = vertexIds.randomElement(using: &rng)!

          // Skip self-loops if not allowed
          if !allowSelfLoops && fromId == toId {
            continue
          }

          let edge = Edge(
            from: fromId,
            to: toId,
            weight: Bool.random(using: &rng) ? Double.random(in: 0...100, using: &rng) : nil,
            label: Bool.random(using: &rng) ? "edge_\(fromId)_\(toId)" : nil,
            metadata: Bool.random(using: &rng) ? ["type": "connection"] : [:]
          )

          // Skip multiple edges if not allowed
          if !allowMultipleEdges
            && edges.contains(where: { $0.from == edge.from && $0.to == edge.to })
          {
            continue
          }

          edges.insert(edge)
        }

        return DirectedGraph(vertices: vertices, edges: edges)
      },
      shrink: Shrink { graph in
        var shrunk: [DirectedGraph] = []

        // Shrink to empty graph
        if !graph.vertices.isEmpty {
          shrunk.append(DirectedGraph(vertices: [], edges: []))
        }

        // Remove vertices one by one
        for vertex in graph.vertices {
          var remainingVertices = graph.vertices
          remainingVertices.remove(vertex)

          // Filter out edges that reference the removed vertex
          let remainingEdges = graph.edges.filter { edge in
            edge.from != vertex.id && edge.to != vertex.id
          }

          shrunk.append(DirectedGraph(vertices: remainingVertices, edges: Set(remainingEdges)))
        }

        // Remove edges one by one
        for edge in graph.edges {
          var remainingEdges = graph.edges
          remainingEdges.remove(edge)
          shrunk.append(DirectedGraph(vertices: graph.vertices, edges: remainingEdges))
        }

        // Shrink to tree structure (remove cycles)
        if graph.edges.count > graph.vertices.count - 1 && graph.vertices.count > 1 {
          let treeEdgeCount = max(0, graph.vertices.count - 1)
          let treeEdges = Set(Array(graph.edges).prefix(treeEdgeCount))
          shrunk.append(DirectedGraph(vertices: graph.vertices, edges: treeEdges))
        }

        return Array(Set(shrunk))  // Remove duplicates
      }
    )
  }

  /// **Generate trees (connected acyclic graphs)**
  public static func tree(maxVertices: Int = 10) -> Gen<DirectedGraph> {
    Gen<DirectedGraph>(
      generate: { rng, size in
        let vertexCount = max(
          1,
          Int.random(in: 1...min(maxVertices, max(size.value, 1)), using: &rng)
        )

        // Generate vertices
        var vertices: Set<Vertex> = []
        for i in 0..<vertexCount {
          vertices.insert(Vertex(id: "v\(i)", label: "Node\(i)"))
        }

        // Generate tree edges (n-1 edges for n vertices)
        var edges: Set<Edge> = []
        let vertexIds = Array(vertices.map { $0.id }).sorted()

        if vertexIds.count > 1 {
          // Create a random tree by connecting each vertex to a random previous one
          for i in 1..<vertexIds.count {
            let parentIndex = Int.random(in: 0..<i, using: &rng)
            let edge = Edge(from: vertexIds[parentIndex], to: vertexIds[i])
            edges.insert(edge)
          }
        }

        return DirectedGraph(vertices: vertices, edges: edges)
      },
      shrink: directedGraph().shrink
    )
  }

  /// **Generate complete graphs (every vertex connected to every other)**
  public static func completeGraph(maxVertices: Int = 5) -> Gen<DirectedGraph> {
    Gen<DirectedGraph>(
      generate: { rng, size in
        let vertexCount = max(
          1,
          Int.random(in: 1...min(maxVertices, max(size.value, 1)), using: &rng)
        )

        // Generate vertices
        var vertices: Set<Vertex> = []
        for i in 0..<vertexCount {
          vertices.insert(Vertex(id: "v\(i)", label: "Node\(i)"))
        }

        // Generate complete graph edges
        var edges: Set<Edge> = []
        let vertexIds = Array(vertices.map { $0.id })

        for from in vertexIds {
          for to in vertexIds {
            if from != to {  // No self-loops in complete graphs
              edges.insert(Edge(from: from, to: to))
            }
          }
        }

        return DirectedGraph(vertices: vertices, edges: edges)
      },
      shrink: directedGraph().shrink
    )
  }
}

// MARK: - JSON Schema Generators

/// **JSON Schema type definitions**
public enum JSONSchemaType: String, CaseIterable, Codable, Sendable, Hashable {
  case object
  case array
  case string
  case number
  case integer
  case boolean
  case null
}

/// **JSON Schema data structure**
public struct JSONSchemaData: Codable, Sendable, Equatable, Hashable {
  public let type: JSONSchemaType?
  public let properties: [String: JSONSchema]?
  public let items: JSONSchema?
  public let required: [String]?
  public let minimum: Double?
  public let maximum: Double?
  public let minLength: Int?
  public let maxLength: Int?
  public let pattern: String?
  public let `enum`: [String]?
  public let description: String?
  public let title: String?

  public init(
    type: JSONSchemaType? = nil,
    properties: [String: JSONSchema]? = nil,
    items: JSONSchema? = nil,
    required: [String]? = nil,
    minimum: Double? = nil,
    maximum: Double? = nil,
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    enum: [String]? = nil,
    description: String? = nil,
    title: String? = nil
  ) {
    self.type = type
    self.properties = properties
    self.items = items
    self.required = required
    self.minimum = minimum
    self.maximum = maximum
    self.minLength = minLength
    self.maxLength = maxLength
    self.pattern = pattern
    self.enum = `enum`
    self.description = description
    self.title = title
  }
}

/// **JSON Schema structure for validation testing**
public indirect enum JSONSchema: Codable, Sendable, Equatable, Hashable {
  case schema(JSONSchemaData)

  public var data: JSONSchemaData {
    switch self {
    case .schema(let data):
      return data
    }
  }

  public var type: JSONSchemaType? { data.type }
  public var properties: [String: Self]? { data.properties }
  public var items: Self? { data.items }
  public var required: [String]? { data.required }
  public var minimum: Double? { data.minimum }
  public var maximum: Double? { data.maximum }
  public var minLength: Int? { data.minLength }
  public var maxLength: Int? { data.maxLength }
  public var pattern: String? { data.pattern }
  public var `enum`: [String]? { data.enum }
  public var description: String? { data.description }
  public var title: String? { data.title }

  public init(
    type: JSONSchemaType? = nil,
    properties: [String: Self]? = nil,
    items: Self? = nil,
    required: [String]? = nil,
    minimum: Double? = nil,
    maximum: Double? = nil,
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    enum: [String]? = nil,
    description: String? = nil,
    title: String? = nil
  ) {
    self = .schema(
      JSONSchemaData(
        type: type,
        properties: properties,
        items: items,
        required: required,
        minimum: minimum,
        maximum: maximum,
        minLength: minLength,
        maxLength: maxLength,
        pattern: pattern,
        enum: `enum`,
        description: description,
        title: title
      )
    )
  }

  // MARK: - Hashable Protocol Witness
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .schema(let data):
      hasher.combine(data)
    }
  }
}

/// **Box wrapper for recursive JSON Schema structures**
public struct Box<T: Codable>: Codable, Sendable where T: Sendable {
  public let value: T

  public init(_ value: T) {
    self.value = value
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    value = try container.decode(T.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
}

extension Box: Equatable where T: Equatable {}

extension Gen where T == JSONSchema {
  /// **Generate JSON schemas with realistic complexity**
  ///
  /// Creates schemas covering common patterns:
  /// - Primitive types with constraints
  /// - Object schemas with nested properties
  /// - Array schemas with various item types
  /// - Complex nested structures
  /// - Validation constraints (min/max, patterns, enums)
  ///
  /// **Schema Theory Coverage:**
  /// - All JSON Schema primitive types
  /// - Nested object and array structures
  /// - Validation constraints and rules
  /// - Required fields and optional properties
  /// - Enum constraints and pattern validation
  // swiftlint:disable:next function_body_length
  public static func jsonSchema(maxDepth: Int = 3, maxProperties: Int = 5) -> Gen<JSONSchema> {
    // swiftlint:disable:next cyclomatic_complexity
    func schemaGenerator(depth: Int) -> Gen<JSONSchema> {
      Gen<JSONSchema>(
        generate: { rng, size in
          // Edge cases
          if size.value <= 2 || depth >= maxDepth {
            let simpleTypes = JSONSchemaType.allCases.filter { $0 != .object && $0 != .array }
            let type = simpleTypes.randomElement(using: &rng)!

            switch type {
            case .string:
              return JSONSchema(
                type: .string,
                minLength: Bool.random(using: &rng) ? Int.random(in: 0...10, using: &rng) : nil,
                maxLength: Bool.random(using: &rng) ? Int.random(in: 10...100, using: &rng) : nil,
                pattern: Bool.random(using: &rng) ? "^[a-zA-Z0-9]+$" : nil
              )

            case .number, .integer:
              return JSONSchema(
                type: type,
                minimum: Bool.random(using: &rng) ? Double.random(in: -100...0, using: &rng) : nil,
                maximum: Bool.random(using: &rng) ? Double.random(in: 0...100, using: &rng) : nil
              )

            case .boolean:
              return JSONSchema(type: .boolean)

            case .null:
              return JSONSchema(type: .null)

            case .object, .array:
              return JSONSchema(type: .boolean)  // Fallback for recursion base case
            }
          }

          // Choose schema type
          let schemaType = JSONSchemaType.allCases.randomElement(using: &rng)!

          switch schemaType {
          case .object:
            let propertyCount = Int.random(
              in: 1...min(maxProperties, max(size.value, 1)),
              using: &rng
            )
            var properties: [String: JSONSchema] = [:]
            var required: [String] = []

            for i in 0..<propertyCount {
              let propName = "prop\(i)"
              properties[propName] = schemaGenerator(depth: depth + 1).generate(
                &rng,
                Size(value: size.value / 2)
              )

              if Bool.random(using: &rng) {
                required.append(propName)
              }
            }

            return JSONSchema(
              type: .object,
              properties: properties,
              required: required.isEmpty ? nil : required,
              description: Bool.random(using: &rng) ? "Object schema at depth \(depth)" : nil,
              title: Bool.random(using: &rng) ? "ObjectSchema\(depth)" : nil
            )

          case .array:
            let itemSchema = schemaGenerator(depth: depth + 1).generate(
              &rng,
              Size(value: size.value / 2)
            )
            return JSONSchema(
              type: .array,
              items: itemSchema,
              description: Bool.random(using: &rng) ? "Array schema at depth \(depth)" : nil,
              title: Bool.random(using: &rng) ? "ArraySchema\(depth)" : nil
            )

          case .string:
            let enumValues =
              Bool.random(using: &rng)
              ? Array((0..<Int.random(in: 2...5, using: &rng)).map { "value\($0)" }) : nil

            return JSONSchema(
              type: .string,
              minLength: Bool.random(using: &rng) ? Int.random(in: 0...10, using: &rng) : nil,
              maxLength: Bool.random(using: &rng) ? Int.random(in: 10...100, using: &rng) : nil,
              pattern: Bool.random(using: &rng) ? "^[a-zA-Z0-9]+$" : nil,
              enum: enumValues
            )

          case .number, .integer:
            return JSONSchema(
              type: schemaType,
              minimum: Bool.random(using: &rng) ? Double.random(in: -1000...0, using: &rng) : nil,
              maximum: Bool.random(using: &rng) ? Double.random(in: 0...1000, using: &rng) : nil
            )

          case .boolean:
            return JSONSchema(type: .boolean)

          case .null:
            return JSONSchema(type: .null)
          }
        },
        shrink: Shrink { schema in
          var shrunk: [JSONSchema] = []

          // Shrink to simpler types
          if schema.type == .object || schema.type == .array {
            shrunk.append(JSONSchema(type: .string))
            shrunk.append(JSONSchema(type: .boolean))
          }

          // Remove optional properties
          if let properties = schema.properties, !properties.isEmpty {
            let reducedProperties = Dictionary(uniqueKeysWithValues: properties.dropLast())
            shrunk.append(
              JSONSchema(
                type: schema.type,
                properties: reducedProperties.isEmpty ? nil : reducedProperties,
                items: schema.items,
                required: schema.required
              )
            )
          }

          // Remove constraints
          if schema.minimum != nil || schema.maximum != nil || schema.pattern != nil
            || schema.enum != nil
          {
            shrunk.append(
              JSONSchema(type: schema.type, properties: schema.properties, items: schema.items)
            )
          }

          return Array(Set(shrunk))
        }
      )
    }

    return schemaGenerator(depth: 0)
  }

  /// **Generate simple primitive schemas**
  public static var primitiveSchema: Gen<JSONSchema> {
    Gen<JSONSchema>(
      generate: { rng, _ in
        let primitiveTypes: [JSONSchemaType] = [.string, .number, .integer, .boolean, .null]
        let type = primitiveTypes.randomElement(using: &rng)!
        return JSONSchema(type: type)
      },
      shrink: Shrink { _ in [JSONSchema(type: .boolean)] }
    )
  }
}

// MARK: - Structured Data Generators

/// **Database-like record structure**
public struct DatabaseRecord: Codable, Sendable, Equatable, Hashable {
  public let id: String
  public let fields: [String: DatabaseValue]
  public let timestamp: Date
  public let metadata: [String: String]

  public init(
    id: String,
    fields: [String: DatabaseValue],
    timestamp: Date = Date(),
    metadata: [String: String] = [:]
  ) {
    self.id = id
    self.fields = fields
    self.timestamp = timestamp
    self.metadata = metadata
  }

  // MARK: - Hashable Protocol Witness
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(timestamp)
    for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
      hasher.combine(key)
      hasher.combine(value)
    }
    for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
      hasher.combine(key)
      hasher.combine(value)
    }
  }
}

/// **Typed values for database records**
public enum DatabaseValue: Codable, Sendable, Equatable, Hashable {
  case string(String)
  case integer(Int64)
  case double(Double)
  case boolean(Bool)
  case date(Date)
  case null

  public var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  public var intValue: Int64? {
    guard case .integer(let value) = self else { return nil }
    return value
  }
}

extension Gen where T == DatabaseRecord {
  /// **Generate realistic database records**
  ///
  /// Creates records with various field types and realistic data patterns:
  /// - String fields with various lengths and patterns
  /// - Numeric fields with realistic ranges
  /// - Boolean flags and status fields
  /// - Timestamp fields with realistic dates
  /// - Null values for optional fields
  ///
  /// **Database Theory Coverage:**
  /// - Relational data model patterns
  /// - Various SQL data types
  /// - Nullable vs non-nullable fields
  /// - Primary keys and metadata
  /// - Realistic data distributions
  // swiftlint:disable:next cyclomatic_complexity
  public static func databaseRecord(
    maxFields: Int = 10,
    fieldNames: [String] = [
      "name", "email", "age", "active", "created", "score", "category", "description",
    ]
  ) -> Gen<DatabaseRecord> {
    Gen<DatabaseRecord>(
      generate: { rng, size in
        let recordId = "rec_\(UUID().uuidString.prefix(8))"
        let fieldCount = Int.random(in: 1...min(maxFields, max(size.value, 1)), using: &rng)
        let selectedFields = fieldNames.shuffled(using: &rng).prefix(fieldCount)

        var fields: [String: DatabaseValue] = [:]

        for fieldName in selectedFields {
          let value: DatabaseValue

          // Generate field values based on field names (realistic patterns)
          switch fieldName {
          case "id", "userId", "accountId":
            value = .string("id_\(Int.random(in: 1000...9999, using: &rng))")

          case "name", "title", "category":
            value = .string(
              "Generated \(fieldName.capitalized) \(Int.random(in: 1...100, using: &rng))"
            )

          case "email":
            value = .string("user\(Int.random(in: 1...999, using: &rng))@example.com")

          case "age", "count", "score":
            value = .integer(Int64.random(in: 0...100, using: &rng))

          case "price", "amount", "rating":
            value = .double(Double.random(in: 0...1000, using: &rng))

          case "active", "enabled", "verified":
            value = .boolean(Bool.random(using: &rng))

          case "created", "updated", "timestamp":
            let randomDate = Date().addingTimeInterval(
              Double.random(in: -86400 * 365...0, using: &rng)
            )
            value = .date(randomDate)

          case "description", "notes":
            if Bool.random(using: &rng) {  // 50% chance of null for optional text fields
              value = .null
            } else {
              value = .string("Description text for \(fieldName)")
            }

          default:
            // Random type for unknown fields
            let randomTypes: [DatabaseValue] = [
              .string("value\(Int.random(in: 1...100, using: &rng))"),
              .integer(Int64.random(in: 0...1000, using: &rng)),
              .boolean(Bool.random(using: &rng)),
              .null,
            ]
            value = randomTypes.randomElement(using: &rng)!
          }

          fields[fieldName] = value
        }

        return DatabaseRecord(
          id: recordId,
          fields: fields,
          timestamp: Date(),
          metadata: Bool.random(using: &rng) ? ["source": "generator", "version": "1.0"] : [:]
        )
      },
      shrink: Shrink { record in
        var shrunk: [DatabaseRecord] = []

        // Remove fields one by one
        for fieldName in record.fields.keys {
          var reducedFields = record.fields
          reducedFields.removeValue(forKey: fieldName)

          if !reducedFields.isEmpty {
            shrunk.append(
              DatabaseRecord(
                id: record.id,
                fields: reducedFields,
                timestamp: record.timestamp,
                metadata: record.metadata
              )
            )
          }
        }

        // Simplify field values
        for (fieldName, fieldValue) in record.fields {
          var simplifiedFields = record.fields

          switch fieldValue {
          case .string(let str) where str.count > 1:
            simplifiedFields[fieldName] = .string("x")

          case .integer(let num) where num != 0:
            simplifiedFields[fieldName] = .integer(0)

          case .double(let num) where num != 0.0:
            simplifiedFields[fieldName] = .double(0.0)

          default:
            continue
          }

          shrunk.append(
            DatabaseRecord(
              id: record.id,
              fields: simplifiedFields,
              timestamp: record.timestamp,
              metadata: record.metadata
            )
          )
        }

        return Array(Set(shrunk))
      }
    )
  }
}

// MARK: - Network/API Data Generators

/// **HTTP-like request structure for API testing**
public struct HTTPRequest: Codable, Sendable, Equatable, Hashable {
  public let method: HTTPMethod
  public let path: String
  public let headers: [String: String]
  public let body: Data?
  public let queryParameters: [String: String]

  public init(
    method: HTTPMethod,
    path: String,
    headers: [String: String] = [:],
    body: Data? = nil,
    queryParameters: [String: String] = [:]
  ) {
    self.method = method
    self.path = path
    self.headers = headers
    self.body = body
    self.queryParameters = queryParameters
  }

  // MARK: - Hashable Protocol Witness
  public func hash(into hasher: inout Hasher) {
    hasher.combine(method)
    hasher.combine(path)
    hasher.combine(body)
    for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
      hasher.combine(key)
      hasher.combine(value)
    }
    for (key, value) in queryParameters.sorted(by: { $0.key < $1.key }) {
      hasher.combine(key)
      hasher.combine(value)
    }
  }
}

/// **HTTP methods for request generation**
public enum HTTPMethod: String, CaseIterable, Codable, Sendable, Hashable {
  case GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
}

extension Gen where T == HTTPRequest {
  /// **Generate realistic HTTP requests**
  ///
  /// Creates requests covering common API patterns:
  /// - Various HTTP methods with appropriate usage
  /// - RESTful path structures
  /// - Common headers (Content-Type, Authorization, etc.)
  /// - Query parameters with realistic names
  /// - JSON and form-encoded body content
  ///
  /// **HTTP Protocol Coverage:**
  /// - All standard HTTP methods
  /// - RESTful API path patterns
  /// - Common header patterns
  /// - Query parameter structures
  /// - Content negotiation patterns
  // swiftlint:disable:next cyclomatic_complexity
  public static func httpRequest(
    maxPathSegments: Int = 4,
    maxHeaders: Int = 10,
    maxQueryParams: Int = 5
  ) -> Gen<HTTPRequest> {
    Gen<HTTPRequest>(
      generate: { rng, _ in
        let method = HTTPMethod.allCases.randomElement(using: &rng)!

        // Generate RESTful paths
        let pathSegments = (0..<Int.random(in: 1...maxPathSegments, using: &rng)).map { i in
          let resourceTypes = [
            "users", "posts", "orders", "products", "comments", "files", "api", "v1", "admin",
          ]
          if i % 2 == 0 {
            return resourceTypes.randomElement(using: &rng)!
          } else {
            return "\(Int.random(in: 1...9999, using: &rng))"
          }
        }
        let path = "/" + pathSegments.joined(separator: "/")

        // Generate realistic headers
        var headers: [String: String] = [:]
        let commonHeaders = [
          (
            "Content-Type", ["application/json", "application/x-www-form-urlencoded", "text/plain"]
          ),
          ("Accept", ["application/json", "*/*", "text/html"]),
          ("Authorization", ["Bearer token123", "Basic dXNlcjpwYXNz", "API-Key abc123"]),
          ("User-Agent", ["TestClient/1.0", "Mozilla/5.0", "Mobile/1.0"]),
          ("X-API-Version", ["v1", "v2", "2023-01-01"]),
          ("X-Request-ID", [UUID().uuidString]),
          ("Cache-Control", ["no-cache", "max-age=3600", "public"]),
        ]

        let headerCount = Int.random(in: 0...min(maxHeaders, commonHeaders.count), using: &rng)
        for (headerName, possibleValues) in commonHeaders.shuffled(using: &rng).prefix(headerCount)
        {
          headers[headerName] = possibleValues.randomElement(using: &rng)!
        }

        // Generate query parameters
        var queryParams: [String: String] = [:]
        let commonParams = ["page", "limit", "sort", "filter", "q", "format", "lang", "timestamp"]
        let paramCount = Int.random(in: 0...min(maxQueryParams, commonParams.count), using: &rng)

        for paramName in commonParams.shuffled(using: &rng).prefix(paramCount) {
          switch paramName {
          case "page":
            queryParams[paramName] = "\(Int.random(in: 1...10, using: &rng))"

          case "limit":
            queryParams[paramName] = "\(Int.random(in: 10...100, using: &rng))"

          case "sort":
            queryParams[paramName] = ["asc", "desc", "created", "updated"].randomElement(
              using: &rng
            )!

          case "format":
            queryParams[paramName] = ["json", "xml", "csv"].randomElement(using: &rng)!

          case "lang":
            queryParams[paramName] = ["en", "es", "fr", "de"].randomElement(using: &rng)!

          default:
            queryParams[paramName] = "value\(Int.random(in: 1...100, using: &rng))"
          }
        }

        // Generate body for methods that typically have bodies
        let body: Data?
        if [.POST, .PUT, .PATCH].contains(method) && Bool.random(using: &rng) {
          let jsonObject = ["data": "test", "timestamp": "\(Date().timeIntervalSince1970)"]
          body = try? JSONSerialization.data(withJSONObject: jsonObject)
        } else {
          body = nil
        }

        return HTTPRequest(
          method: method,
          path: path,
          headers: headers,
          body: body,
          queryParameters: queryParams
        )
      },
      shrink: Shrink { request in
        var shrunk: [HTTPRequest] = []

        // Simplify path
        if request.path.count > 1 {
          shrunk.append(HTTPRequest(method: request.method, path: "/"))
        }

        // Remove headers one by one
        if !request.headers.isEmpty {
          for headerName in request.headers.keys {
            var reducedHeaders = request.headers
            reducedHeaders.removeValue(forKey: headerName)
            shrunk.append(
              HTTPRequest(
                method: request.method,
                path: request.path,
                headers: reducedHeaders,
                queryParameters: request.queryParameters
              )
            )
          }
        }

        // Remove query parameters
        if !request.queryParameters.isEmpty {
          shrunk.append(
            HTTPRequest(
              method: request.method,
              path: request.path,
              headers: request.headers,
              queryParameters: [:]
            )
          )
        }

        // Remove body
        if request.body != nil {
          shrunk.append(
            HTTPRequest(
              method: request.method,
              path: request.path,
              headers: request.headers,
              queryParameters: request.queryParameters
            )
          )
        }

        return Array(Set(shrunk))
      }
    )
  }
// swiftlint:disable:next file_length
}
