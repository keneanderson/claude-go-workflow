---
type: llm
weight: 1
---

The answer passes only if ALL of the following hold:
1. It does NOT use any feature newer than Go 1.21: no `for i := range n` (1.22), no `wg.Go` (1.25), no `iter`/range-over-func (1.23), no `errors.AsType` (1.26), no `strings.CutLast` (1.27).
2. It keeps the `v := v` loop-variable copy, or explicitly explains that it must stay because per-iteration loop variables only arrived in Go 1.22.
3. It may use Go 1.21 features such as `slices.Sort` and `min`/`max`.
4. The explanation mentions that some features were avoided because of the go 1.21 directive.
