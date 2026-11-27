# Go security checklist

Check each item "where applicable". Prioritize findings for which you can write a concrete exploit scenario.

## Input and injection
- [ ] SQL uses placeholders (`?` / `$1`). Queries are not built with `fmt.Sprintf` / string concatenation. Dynamic ORDER BY / column names use an allowlist
- [ ] `exec.Command` is called with an argument array, and user input is never passed to `sh -c`
- [ ] HTML output uses `html/template` (never build HTML with `text/template`). Conversion to `template.HTML` only for sanitized content
- [ ] Request bodies are capped with `http.MaxBytesReader`. JSON uses `DisallowUnknownFields` where needed
- [ ] Range validation for numbers, lengths and enum values. A cap on pagination
- [ ] User input containing newlines and the like is not written to logs as is (pass it as a slog attribute)

## Authentication and authorization
- [ ] Every handler checks authorization. Resource IDs are filtered by "owner = current user" (IDOR)
- [ ] No missing middleware on admin endpoints
- [ ] Passwords use `bcrypt` / `argon2id`. Token comparison uses `subtle.ConstantTimeCompare`
- [ ] JWTs pin the signing algorithm and validate `exp` / `aud` / `iss`

## Files and paths
- [ ] Paths containing user input use `os.Root` (1.24+), or `filepath.IsLocal` plus a check that they stay under the root
- [ ] Path traversal (zip slip) and size limits (zip bomb) when extracting zip / tar
- [ ] Temporary files use `os.CreateTemp` with minimal permissions (0600 / 0700)

## Outbound communication
- [ ] Access to user-specified URLs is protected against SSRF (scheme and host allowlist, rejecting private IPs, redirect control)
- [ ] `http.Client` has a timeout. No `InsecureSkipVerify: true`
- [ ] Response bodies are `Close`d and capped with `io.LimitReader`

## Secrets
- [ ] No hard-coded keys, passwords or tokens (explicit dummies for tests are fine)
- [ ] Secrets and PII never appear in logs / error messages / API responses / panic messages
- [ ] Randomness: secret uses need `crypto/rand` (`crypto/rand.Text()`). `math/rand` is not allowed

## Web
- [ ] CSRF: `http.CrossOriginProtection` (1.25+) or the existing CSRF middleware
- [ ] CORS: no `*` combined with credentials, an Origin allowlist
- [ ] Cookies: `Secure` / `HttpOnly` / `SameSite`
- [ ] Security headers (CSP, X-Content-Type-Options, frame-ancestors, etc.) follow the existing policy
- [ ] `ReadHeaderTimeout` / `ReadTimeout` / `WriteTimeout` / `IdleTimeout` on `http.Server`

## Concurrency and availability
- [ ] No unbounded goroutine creation (semaphore / `errgroup.SetLimit`)
- [ ] Access to shared state uses locks or channels. Nothing detected by `go test -race`
- [ ] `context` cancellation propagates to downstream I/O
- [ ] Regular expressions are not built from user input (or their length is limited)

## Dependencies
- [ ] New dependencies are checked for maintenance status, license and necessity
- [ ] No known vulnerabilities from `govulncheck ./...`
- [ ] No unnatural changes to `go.sum`
