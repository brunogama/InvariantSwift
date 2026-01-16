import Foundation

// MARK: - Lens System for Functional Immutable Updates

/// A composable functional optic providing focused immutable access and updates to a part of a data structure.
///
/// A lens is a first-class abstraction that pairs a getter and setter for a particular field, enabling
/// functional updates of immutable data structures without mutation. Lenses satisfy three mathematical laws
/// that guarantee their correctness and composability.
///
/// **Lens Laws (Mathematical Foundation):**
///
/// 1. **Get-Put (Identity)**: `set(get(s), s) == s`
///    Setting a structure with the value you just got doesn't change anything.
///
/// 2. **Put-Get (Uniqueness)**: `get(set(v, s)) == v`
///    Getting after setting returns the value you set.
///
/// 3. **Put-Put (Transitivity)**: `set(v2, set(v1, s)) == set(v2, s)`
///    Setting twice is the same as setting the final value once.
///
/// These laws ensure lenses behave predictably and can be safely composed. For detailed mathematical
/// background, see:
/// - [Edward Kmett's Lens Library](https://github.com/ekmett/lens) - Comprehensive optics implementation
/// - [van Laarhoven Representation](https://www.twanvl.nl/blog/haskell/cps-functional-references) - Profunctor-based lenses
/// - [Lenses in Functional Programming](https://en.wikipedia.org/wiki/Lens_(computer_science))
///
/// **Composition Semantics:**
/// Lenses compose naturally using the ``>>>`` operator (forward composition), allowing you to focus
/// through multiple layers of nesting. Composition is associative: `(a >>> b) >>> c == a >>> (b >>> c)`.
///
/// **Performance Characteristics:**
/// - **Time**: O(1) for get and set operations (single function calls)
/// - **Space**: O(1) in addition to the data structure itself
/// - **Composition**: Composing two lenses creates a new lens with O(1) overhead
///
/// **Generic Parameters:**
///   - `Root`: The outer/parent type being focused into
///   - `Value`: The type of the focused field
///
/// **Thread Safety:**
/// Lenses are immutable and thread-safe. They create new root structures rather than mutating,
/// making them safe for concurrent use in actor-isolated code.
///
/// - Parameters:
///   - get: Function to extract the focused value from the root structure. Must be pure.
///   - set: Function to create a new root structure with the focused value updated.
///     Receives `(newValue, oldRoot)` and returns a new root with only the focused
///     field changed. Must not modify the input root.
///
/// - Example:
///   ```swift
///   // Define a simple record type
///   struct Address {
///       let street: String
///       let city: String
///   }
///
///   struct Person {
///       let name: String
///       let address: Address
///   }
///
///   // Create a lens focusing on a person's city
///   let personCityLens = Lens<Person, String>(
///       get: { person in person.address.city },
///       set: { newCity, person in
///           let newAddress = Address(street: person.address.street, city: newCity)
///           return Person(name: person.name, address: newAddress)
///       }
///   )
///
///   // Use the lens to immutably update the city
///   let alice = Person(name: "Alice", address: Address(street: "Main St", city: "NYC"))
///   let moved = personCityLens.set("Boston", alice)
///   assert(moved.address.city == "Boston")
///   assert(moved.name == "Alice")  // Other fields unchanged
///   ```
///
/// - Note: Important: Lenses are immutable and create new structures on updates.
///   For nested structures with many fields, consider using builder patterns or
///   copy-with-modifications syntax to reduce boilerplate. The ``copy(_:_:)``
///   utility function can help chain multiple lens updates ergonomically.
///
/// - See Also: ``Prism``, ``Traversal``, ``compose(_:_:)``, ``>>>(_:_:)``
public struct Lens<Root, Value>: Sendable {
  /// Extract the focused value from the root structure.
  ///
  /// This is the "view" operation in optics terminology. It's a pure function
  /// that should always return consistently for the same input.
  public let get: @Sendable (Root) -> Value

  /// Create a new root structure with the focused value updated.
  ///
  /// This is the "update" operation in optics terminology. It receives the new value
  /// and the old root, returning a new root with only the focused field changed.
  /// Must not modify the input root structure.
  public let set: @Sendable (Value, Root) -> Root

