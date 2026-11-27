# Modern Go reference

Only use features from versions up to the `go` directive in `go.mod`. Check anything uncertain with `go doc`.

## Old → new replacement table

| Old | New | Minimum version |
|-----|-----|-----------------|
| `interface{}` | `any` | 1.18 |
| `strings.Index` + slicing | `strings.Cut` / `CutPrefix` / `CutSuffix` | 1.18 / 1.20 |
| Hand-rolled joining of multiple errors | `errors.Join`, multiple `%w` in `fmt.Errorf` | 1.20 |
| `sync/atomic.AddInt64(&x)` | Types such as `atomic.Int64` | 1.19 |
| `if a < b { m = a }` | `min(a, b)` / `max(a, b)` | 1.21 |
| Deleting every map entry in a for loop | `clear(m)` | 1.21 |
| `sort.Slice` / hand-written contains and index | `slices.Sort` / `slices.SortFunc` / `slices.Contains` / `slices.Index` | 1.21 |
| A loop collecting map keys | `slices.Sorted(maps.Keys(m))` | 1.23 |
| Introducing `log` / an external logger in new code | `log/slog` (follow the existing logger if there is one) | 1.21 |
| `sync.Once` + a variable | `sync.OnceFunc` / `OnceValue` / `OnceValues` | 1.21 |
| `v := v` (copying the loop variable) | Not needed (since 1.22 each iteration has a new variable) | 1.22 |
| `for i := 0; i < n; i++` | `for i := range n` | 1.22 |
| An external router dependency just for simple path matching | `mux.HandleFunc("GET /items/{id}", h)` + `r.PathValue("id")` | 1.22 |
| `math/rand` | `math/rand/v2` (`crypto/rand` for secrets) | 1.22 |
| `if x == "" { x = def }` | `cmp.Or(x, def)` | 1.22 |
| Chained appends to concatenate slices | `slices.Concat` | 1.22 |
| Callback-style iterators | `iter.Seq[T]` / `iter.Seq2[K,V]` + range-over-func | 1.23 |
| `context.WithCancel(context.Background())` in tests | `t.Context()` | 1.24 |
| `for i := 0; i < b.N; i++` | `for b.Loop()` | 1.24 |
| `filepath.Join(root, userPath)` + hand-rolled validation | `os.Root` / `os.OpenInRoot` | 1.24 |
| `json:",omitempty"` (zero values of structs and time.Time) | `json:",omitzero"` | 1.24 |
| Iterating lines/fields with `strings.Split` | `strings.Lines` / `SplitSeq` / `FieldsSeq` (same for bytes) | 1.24 |
| Managing tool dependencies with `tools.go` | `go get -tool <pkg>` / `go tool <name>` | 1.24 |
| A hand-rolled secret token generator | `crypto/rand.Text()` | 1.24 |
| `wg.Add(1); go func(){ defer wg.Done() ... }()` | `wg.Go(func(){ ... })` | 1.25 |
| Sleeps in time-dependent tests | `testing/synctest` | 1.25 |
| Hand-rolled CSRF (Origin/Sec-Fetch-Site checks) | `http.CrossOriginProtection` | 1.25 |
| `var target *MyErr; errors.As(err, &target)` | `target, ok := errors.AsType[*MyErr](err)` | 1.26 |
| `p := new(T); *p = v` / pointer helper functions | `new(v)` (`new` taking an expression) | 1.26 |
| A generic function placed at package level although it belongs to a type | Generic methods `func (s Set[T]) Map[U any](...)` (not allowed as interface methods, and a generic method cannot satisfy an interface) | 1.27 |
| `i := strings.LastIndex(s, sep); s[:i], s[i+len(sep):]` | `strings.CutLast` / `bytes.CutLast` | 1.27 |
| Hand-written deep copies of `url.URL` / `url.Values` | `URL.Clone()` / `Values.Clone()` | 1.27 |
| UUID dependencies such as `github.com/google/uuid` | The standard library `uuid` package (after checking you do not rely on v3/v5 namespace UUIDs or DB Scanner integration) | 1.27 |
| `time.Sleep` + `synctest.Wait` inside a synctest bubble | `synctest.Sleep` | 1.27 |
| `httptest.NewServer` combined with synctest | `httptest.NewTestServer` (an in-memory fake network) | 1.27 |
| New JSON code that needs fine-grained control | `encoding/json/v2` + `encoding/json/jsontext` (v2 rejects invalid UTF-8 and duplicate keys. The existing `encoding/json` keeps v1 behavior on top of the v2 implementation, so migrating is not required) | 1.27 |

For any 1.27+ feature not listed above, check the release notes at https://go.dev/doc/devel/release before using it (do not write from memory).

## Checks when upgrading Go (1.27)

Items that need checking beforehand rather than code rewrites:

- Check that `godebug` in `go.mod` or `//go:debug` does not pin a GODEBUG setting removed in 1.27 (such as `asynctimerchan`) to an old value → it becomes a build error (`git grep -n 'go:debug'; grep -n godebug go.mod`)
- `go test` now runs the `stdversion` vet check, so using standard library APIs newer than the go directive fails the tests → do not silence the check; raise the go directive or separate the code with build tags
- `encoding/json` is now based on the v2 implementation, and error message wording may change → check tests that compare error strings
- The minimum supported version for macOS builds is 13.0
- `go fix` gained modernizers (`atomictypes`, `embedlit`, `slicesbackward`, `unsafefuncs`) and `fmtappendf` was removed. After updating the toolchain, check with `go fix -diff ./...`

## New features for runtime investigation

- Goroutine leaks: the `goroutineleak` profile in `runtime/pprof` (official in 1.27, `/debug/pprof/goroutineleak`). It detects goroutines stuck on unreachable synchronization primitives

## Automatic modernization (`go fix` / modernize)

- Go 1.26+: `go fix ./...` runs the modernize analyzers (`go fix -diff ./...` only shows the diff)
- Go 1.25 and earlier: `go run golang.org/x/tools/go/analysis/passes/modernize/cmd/modernize@latest -fix -test ./...`
- In repositories using golangci-lint v2, check whether `modernize` / `intrange` / `copyloopvar` / `usestdlibvars` and the like are enabled in `.golangci.yml`, and follow the repository's settings
- As a rule, limit automatic fixes to the packages the task touched. Applying them everywhere produces a large unrelated diff

## Other modern practices

- Errors: `fmt.Errorf("op: %w", err)`, compare with `errors.Is` / `errors.As` (`errors.AsType`)
- HTTP servers: always set `ReadHeaderTimeout` and friends on `http.Server`, and use a client with a timeout instead of `http.DefaultClient`
- JSON v2 (`encoding/json/v2`) needs `GOEXPERIMENT=jsonv2` in 1.25–1.26, so do not use it there. From 1.27 it is fine to use, but replace existing `encoding/json` only after checking behavior differences (rejecting invalid UTF-8 and duplicate keys, etc.)
- Tests: table-driven + `t.Run`, `t.Cleanup`, `t.TempDir`, `t.Setenv`, `go test -race`
- Structured logging: `slog.InfoContext(ctx, "msg", "key", v)`, no PII in attributes
