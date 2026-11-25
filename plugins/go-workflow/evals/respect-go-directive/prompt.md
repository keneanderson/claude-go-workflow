---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

This Go module's go.mod says `go 1.21` and must stay on that version (we cannot upgrade). Modernize the following code where it is safe for that go directive. Reply with only the rewritten Go code and a short bullet list explaining which modern features you used and which you deliberately avoided because of the go directive.

```go
func top(values []int, n int) []int {
	out := []int{}
	for i := 0; i < n; i++ {
		out = append(out, values[i])
	}
	sort.Slice(out, func(a, b int) bool { return out[a] < out[b] })
	var wg sync.WaitGroup
	for _, v := range out {
		v := v
		wg.Add(1)
		go func() { defer wg.Done(); report(v) }()
	}
	wg.Wait()
	return out
}
```
