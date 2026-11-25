---
type: llm
weight: 1
---

Score 1 only if the review identifies all three real bugs:
1. `validate` returns a typed nil `*ValidationError` as `error`, so `err != nil` is always true (typed-nil interface gotcha). Fix: return `nil` explicitly when there is no error.
2. After `http.Error(w, "bad request", ...)` there is no `return`, so the handler keeps executing.
3. `_, saveErr := ...` inside the `if` block shadows the outer `saveErr` (and then discards it with `_ =`), so the save error is silently lost.
Deduct to 0 if the answer mostly consists of style nits or invents bugs that are not there.
