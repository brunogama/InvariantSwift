import Foundation

// MARK: - Function Composition and Higher-Order Function Utilities

// swiftlint:disable:next orphaned_doc_comment
/// **Function Composition Utilities**
///
/// This module provides a comprehensive set of higher-order functions for functional
/// programming patterns, including function composition, currying, partial application,
/// and various combinators that enhance code expressiveness and reusability.
///
/// **Mathematical Foundation:**
/// - Based on lambda calculus and combinatory logic
/// - Follows associative and identity laws for composition
/// - Implements combinators from SKI calculus and fixed-point theory
///
/// **External References:**
/// - [Combinatory Logic - Wikipedia](https://en.wikipedia.org/wiki/Combinatory_logic)
/// - [Lambda Calculus](https://en.wikipedia.org/wiki/Lambda_calculus)
/// - [Fixed-point Combinator](https://en.wikipedia.org/wiki/Fixed-point_combinator)
/// - [Function Composition](https://en.wikipedia.org/wiki/Function_composition)

// MARK: - Core Composition Functions

/// **Function Composition (Mathematical)**
/// Compose two functions: (g ∘ f)(x) = g(f(x))
///
/// **Laws:**
/// - **Associativity**: `(h • g) • f = h • (g • f)`
/// - **Identity**: `id • f = f • id = f`
///
/// - Parameters:
///   - g: Second function to apply (outer)
///   - f: First function to apply (inner)
/// - Returns: Composed function g(f(x))
public func compose<A, B, C>(_ g: @escaping (B) -> C, _ f: @escaping (A) -> B) -> (A) -> C {
  { a in g(f(a)) }
}

/// **Forward Composition (Pipeline)**
/// Compose functions in left-to-right order: (f >>> g)(x) = g(f(x))
///
/// - Parameters:
///   - f: First function to apply
///   - g: Second function to apply
/// - Returns: Composed function g(f(x))
public func pipe<A, B, C>(_ f: @escaping (A) -> B, _ g: @escaping (B) -> C) -> (A) -> C {
  { a in g(f(a)) }
}

/// **Identity Function**
/// Returns its input unchanged: id(x) = x
///
/// **Mathematical Property:**
/// - **Identity Law**: For any function f, `compose(id, f) = f` and `compose(f, id) = f`
///
/// - Parameter x: Input value
/// - Returns: The same input value unchanged
public func identity<T>(_ x: T) -> T {
  x
}

/// **Constant Function**
/// Always returns the same value regardless of input: const(k)(x) = k
///
/// - Parameter value: The constant value to always return
/// - Returns: Function that ignores input and returns the constant
public func constant<A, B>(_ value: B) -> (A) -> B {
  { _ in value }
}

// MARK: - Currying and Partial Application

/// **Curry a binary function**
/// Transform f(a, b) into f(a)(b)
///
/// **Mathematical Foundation:**
/// - Based on Haskell Curry's work in combinatory logic
/// - Enables partial application and function specialization
/// - Establishes isomorphism between A × B → C and A → B → C
///
/// - Parameter f: Binary function to curry
/// - Returns: Curried function
public func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C {
  { a in { b in f(a, b) } }
}

/// **Uncurry a curried function**
/// Transform f(a)(b) into f(a, b)
///
/// - Parameter f: Curried function to uncurry
/// - Returns: Binary function
public func uncurry<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (A, B) -> C {
  { a, b in f(a)(b) }
}