  /// Initialize a lens with get and set functions.
  ///
  /// When creating a custom lens, ensure it satisfies the three lens laws
  /// (Get-Put, Put-Get, Put-Put) to guarantee correct composition and updating semantics.
  ///
  /// - Parameters:
  ///   - get: Function to extract the focused value from root. Should be pure.
  ///   - set: Function to create a new root with the focused value updated.
  ///     Receives `(newValue, oldRoot)`. Must not mutate the input.
  public init(
    get: @escaping @Sendable (Root) -> Value,
    set: @escaping @Sendable (Value, Root) -> Root
  ) {
    self.get = get
    self.set = set
  }
}

// MARK: - Lens Operations

extension Lens {
  /// Apply a transformation function to the focused value.
  ///
  /// This is the "modify" operation in optics terminology. It extracts the focused value,
  /// applies a transformation, and sets the result back, all in a single composable operation.
  ///
  /// **Mathematical Property:**
  /// The `over` function implements the functor pattern for lenses, treating the focused
  /// value as if it were wrapped in a simple functor. Unlike ``set(_:_:)``, `over` preserves
  /// the structure's other fields unchanged.
  ///
  /// - Parameters:
  ///   - transform: Pure function to transform the focused value. Takes the current value
  ///     and returns the new value. Should have no side effects.
  ///
  /// - Returns: A function that takes a root structure and returns a new root with the
  ///   focused value transformed and all other fields unchanged.
  ///
  /// - Complexity: O(1) function overhead; actual complexity depends on the root structure's
  ///   copying cost (typically O(1) to O(n) depending on depth of nesting).
  ///
  /// - Example:
  ///   ```swift
  ///   struct Person { let age: Int }
  ///   let ageLens = Lens<Person, Int>(
  ///       get: { $0.age },
  ///       set: { age, person in Person(age: age) }
  ///   )
  ///
  ///   let person = Person(age: 30)
  ///   let birthday = ageLens.over { $0 + 1 }
  ///   let older = birthday(person)
  ///   assert(older.age == 31)
  ///   ```
  ///
  /// - Note: Important: `over` is more efficient than separately calling `get` and `set`
  ///   when you need both operations, as it ensures consistent semantics.
  ///
  /// - See Also: ``set(_:_:)``, ``view(_:)``
  public func over(_ transform: @escaping (Value) -> Value) -> (Root) -> Root {
    { root in
      let currentValue = self.get(root)
      let newValue = transform(currentValue)
      return self.set(newValue, root)
    }
  }

  /// Update the focused value to a new value in the root structure.
  ///
  /// Creates a new root structure with only the focused field changed to the new value.
  /// This is an ergonomic method-style wrapper around the underlying ``set`` function.
  ///
  /// - Parameters:
  ///   - newValue: The new value to assign to the focused field
  ///   - root: The root structure to update (not modified; a new structure is returned)
  ///
  /// - Returns: A new root structure with the focused field set to `newValue` and all
  ///   other fields unchanged.
  ///
  /// - Complexity: O(1) function overhead; actual complexity depends on structure copying.
  ///
  /// - Example:
  ///   ```swift
  ///   let oldPerson = Person(age: 30)
  ///   let newPerson = ageLens.set(31, oldPerson)
  ///   assert(newPerson.age == 31)
  ///   ```
  ///
  /// - See Also: ``over(_:)``
  public func set(_ newValue: Value, _ root: Root) -> Root {
    set(newValue, root)
  }

  /// Extract the focused value from the root structure.
  ///
  /// This is a convenience method for the ``get`` property, providing an alternative name
  /// that's common in optics libraries ("view" is used for the read operation).
  ///
  /// - Parameter root: The root structure to read from
  ///
  /// - Returns: The value of the focused field
  ///
  /// - Complexity: O(1) function overhead; actual complexity depends on field access cost.
  ///
  /// - Example:
  ///   ```swift
  ///   let person = Person(age: 30)
  ///   let currentAge = ageLens.view(person)
  ///   assert(currentAge == 30)
  ///   ```
  ///
  /// - See Also: ``get``
  public func view(_ root: Root) -> Value {
    get(root)
  }
}

