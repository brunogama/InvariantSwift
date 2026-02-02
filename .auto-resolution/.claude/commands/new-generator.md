Create a new generator type: $ARGUMENTS

## Steps

1. **Create Generator File**
   
   Location: `Sources/InvariantSwift/Generators/$ARGUMENTSGenerator.swift`

2. **Follow Generator Pattern**

   ```swift
   // See: Core/Generator.swift for the base pattern
   import Foundation

   extension Gen where T == $ARGUMENTS {
     /// Generates a random $ARGUMENTS.
     ///
     /// - Returns: A generator that produces $ARGUMENTS values
     public static var $arguments: Gen<$ARGUMENTS> {
       Gen { rng, size in
         // Implementation here
       } shrink: { value in
         // Shrink implementation
         []
       }
     }
   }
   ```

3. **Add Shrink Strategy**

   ```swift
   // See: Core/Generator.swift (lines 95-512) for shrink patterns
   Shrink<$ARGUMENTS> { value in
     // Return smaller/simpler values
     // Must eventually return [] to prevent infinite loops
   }
   ```

4. **Export in FunctionalTesting.swift**

   Add export if needed for public API.

5. **Create Tests**

   Location: `Tests/FunctionalTesting/$ARGUMENTSGeneratorTests.swift`

   ```swift
   import Testing
   @testable import InvariantSwift

   @Suite("$ARGUMENTS Generator Tests")
   struct $ARGUMENTSGeneratorTests {
     
     @Test("generates valid values")
     func generatesValidValues() {
       let gen = Gen<$ARGUMENTS>.$arguments
       let seed = Seed(value: 42)
       let value = gen.sample(size: .medium, seed: seed)
       // Assertions
     }
     
     @Test("same seed produces same output")
     func determinism() {
       let gen = Gen<$ARGUMENTS>.$arguments
       let seed = Seed(value: 12345)
       let v1 = gen.sample(size: .medium, seed: seed)
       let v2 = gen.sample(size: .medium, seed: seed)
       #expect(v1 == v2)
     }
   }
   ```

6. **Run Tests**

   ```bash
   swift test --filter "$ARGUMENTSGeneratorTests"
   ```

## Checklist

- [ ] Generator uses `@unchecked Sendable` if capturing closures
- [ ] Size parameter passed through for recursive generators
- [ ] Shrink function eventually returns `[]`
- [ ] Same Seed + Size produces same value (deterministic)
- [ ] Tests cover edge cases
- [ ] DocC comments on public API