/// **Curry a ternary function**
/// Transform f(a, b, c) into f(a)(b)(c)
///
/// - Parameter f: Ternary function to curry
/// - Returns: Curried function
public func curry<A, B, C, D>(_ f: @escaping (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
  { a in { b in { c in f(a, b, c) } } }
}

/// **Partial application for binary functions**
/// Fix the first argument of a binary function
///
/// - Parameters:
///   - f: Binary function
///   - a: First argument to fix
/// - Returns: Unary function with first argument applied
public func partial<A, B, C>(_ f: @escaping (A, B) -> C, _ a: A) -> (B) -> C {
  { b in f(a, b) }
}

/// **Flip the arguments of a binary function**
/// Transform f(a, b) into f(b, a)
///
/// - Parameter f: Binary function to flip
/// - Returns: Function with arguments flipped
public func flip<A, B, C>(_ f: @escaping (A, B) -> C) -> (B, A) -> C {
  { b, a in f(a, b) }
}

// MARK: - Combinators

/// **S Combinator (Substitution)**
/// S(f)(g)(x) = f(x)(g(x))
/// Applies two functions to the same input and then applies the first result to the second
///
/// **Mathematical Foundation:**
/// - Part of SKI combinator calculus
/// - S, K, I combinators form a complete basis for computation
/// - Enables duplication of computation paths
///
/// - Parameters:
///   - f: Function that returns another function
///   - g: Function to apply to input
/// - Returns: Combined function
public func S<A, B, C>(_ f: @escaping (A) -> (B) -> C, _ g: @escaping (A) -> B) -> (A) -> C {
  { a in f(a)(g(a)) }
}

/// **K Combinator (Constant)**
/// K(x)(y) = x
/// Always returns the first argument, ignoring the second
///
/// - Parameter x: Value to return
/// - Returns: Function that ignores its input and returns x
public func K<A, B>(_ x: A) -> (B) -> A {
  constant(x)
}

/// **I Combinator (Identity)**
/// I(x) = x
/// Returns its argument unchanged
///
/// - Parameter x: Input value
/// - Returns: The same input value
public func I<A>(_ x: A) -> A {
  identity(x)
}

/// **Y Combinator (Fixed Point)**
/// Enables recursion in lambda calculus without explicit recursion
///
/// **Mathematical Foundation:**
/// - Fixed-point combinator: Y(f) = f(Y(f))
/// - Enables definition of recursive functions in pure lambda calculus
/// - Based on Curry's paradox and Church's lambda calculus
///
/// **Note:** Swift's strict evaluation requires a lazy wrapper
///
/// - Parameter f: Function to find fixed point for
/// - Returns: Fixed point of f
public func Y<A>(_ f: @escaping ((A) -> A) -> (A) -> A) -> (A) -> A {
  { a in f(Y(f))(a) }
}

/// **Lazy Y Combinator**
/// Y combinator implementation that works with Swift's strict evaluation
///
/// - Parameter f: Function to find fixed point for
/// - Returns: Fixed point of f
public func lazyY<A>(_ f: @escaping (@escaping (A) -> A) -> (A) -> A) -> (A) -> A {
  // Simplified implementation to avoid Swift's type system complexity
  var result: ((A) -> A)!
  result = { a in
    f(result)(a)
  }
  return result
}

// MARK: - Function Transformation Utilities

/// **Memoization**
/// Cache function results for expensive computations
///
/// **Note:** Only use with pure functions (no side effects)
///
/// - Parameter f: Pure function to memoize
/// - Returns: Memoized version of the function
public func memoize<Input: Hashable, Output>(_ f: @escaping (Input) -> Output) -> (Input) -> Output
{
  var cache: [Input: Output] = [:]
  return { input in
    if let cached = cache[input] {
      return cached
    }
    let result = f(input)
    cache[input] = result
    return result
  }
}

/// **Function Timing**
/// Measure execution time of a function
///
/// - Parameter f: Function to time
/// - Returns: Tuple of (result, execution_time_in_seconds)
public func time<A, B>(_ f: @escaping (A) -> B) -> (A) -> (B, TimeInterval) {
  { a in
    let startTime = CFAbsoluteTimeGetCurrent()
    let result = f(a)
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    return (result, timeElapsed)
  }
}

/// **Throttle function execution**
/// Limit how often a function can be called
///
/// - Parameters:
///   - f: Function to throttle
///   - interval: Minimum time interval between calls
/// - Returns: Throttled function
public func throttle<A, B>(_ f: @escaping (A) -> B, interval: TimeInterval) -> (A) -> B? {
  var lastCallTime: CFAbsoluteTime = 0
  return { a in
    let currentTime = CFAbsoluteTimeGetCurrent()
    guard currentTime - lastCallTime >= interval else {
      return nil
    }
    lastCallTime = currentTime
    return f(a)
  }
}

/// **Debounce function execution**
/// Delay function execution until after calls have stopped
///
/// **Note:** This implementation is simplified for synchronous contexts
/// For full async debouncing, use with Task and actors
///
/// - Parameters:
///   - f: Function to debounce
///   - delay: Delay after last call before execution
/// - Returns: Debounced function wrapper
public func debounce<A, B>(_ f: @escaping (A) -> B, delay: TimeInterval) -> (A) -> Void {
  var workItem: DispatchWorkItem?
  return { a in
    workItem?.cancel()
    workItem = DispatchWorkItem {
      _ = f(a)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
  }
}

// MARK: - Error Handling Combinators

/// **Try combinator for error handling**
/// Apply a function that might throw, returning a Result
///
/// - Parameter f: Throwing function to wrap
/// - Returns: Function that returns Result instead of throwing
public func tryF<A, B>(_ f: @escaping (A) throws -> B) -> (A) -> Result<B, Error> {
  { a in
    do {
      return .success(try f(a))
    } catch {
      return .failure(error)
    }
  }
}

/// **Rescue combinator**
/// Provide a fallback function for error cases
///
/// - Parameters:
///   - f: Primary function that might fail
///   - rescue: Fallback function for errors
/// - Returns: Function that always succeeds by using fallback
public func rescue<A, B>(
  _ f: @escaping (A) -> Result<B, Error>,
  _ rescue: @escaping (Error) -> B
) -> (A) -> B {
  { a in
    switch f(a) {
    case .success(let value):
      return value

    case .failure(let error):
      return rescue(error)
    }
  }
}

// MARK: - Collection Combinators

/// **Map with index**
/// Transform elements with access to their index
///
/// - Parameter f: Transform function receiving (index, element)
/// - Returns: Function that maps over collections with index
public func mapWithIndex<A, B>(_ f: @escaping (Int, A) -> B) -> ([A]) -> [B] {
  { array in
    array.enumerated().map { index, element in
      f(index, element)
    }
  }
}

/// **Filter with index**
/// Filter elements with access to their index
///
/// - Parameter predicate: Predicate function receiving (index, element)
/// - Returns: Function that filters collections with index
public func filterWithIndex<A>(_ predicate: @escaping (Int, A) -> Bool) -> ([A]) -> [A] {
  { array in
    array.enumerated().compactMap { index, element in
      predicate(index, element) ? element : nil
    }
  }
}

/// **Reduce with index**
/// Reduce collection with access to index
///
/// - Parameters:
///   - initial: Initial accumulator value
///   - f: Reducer function receiving (accumulator, index, element)
/// - Returns: Function that reduces collections with index access
public func reduceWithIndex<A, B>(_ initial: B, _ f: @escaping (B, Int, A) -> B) -> ([A]) -> B {
  { array in
    array.enumerated().reduce(initial) { acc, pair in
      f(acc, pair.offset, pair.element)
    }
  }
}

// MARK: - Operator Definitions

infix operator • : MultiplicationPrecedence  // Function composition (mathematical)
infix operator >>> : MultiplicationPrecedence  // Forward composition (pipeline)
infix operator |> : ApplyPrecedence  // Pipe operator

// swiftlint:disable:next orphaned_doc_comment
/// **Function composition operator (mathematical style)**
/// Compose two functions: g • f = λx. g(f(x))
// swiftlint:disable:next static_operator
public func • <A, B, C>(g: @escaping (B) -> C, f: @escaping (A) -> B) -> (A) -> C {
  compose(g, f)
}

// swiftlint:disable:next orphaned_doc_comment
/// **Forward composition operator (pipeline style)**
/// Chain functions left-to-right: f >>> g = λx. g(f(x))
// swiftlint:disable:next static_operator
public func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) -> C) -> (A) -> C {
  pipe(f, g)
}