// MARK: - Lens Composition

extension Lens {
  /// Compose this lens with another lens to focus deeper into nested structures.
  ///
  /// Lens composition is the primary mechanism for working with nested immutable data structures.
  /// When you have a lens focusing on `Value` and another lens focusing on `NewValue` (from `Value`),
  /// composing them creates a single lens that focuses on `NewValue` from `Root`.
  ///
  /// **Composition Laws (Mathematical):**
  ///
  /// 1. **Associativity**: `(a.compose(b)).compose(c) == a.compose(b.compose(c))`
  ///    Grouping doesn't matter when composing three or more lenses.
  ///
  /// 2. **Identity**: Composing with an identity lens has no effect (theoretical; practical implementation details vary)
  ///
  /// This enables building up complex navigation paths through deeply nested structures
  /// without intermediate variables or imperative-style updates.
  ///
  /// **Composition Semantics:**
  /// The composed lens's `get` extracts through both lenses sequentially. The `set` updates
  /// through both lenses, ensuring all intermediate structures are properly copied and updated.
  /// The three lens laws are preserved through composition (mathematical property).
  ///
  /// - Parameter other: A lens focusing on `NewValue` from the current lens's `Value` type.
  ///   The generic parameter is inferred automatically.
  ///
  /// - Returns: A new lens that focuses on `NewValue` from the original `Root` type,
  ///   with semantics equivalent to navigating through both lenses sequentially.
  ///
  /// - Complexity: O(1) to create the composed lens; O(1) to O(n) to use it (depends on
  ///   copying cost of intermediate structures).
  ///
  /// - Example:
  ///   ```swift
  ///   struct Company {
  ///       let name: String
  ///       let ceo: Person
  ///   }
  ///
  ///   // Lens for accessing the CEO
  ///   let companyCEO = Lens<Company, Person>(
  ///       get: { $0.ceo },
  ///       set: { ceo, company in Company(name: company.name, ceo: ceo) }
  ///   )
  ///
  ///   // Lens for accessing person's age
  ///   let personAge = Lens<Person, Int>(
  ///       get: { $0.age },
  ///       set: { age, person in Person(age: age) }
  ///   )
  ///
  ///   // Compose to access CEO's age
  ///   let ceoAge = companyCEO.compose(personAge)
  ///
  ///   let oldCEO = Person(age: 50)
  ///   let company = Company(name: "TechCorp", ceo: oldCEO)
  ///   let updated = ceoAge.set(51, company)
  ///   assert(updated.ceo.age == 51)
  ///   ```
  ///
  /// - Note: Prefer using the ``>>>(_:_:)`` operator over this method for typical usage,
  ///   as it reads more naturally (left-to-right).
  ///
  /// - See Also: ``>>>(_:_:)``, ``over(_:)``
  public func compose<NewValue>(_ other: Lens<Value, NewValue>) -> Lens<Root, NewValue> {
    Lens<Root, NewValue>(
      get: { root in
        let intermediate = self.get(root)
        return other.get(intermediate)
      },
      set: { newValue, root in
        let currentIntermediate = self.get(root)
        let newIntermediate = other.set(newValue, currentIntermediate)
        return self.set(newIntermediate, root)
      }
    )
  }
}

/// Compose two lenses using forward-composition syntax.
///
/// This operator composes two lenses in left-to-right order: `left >>> right` creates a lens
/// that applies `left` first, then `right`. This reads more naturally than the traditional
/// mathematical composition notation and aligns with function piping semantics.
///
/// **Operator Properties:**
/// - **Associativity**: Right-associative in Swift: `a >>> b >>> c == a >>> (b >>> c)`
/// - **Precedence**: Composes with the same precedence as other composition operators
/// - **Identity**: Composing with identity lens (theoretical) has no observable effect
///
/// This is the primary way to compose lenses in idiomatic Swift code.
///
/// - Parameters:
///   - left: The first lens, focusing on `Value` from `Root`
///   - right: The second lens, focusing on `NewValue` from `Value`
///
/// - Returns: A new lens focusing on `NewValue` from `Root`, equivalent to `left.compose(right)`
///
/// - Complexity: O(1) to create the composed lens
///
/// - Example:
///   ```swift
///   // Build a deep focus path through composition
///   let companyHeadquarters = companyCEO >>> personAddress >>> addressCity
///
///   let company = Company(...)
///   let newCompany = companyHeadquarters.set("San Francisco", company)
///   ```
///
/// - See Also: ``compose(_:)``, ``Lens``
public func >>> <Root, Value, NewValue>(
  left: Lens<Root, Value>,
  right: Lens<Value, NewValue>
) -> Lens<Root, NewValue> {
  left.compose(right)
}

