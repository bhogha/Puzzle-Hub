// ── scr_wordle ────────────────────────────────────────────────────────────────
// Wordle puzzle logic (pure functions, ph_wordle_ prefix).
//
// Phase 0 scaffold: this file is intentionally a stub. The Phase 1 build fills in:
//   - loader + caches: global.ph_wordle_cache (answers), global.ph_wordle_allowed (guess set)
//   - date selection (two-pass: exact `date` match, else seed mod length)
//   - ph_wordle_make(date_key) -> normalized puzzle struct
//   - ph_wordle_score_guess(answer, guess) -> array of "green"/"yellow"/"gray" (two-pass dup logic)
//   - ph_wordle_is_allowed(word) -> bool (membership in the validation list)
//   - win/loss detection, state serialise/restore
//   - ph_wordle_is_done (won) / ph_wordle_is_missed (lost) / mark helpers
//
// See WORDLE_PLAN.md §6/§7 for data formats and save shape.

// Phase 0 placeholder so the script compiles and is registered.
function ph_wordle_stub() {
    // no-op
}
