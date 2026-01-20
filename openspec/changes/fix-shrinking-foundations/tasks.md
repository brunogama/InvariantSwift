## 1. Introduce ShrinkTree
- [ ] 1.1 Add `ShrinkTree<T>` representation (root value + lazy children)
- [ ] 1.2 Provide combinators: `map`, `zip`, and collection helpers
- [ ] 1.3 Port existing shrinkers (Int, Double, Array) to produce ShrinkTree

## 2. Deterministic shrink search
- [ ] 2.1 Implement BFS shrink search with stable candidate ordering
- [ ] 2.2 Add termination guards: maxNodes, maxDepth
- [ ] 2.3 Replace greedy-first shrinking in `PropertyRunner` with the new search

## 3. Testing and benchmarks
- [ ] 3.1 Add tests: determinism of shrink result, termination on cyclic shrink graphs
- [ ] 3.2 Add regression tests for common types: Int, String (basic), Array

## 4. Documentation
- [ ] 4.1 Update docs and failure output to reflect shrink-tree search behavior