// MARK: - Common Lens Patterns

extension Lens where Value: RangeReplaceableCollection {
  /// Lens for appending to a collection
  /// - Parameter element: Element to append
  /// - Returns: Function that appends to the focused collection
  public func append(_ element: Value.Element) -> (Root) -> Root {
    over { collection in
      var mutableCollection = collection
      mutableCollection.append(element)
      return mutableCollection
    }
  }

  /// Lens for prepending to a collection
  /// - Parameter element: Element to prepend
  /// - Returns: Function that prepends to the focused collection
  public func prepend(_ element: Value.Element) -> (Root) -> Root {
    over { collection in
      var mutableCollection = collection
      mutableCollection.insert(element, at: mutableCollection.startIndex)
      return mutableCollection
    }
  }
}

extension Lens where Value: BidirectionalCollection, Value: RangeReplaceableCollection {
  /// Remove the last element from a collection
  /// - Returns: Function that removes the last element
  public func removeLast() -> (Root) -> Root {
    over { collection in
      var mutableCollection = collection
      if !mutableCollection.isEmpty {
        mutableCollection.removeLast()
      }
      return mutableCollection
    }
  }
}

// MARK: - Lens Builders for Common Swift Types

extension Lens {
  /// Create a lens for a specific index in an array
  /// - Parameter index: The array index to focus on
  /// - Returns: Lens focused on the array element at index
  public static func index<Element>(_ index: Int) -> Lens<[Element], Element?>
  where Root == [Element], Value == Element? {
    Lens<[Element], Element?>(
      get: { array in
        array.indices.contains(index) ? array[index] : nil
      },
      set: { newElement, array in
        var mutableArray = array
        if let element = newElement, array.indices.contains(index) {
          mutableArray[index] = element
        }
        return mutableArray
      }
    )
  }

  /// Create a lens for a dictionary key
  /// - Parameter key: The dictionary key to focus on
  /// - Returns: Lens focused on the dictionary value for key
  public static func key<Key, DictValue>(_ key: Key) -> Lens<[Key: DictValue], DictValue?>
  where Root == [Key: DictValue], Value == DictValue?, Key: Sendable {
    Lens<[Key: DictValue], DictValue?>(
      get: { dict in dict[key] },
      set: { newValue, dict in
        var mutableDict = dict
        mutableDict[key] = newValue
        return mutableDict
      }
    )
  }
}

// MARK: - Prism (for Optional/Result handling)

