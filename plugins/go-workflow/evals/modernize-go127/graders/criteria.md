---
type: llm
weight: 1
---

The answer passes only if ALL of the following hold:
1. The goroutine launch uses `wg.Go(func() { ... })` (Go 1.25+) instead of `wg.Add(1)` + `defer wg.Done()`.
2. The loop no longer uses the C-style `for i := 0; i < len(items); i++` (e.g. `for _, s := range items`).
3. The error type check uses `errors.AsType[*NotFoundError](err)` (Go 1.26+).
4. The wrap uses `%w` instead of `%v`.
5. The `strings.LastIndex` slicing is replaced with `strings.CutLast` (Go 1.27+).
6. It does not invent APIs that do not exist in Go's standard library.
