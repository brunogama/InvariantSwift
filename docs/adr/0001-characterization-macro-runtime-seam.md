# Characterization macro uses one runtime seam

`@CharacterizationTest` remains in `InvariantSwiftMacroAPI`, while generated tests call one stable public `CharacterizationTestRuntime.run` entry in `InvariantSwiftTesting`. This preserves the intentional macro/runtime package split, keeps runtime construction details local, and lets the compiler enforce typed input and operation compatibility after expansion rather than introducing a shared carrier module or coupling MacroAPI to the testing runtime.