/// A functional optic for focusing on one case of a sum type (like Optional or Result).
///
/// A prism is similar to a lens, but optimized for sum types where you want to focus on
/// one particular case. Unlike lenses (which always succeed), prism operations may fail
/// when the focused case doesn't match. Prisms pair a "preview" (fallible extract) with
/// a "review" (construct).
///
/// **Prism Laws (Mathematical Foundation):**
///
/// 1. **Preview-Review**: `preview(review(value)) == value`
///    Constructing and then viewing always gives you what you constructed.
///
/// 2. **Review-Preview**: For any root, if `preview(root) == value`, then `review(value) == root`
///    (assuming the prism is total for the reviewed case).
///
/// These laws ensure prisms compose correctly and maintain referential transparency.
/// For comprehensive mathematical background, see:
/// - [Prisms in Haskell Optics](https://hackage.haskell.org/package/lens/docs/Control-Lens-Prism.html)
/// - [Optics: Lenses and Prisms](https://www.schoolofhaskell.com/school/to-infinity-and-beyond/pick-of-the-week/a-little-lens-starter-tutorial)
/// - [Wikipedia: Algebraic Data Types](https://en.wikipedia.org/wiki/Algebraic_data_type)
///
/// **Comparison with Lenses:**
/// - **Lens**: Always succeeds; focuses on a required field
/// - **Prism**: May fail; focuses on one case of a sum type
/// - **Traversal**: Like a lens but for multiple focuses; like a prism for multiple cases
///
/// **Performance Characteristics:**
/// - **Time**: O(1) for preview and review operations
/// - **Space**: O(1) in addition to the returned structure
/// - **Composition**: Prisms compose with other prisms; composition is associative
///
/// **Generic Parameters:**
///   - `Root`: The sum type being focused (e.g., `Optional<T>`, `Result<Success, Failure>`)
///   - `Value`: The type of the focused case (e.g., `T`, `Success`)
///
/// - Parameters:
///   - preview: Fallible extract operation. Takes a root and returns the focused value
///     if the root matches this case, or nil if it matches a different case. Must be pure.
///   - review: Construct operation. Takes a value and builds a root of the focused case.
///     Must be pure and always succeed (never return nil).
///
/// - Example:
///   ```swift
///   // Define a custom sum type
///   enum Response {
///       case success(String)
///       case failure(Error)
///   }
///
///   // Create a prism focusing on the success case
///   let successPrism = Prism<Response, String>(
///       preview: { response in
///           switch response {
///           case .success(let value): return value
///           case .failure: return nil
///           }
///       },
///       review: { value in .success(value) }
///   )
///
///   // Use the prism
///   let response = Response.success("Hello")
///   let message = successPrism.preview(response)  // "Hello"
///
///   let newResponse = successPrism.review("World")  // Response.success("World")
///   ```
///
/// - Note: Important: Unlike lenses, prism operations are fallible (preview may return nil).
///   Use them when working with sum types like Optional, Result, or custom enums.
///   The built-in prisms ``Prism.some()``, ``Prism.success()``, and ``Prism.failure()``
///   provide convenient access to common cases.
///
/// - See Also: ``Lens``, ``Traversal``, ``Prism.some()``, ``Prism.success()``, ``Prism.failure()``
public struct Prism<Root, Value>: Sendable {
  /// Fallible extraction of the focused case from the root.
  ///
  /// This is the "preview" operation in optics terminology. Returns the focused value
  /// if the root matches this case, or nil otherwise.
  public let preview: @Sendable (Root) -> Value?

  /// Construct a root of the focused case from a value.
  ///
  /// This is the "review" operation in optics terminology. Always succeeds and creates
  /// a root of the focused case containing the given value.
  public let review: @Sendable (Value) -> Root

  /// Initialize a prism with preview and review functions.
  ///
  /// When creating a custom prism, ensure it satisfies the prism laws to guarantee
  /// correct composition and case handling semantics.
  ///
  /// - Parameters:
  ///   - preview: Fallible extract. Should be pure. Return nil for non-matching cases.
  ///   - review: Construct operation. Should be pure. Always succeeds.
  public init(
    preview: @escaping @Sendable (Root) -> Value?,
    review: @escaping @Sendable (Value) -> Root
  ) {
    self.preview = preview
    self.review = review
  }
}

extension Prism {
  /// Modify a value if it matches this prism
  /// - Parameter transform: Function to transform the value
  /// - Returns: Function that conditionally transforms the root
  public func over(_ transform: @escaping (Value) -> Value) -> (Root) -> Root {
    { root in
      if let value = self.preview(root) {
        return self.review(transform(value))
      }
      return root
    }
  }
}

// MARK: - Common Prisms

extension Prism {
  /// Prism for the Some case of an Optional
  public static func some<T>() -> Prism<T?, T> {
    Prism<T?, T>(
      preview: { $0 },
      review: { $0 }
    )
  }

  /// Prism for the success case of a Result
  public static func success<Success, Failure>() -> Prism<Result<Success, Failure>, Success> {
    Prism<Result<Success, Failure>, Success>(
      preview: { result in
        switch result {
        case .success(let value): return value
        case .failure: return nil
        }
      },
      review: { .success($0) }
    )
  }

