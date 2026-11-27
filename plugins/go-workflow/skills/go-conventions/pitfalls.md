# Common Go pitfalls (flag them when found in review)

Patterns that linters rarely catch and that review should pick up. Only consider those included in the diff.

## Errors
| Pattern | Problem |
|---------|---------|
| `v, _ := f()` (discarding err) | Failures are silently ignored |
| `fmt.Errorf("...: %v", err)` | `%v` breaks the error chain, so `errors.Is/As` stop working. Use `%w` |
| `x, err := ...` in an inner scope | Shadows the outer `err`, so the outer one is returned as nil |
| `var e *MyErr; return e` (return type `error`) | A typed nil goes into the interface and `err != nil` is true |
| No `return` after `http.Error(w, ...)` | The handler keeps running |
| `log.Fatal` / `os.Exit` while a `defer` is pending | The process ends without running the defers |
| `rows, _ := db.Query(...)` without Close / not checking `rows.Err()` | Connection leak / errors in the middle are missed |

## Concurrency
| Pattern | Problem |
|---------|---------|
| `go func() { ... }()` without a context | Cannot be stopped, so it leaks |
| `wg.Add(1)` inside the goroutine | Race where `Wait()` returns first. Use `wg.Go` or Add before starting |
| Value receivers / value copies of structs containing `sync.Mutex` and the like | The lock is copied and protects nothing |
| A shared map without a mutex | Data race (fails under `-race`, fatal error in production) |
| Sending after `close(ch)`, closing on the receiver side | panic. Only the sender closes |
| `select { default: }` inside a loop | A busy loop that never blocks and burns CPU |
| `time.After` in a hot loop | Creates a timer every time. Use `time.NewTimer` + `Reset` |

## Values and types
| Pattern | Problem |
|---------|---------|
| Narrowing conversions of large integers such as `int32(x)` | Silent overflow. Needs a range check |
| `t1 == t2` (`time.Time`) | Mismatches due to the monotonic clock or location. Use `t1.Equal(t2)` |
| `strings.Trim(s, "prefix")` | Removes a set of characters, not a substring. Use `strings.TrimPrefix` |
| Enums with `iota` starting at 0 | The zero value cannot be told apart from the first value. Put something like `Unknown = iota` first |
| Returning a slice that the caller appends to | Shares and overwrites the underlying array. Use `slices.Clone` if needed |
| Writing to a nil map | panic. Initialize with `make` |
| `fallthrough` in a `switch` | Runs the next case unconditionally |

## HTTP, I/O and paths
| Pattern | Problem |
|---------|---------|
| `http.Get` / `http.DefaultClient` | No timeout |
| Not closing / not draining `resp.Body` | The connection is not reused and leaks |
| `filepath.Join(base, userInput)` | Does not prevent path traversal via `../`. Use `os.Root` or `filepath.IsLocal` |
| `regexp.MustCompile` inside a handler | Compiles on every request. Move it to a package variable |

## Performance
| Pattern | Problem |
|---------|---------|
| `defer` in a hot loop | Piles up until the function returns |
| String `+=` in a loop | Use `strings.Builder` |
| Appending to a slice whose length is known | Preallocate with `make([]T, 0, n)` |
| DB queries inside a loop | N+1. Fetch in bulk |
