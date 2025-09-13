import Foundation

// MARK: - Lens System for Functional Immutable Updates

/// **Lens System Implementation**
///
/// A lens is a functional programming concept that provides a composable way to focus on
/// a particular part of a data structure for getting and setting values immutably.
/// Lenses follow the lens laws and enable elegant functional updates of nested structures.
///
/// **Mathematical Foundation:**
/// - **Get-Put Law**: `set(get(s), s) = s` - Setting what you get doesn't change anything
/// - **Put-Get Law**: `get(set(v, s)) = v` - Getting what you set gives you what you set
/// - **Put-Put Law**: `set(v2, set(v1, s)) = set(v2, s)` - Setting twice is same as setting once
///
/// **External References:**
/// - [Lenses in Functional Programming](https://en.wikipedia.org/wiki/Lens_(computer_science))
/// - [Lens Laws - Haskell Wiki](https://wiki.haskell.org/Lens)
/// - [van Laarhoven Lenses](https://www.twanvl.nl/blog/haskell/cps-functional-references)
///
/// **Example Usage:**
/// ```swift
/// struct Person {
///     let name: String
///     let address: Address
/// }
///
/// struct Address {
///     let street: String
///     let city: String
/// }
///
/// let personNameLens = Lens<Person, String>(
///     get: { $0.name },
///     set: { newName, person in Person(name: newName, address: person.address) }
/// )
///
/// let addressCityLens = Lens<Address, String>(
///     get: { $0.city },
///     set: { newCity, address in Address(street: address.street, city: newCity) }
/// )
///
/// // Compose lenses to access nested properties
/// let personCityLens = personNameLens >>> addressCityLens
///
/// let person = Person(name: "Alice", address: Address(street: "Main St", city: "NYC"))
/// let updatedPerson = personCityLens.set("Boston", person)
/// ```
public struct Lens<Root, Value>: Sendable {
  /// Extract a value from the root structure
  public let get: @Sendable (Root) -> Value

  /// Create a new root structure with the value updated
  public let set: @Sendable (Value, Root) -> Root

  /// Initialize a lens with get and set functions
  /// - Parameters:
  ///   - get: Function to extract value from root
  ///   - set: Function to create new root with updated value
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
  /// Update a value using a transformation function
  /// - Parameters:
  ///   - transform: Function to transform the current value
  ///   - root: The root structure to update
  /// - Returns: New root structure with transformed value
  public func over(_ transform: @escaping (Value) -> Value) -> (Root) -> Root {
    { root in
      let currentValue = self.get(root)
      let newValue = transform(currentValue)
      return self.set(newValue, root)
    }
  }

  /// Set a specific value in the root structure
  /// - Parameters:
  ///   - newValue: The new value to set
  ///   - root: The root structure to update
  /// - Returns: New root structure with the value set
  public func set(_ newValue: Value, _ root: Root) -> Root {
    set(newValue, root)
  }

  /// View/get a value from the root structure
  /// - Parameter root: The root structure to read from
  /// - Returns: The focused value
  public func view(_ root: Root) -> Value {
    get(root)
  }
}

// MARK: - Lens Composition

extension Lens {
  /// Compose two lenses to create a lens that focuses deeper into a structure
  /// - Parameter other: Another lens to compose with
  /// - Returns: A composed lens that can focus on nested values
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

/// Operator for lens composition (functional composition style)
/// - Parameters:
///   - left: First lens
///   - right: Second lens to compose with
/// - Returns: Composed lens
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
  public static func key<Key: Sendable, DictValue>(_ key: Key) -> Lens<[Key: DictValue], DictValue?>
  where Root == [Key: DictValue], Value == DictValue? {
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

/// **Prism for Optional and Sum Type Handling**
///
/// A prism is a first-class pattern for working with sum types (like Optional and Result).
/// It provides a way to focus on one case of a sum type, with the ability to extract
/// the associated value or construct the sum type from a value.
///
/// **Mathematical Foundation:**
/// - **Prism Laws**: Similar to lens laws but for sum types
/// - **Preview-Review Law**: `preview(review(value)) = some(value)`
/// - **Review-Preview Law**: For valid cases, reviewing after previewing gives identity
///
/// **External References:**
/// - [Prisms in Functional Programming](https://hackage.haskell.org/package/lens/docs/Control-Lens-Prism.html)
/// - [Optics: Lenses and Prisms](https://www.schoolofhaskell.com/school/to-infinity-and-beyond/pick-of-the-week/a-little-lens-starter-tutorial)
public struct Prism<Root, Value>: Sendable {
  /// Try to extract a value from the root (may fail)
  public let preview: @Sendable (Root) -> Value?

  /// Construct a root from a value
  public let review: @Sendable (Value) -> Root

  /// Initialize a prism with preview and review functions
  /// - Parameters:
  ///   - preview: Function to try extracting value from root
  ///   - review: Function to construct root from value
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

/// **Traversal for Collection Handling**
///
/// A traversal generalizes lenses to work with multiple focuses simultaneously.
/// It's particularly useful for working with collections where you want to update
/// all elements or a subset of elements.
///
/// **Mathematical Foundation:**
/// - Based on the Traversable functor concept from category theory
/// - Maintains the structure while allowing element-wise transformations
/// - Preserves collection laws and maintains referential transparency
///
/// **External References:**
/// - [Traversable Functors](https://en.wikipedia.org/wiki/Traversable_functor)
/// - [Traversals in Optics](https://hackage.haskell.org/package/lens/docs/Control-Lens-Traversal.html)
public struct Traversal<Root, Value>: Sendable where Root: Sendable, Value: Sendable {
  /// Transform all focused values in the structure
  public let over: @Sendable (@escaping @Sendable (Value) -> Value) -> @Sendable (Root) -> Root

  /// Extract all focused values from the structure
  public let toListOf: @Sendable (Root) -> [Value]

  /// Initialize a traversal
  /// - Parameters:
  ///   - over: Function to transform all focused values
  ///   - toListOf: Function to extract all focused values
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
  public static func values<Key, DictValue>() -> Traversal<[Key: DictValue], DictValue> {
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

/// Copy a value while updating specific properties using lenses
/// - Parameters:
///   - value: The original value to copy
///   - updates: Variadic list of lens-based updates
/// - Returns: New value with updates applied
public func copy<T>(_ value: T, _ updates: ((T) -> T)...) -> T {
  updates.reduce(value) { result, update in
    update(result)
  }
}

// Note: Functional composition operators (|>, •, >>>) are defined in FunctionComposition.swift
// to avoid duplicate definitions across modules