  /// Prism for the failure case of a Result
  public static func failure<Success, Failure>() -> Prism<Result<Success, Failure>, Failure> {
    Prism<Result<Success, Failure>, Failure>(
      preview: { result in
        switch result {
        case .success: return nil
        case .failure(let error): return error
        }
      },
      review: { .failure($0) }
    )
  }
}

// MARK: - Traversal (for Collections)

/// A functional optic for focusing on zero or more elements within a structure.
///
/// A traversal generalizes lenses from single-element focus to multiple-element focus.
/// Where a lens focuses on exactly one field, a traversal can focus on zero, one, or many
/// elements (typically in a collection). Traversals are useful for batch updates across
/// collections while preserving the overall structure.
///
/// **Traversal Laws (Mathematical Foundation):**
///
/// Based on the `Traversable` functor from category theory, traversals satisfy:
///
/// 1. **Identity**: `traversal.over(identity) == identity`
///    Applying the identity function changes nothing.
///
/// 2. **Composition**: Composing two traversals maintains traversable structure
///    (mathematical property; implementation-dependent).
///
/// 3. **Structure Preservation**: The number of elements focused never changes; only
///    their values are transformed.
///
/// For detailed mathematical background, see:
/// - [Traversable Functors](https://en.wikipedia.org/wiki/Traversable_functor) - Category theory foundation
/// - [Traversals in Haskell Optics](https://hackage.haskell.org/package/lens/docs/Control-Lens-Traversal.html) - Comprehensive treatment
/// - [Applicative Functors](https://en.wikipedia.org/wiki/Applicative_functor) - Related to traversals
///
/// **Comparison with Other Optics:**
/// - **Lens**: Focuses on exactly 1 field; always succeeds
/// - **Prism**: Focuses on exactly 1 case; may fail
/// - **Traversal**: Focuses on 0+ elements; may all fail or partially succeed
///
/// **Performance Characteristics:**
/// - **Time**: O(n) for collections of size n; O(1) overhead per element
/// - **Space**: O(n) for collecting all focused values
/// - **Composition**: Traversals compose; composition is associative
///
/// **Generic Parameters:**
///   - `Root`: The overall structure being traversed
///   - `Value`: The type of focused elements; must be `Sendable` for concurrency safety
///
/// - Parameters:
///   - over: Transformation function. Takes a mapping function and returns a function
///     that traverses the structure, applying the mapping to each focused element.
///     Signature: `(Value -> Value) -> (Root -> Root)`
///   - toListOf: Extraction function. Takes a root and returns a list of all focused values.
///
/// - Example:
///   ```swift
///   // Define a traversal for array elements
///   let arrayTraversal = Traversal<[Int], Int>(
///       over: { transform in
///           { array in array.map(transform) }
///       },
///       toListOf: { $0 }
///   )
///
///   // Use the traversal to transform all elements
///   let numbers = [1, 2, 3, 4, 5]
///   let doubled = arrayTraversal.over { $0 * 2 }(numbers)
///   assert(doubled == [2, 4, 6, 8, 10])
///
///   // Extract all values
///   let values = arrayTraversal.toListOf(numbers)
///   assert(values == [1, 2, 3, 4, 5])
///   ```
///
/// - Note: Important: Traversals work with collections and apply the same transformation
///   to all focused elements. Use ``Traversal.each()`` for arrays, ``Traversal.values()``
///   for dictionaries. For custom structures, you need to provide both `over` and `toListOf`.
///
/// - See Also: ``Lens``, ``Prism``, ``Traversal.each()``, ``Traversal.values()``
public struct Traversal<Root, Value>: Sendable where Value: Sendable {
  /// Transform all focused elements in the structure.
  ///
  /// This operation applies a transformation function to each focused element while
  /// preserving the overall structure. The result is a function that takes a root
  /// and returns a new root with all focused elements transformed.
  public let over: @Sendable (@escaping @Sendable (Value) -> Value) -> @Sendable (Root) -> Root

  /// Extract all focused elements as a list.
  ///
  /// This operation collects all focused values from the structure into a list.
  /// May return an empty list if the structure contains no focused elements.
  public let toListOf: @Sendable (Root) -> [Value]

