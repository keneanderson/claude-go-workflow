---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

Review this newly added Go code for real bugs (not style). List each bug with the line and a one-line fix. Do not list style nits.

```go
type ValidationError struct{ Msg string }

func (e *ValidationError) Error() string { return e.Msg }

func validate(u User) error {
	var verr *ValidationError
	if u.Name == "" {
		verr = &ValidationError{Msg: "name required"}
	}
	return verr
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	u, err := decode(r)
	if err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
	}
	if err := validate(u); err != nil {
		http.Error(w, err.Error(), http.StatusUnprocessableEntity)
		return
	}
	var saveErr error
	if u.Admin {
		_, saveErr := h.store.SaveAdmin(r.Context(), u)
		_ = saveErr
	}
	if saveErr != nil {
		http.Error(w, "save failed", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
}
```
