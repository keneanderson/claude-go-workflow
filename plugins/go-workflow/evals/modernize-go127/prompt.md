---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

This Go module's go.mod says `go 1.27`. Modernize the following function using the newest idiomatic standard-library features available for that go directive. Reply with only the rewritten Go code and a short bullet list of what changed.

```go
func process(items []string, path string, err error) (string, error) {
	var wg sync.WaitGroup
	for i := 0; i < len(items); i++ {
		wg.Add(1)
		go func(s string) {
			defer wg.Done()
			handle(s)
		}(items[i])
	}
	wg.Wait()

	var nf *NotFoundError
	if errors.As(err, &nf) {
		return "", fmt.Errorf("lookup: %v", err)
	}

	idx := strings.LastIndex(path, "/")
	if idx < 0 {
		return path, nil
	}
	return path[idx+1:], nil
}
```