  /// Initialize a traversal with transformation and extraction operations.
  ///
  /// When creating a custom traversal, ensure:
  /// - `over` applies the function to all focused elements
  /// - `toListOf` returns all focused values in consistent order
  /// - Both operations maintain structure preservation
  ///
  /// - Parameters:
  ///   - over: Transformation function with type `(Value -> Value) -> (Root -> Root)`
  ///   - toListOf: Extraction function with type `(Root) -> [Value]`
  public init(
    over: @escaping @Sendable (@escaping @Sendable (Value) -> Value) -> @Sendable (Root) -> Root,
    toListOf: @escaping @Sendable (Root) -> [Value]
  ) {
    self.over = over
    self.toListOf = toListOf
  }
}

extension Traversal {
  /// Set all focused values to a specific value
  /// - Parameter newValue: The value to set all focuses to
  /// - Returns: Function that sets all focused values
  public func set(_ newValue: Value) -> (Root) -> Root {
    over { _ in newValue }
  }
}

// MARK: - Common Traversals

extension Traversal {
  /// Traversal for all elements in an array
  public static func each<Element>() -> Traversal<[Element], Element> {
    Traversal<[Element], Element>(
      over: { transform in
        { array in array.map(transform) }
      },
      toListOf: { $0 }
    )
  }

  /// Traversal for dictionary values
  public static func values<Key, DictValue>() -> Traversal<[Key: DictValue], DictValue>
  where Key: Sendable, DictValue: Sendable {
    Traversal<[Key: DictValue], DictValue>(
      over: { transform in
        { dict in
          dict.mapValues(transform)
        }
      },
      toListOf: { dict in Array(dict.values) }
    )
  }
}

// MARK: - Functional Setters Integration

/// **Functional Setter Utilities**
///
/// These utilities provide ergonomic ways to perform immutable updates
/// using the lens system, making it easy to update nested structures
/// without verbose boilerplate code.

/// Apply multiple lens-based transformations to a value in a single expression.
///
/// This function provides ergonomic chaining of lens updates without intermediate variables
/// or nested function calls. It's particularly useful for updating multiple fields in
/// immutable structures where you want to avoid boilerplate.
///
/// **Use Case:**
/// When working with immutable data structures, updating multiple fields typically requires
/// nested function calls or intermediate variables. The `copy` function allows you to apply
/// a sequence of lens-based updates in a clean, readable way.
///
/// **Application Semantics:**
/// Updates are applied left-to-right, with each update receiving the result of the previous
/// update. This is equivalent to composing the update functions with function composition.
///
/// - Parameters:
///   - value: The original value to update (not modified; immutable)
///   - updates: Variadic list of transformation functions, typically created from lens operations
///     like ``Lens.over(_:)``. Each function takes the accumulated value and returns an updated value.
///
/// - Returns: A new value with all updates applied sequentially. The original `value` is unchanged.
///
/// - Complexity: O(k) where k is the number of updates; each update's cost depends on the
///   lens operation being performed.
///
/// - Example:
///   ```swift
///   struct Person {
///       let name: String
///       let age: Int
///   }
///
///   // Define some lenses
///   let personAge = Lens<Person, Int>(
///       get: { $0.age },
///       set: { age, person in Person(name: person.name, age: age) }
///   )
///
///   // Apply multiple updates with copy
///   let person = Person(name: "Alice", age: 30)
///   let updated = copy(
///       person,
///       personAge.over { $0 + 1 },     // First update: increment age
///       personAge.over { $0 * 2 }      // Second update: double age
///   )
///   assert(updated.age == 62)  // (30 + 1) * 2 = 62
///   ```
///
/// - Note: Important: Updates are applied in order (left-to-right). If multiple updates
///   focus on the same field, the rightmost update takes precedence. This is generally
///   avoided in practice; use a single lens update for a single field instead of multiple.
///
/// - See Also: ``Lens``, ``Lens.over(_:)``
public func copy<T>(_ value: T, _ updates: ((T) -> T)...) -> T {
  updates.reduce(value) { result, update in
    update(result)
  }
}

// Operator definitions available in FunctionComposition.swift