// swiftlint:disable:next orphaned_doc_comment
/// **Pipe operator**
/// Apply a function to a value: x |> f = f(x)
// swiftlint:disable:next static_operator
public func |> <A, B>(value: A, f: (A) -> B) -> B {
  f(value)
}

// MARK: - Precedence Groups

precedencegroup ApplyPrecedence {
  associativity: left
  higherThan: AssignmentPrecedence
  lowerThan: TernaryPrecedence
}

// MARK: - Type Aliases for Common Patterns

/// **Predicate type alias**
/// Represents functions that return boolean values
public typealias Predicate<T> = (T) -> Bool

/// **Transform type alias**
/// Represents functions that transform one type to another
public typealias Transform<A, B> = (A) -> B

/// **Endomorphism type alias**
/// Represents functions from a type to itself
public typealias Endomorphism<T> = (T) -> T

/// **Effect type alias**
/// Represents functions that perform side effects
public typealias Effect<T> = (T) -> Void

/// **Thunk type alias**
/// Represents parameterless functions (lazy computation)
public typealias Thunk<T> = () -> T

// MARK: - Utility Functions for Common Patterns

/// **Apply function multiple times**
/// Apply an endomorphism n times: applyN(3)(f)(x) = f(f(f(x)))
///
/// - Parameter n: Number of times to apply the function
/// - Returns: Function that applies the input function n times
public func applyN<T>(_ n: Int) -> (@escaping Endomorphism<T>) -> Endomorphism<T> {
  { f in
    { initial in
      (0..<n).reduce(initial) { result, _ in f(result) }
    }
  }
}

/// **Until combinator**
/// Apply function until predicate is true
///
/// - Parameters:
///   - predicate: Condition to check
///   - f: Function to apply
/// - Returns: Function that applies f until predicate is satisfied
public func until<T>(
  _ predicate: @escaping Predicate<T>,
  _ f: @escaping Endomorphism<T>
) -> Endomorphism<T> {
  { initial in
    var result = initial
    while !predicate(result) {
      result = f(result)
    }
    return result
  }
}

/// **While combinator**
/// Apply function while predicate is true
///
/// - Parameters:
///   - predicate: Condition to check
///   - f: Function to apply
/// - Returns: Function that applies f while predicate is satisfied
public func while_<T>(
  _ predicate: @escaping Predicate<T>,
  _ f: @escaping Endomorphism<T>
) -> Endomorphism<T> {
  { initial in
    var result = initial
    while predicate(result) {
      result = f(result)
    }
    return result
  }
}
