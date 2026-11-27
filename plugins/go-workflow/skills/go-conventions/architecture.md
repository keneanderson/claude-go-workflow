# Go architecture guidelines (defaults when the repository has no conventions)

## Match the existing structure first
- Check in `exploration.md` whether the repository uses Clean Architecture, layered, hexagonal or a flat structure, and **do not introduce a new structural style**
- If a similar feature already exists, follow its directory layout, naming and DI approach as is

## Packages
- Name packages after what they provide (`user`, `billing`). Do not create `util` / `common` / `helpers`
- Put anything not meant for external use under `internal/`
- Do not create import cycles. The domain layer does not depend on infrastructure (DB, HTTP, external SDKs)
- Avoid `init()` and mutable package-level global state; inject dependencies through constructors

## Interfaces
- Define interfaces in the **consuming** package, with only the methods it needs (keep them small)
- "Accept interfaces, return structs"
- Avoid a proliferation of interfaces that exist only for tests; follow the existing mocking approach (mockgen / mockery / hand-written fakes)

## Errors
- Wrap with `%w` at lower levels to add context, and log once and convert to the external representation only at the boundary (HTTP handler, gRPC, CLI)
- Represent expected failures with sentinels (`var ErrNotFound = errors.New(...)`) or typed errors, and have callers check them with `errors.Is` / `errors.As`
- Error messages start lowercase and have no trailing punctuation

## context
- `ctx context.Context` is the first parameter. Do not store it in struct fields
- Put nothing in `context.WithValue` other than request-scoped values (user ID, trace ID)

## Concurrency
- Whoever starts a goroutine is responsible for it until it finishes (`errgroup`, `sync.WaitGroup.Go`)
- Only the sender closes a channel

## Tests
- Table-driven with `t.Run`. Fake external I/O at the boundary; for the DB, follow the existing approach (testcontainers / sqlmock / a real DB)
- Test the behavior of the public API and avoid depending too much on implementation details
- Follow the existing practice of separating integration tests with build tags or `testing.Short()`
