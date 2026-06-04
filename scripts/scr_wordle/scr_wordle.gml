// ── scr_wordle ────────────────────────────────────────────────────────────────
// Wordle puzzle logic (pure functions, ph_wordle_ prefix). No UI, no save struct
// access here — the controller (Phase 2) and save layer (Phase 3) call into this.
//
// Data files (datafiles/, copied to working_directory at runtime):
//   puzzles_wordle.json : array of { "date"?: "YYYY-MM-DD", "answer": "<6 letters>" }
//   wordle_allowed.json : flat array of valid uppercase 6-letter guess strings
//
// Runtime puzzle struct (ph_wordle_make):
//   {
//     answer:       "STREAM",        // uppercase, PH_WORDLE_LEN chars
//     guesses:      [ "PLANTS", ...],// submitted guesses, uppercase
//     max_guesses:  PH_WORDLE_GUESSES,// grows by PH_WORDLE_EXTRA_MOVES if bought
//     extra_bought: false,           // one-time extra-moves purchase used?
//     hints:        [ {pos, letter} ],// locked hint reveals (filled in Phase 4)
//     status:       "in_progress",   // "in_progress" | "won" | "lost"
//   }
//
// Tile/letter feedback values are the strings "green" / "yellow" / "gray".

// ── Loaders / caches ──────────────────────────────────────────────────────────

/// Load + cache the answer pool. Returns an array (possibly undefined if missing).
function ph_load_wordles() {
    if (variable_global_exists("ph_wordle_cache")) {
        return global.ph_wordle_cache;   // may be undefined sentinel (file missing)
    }
    var _path = working_directory + "puzzles_wordle.json";
    if (!file_exists(_path)) {
        global.ph_wordle_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_wordle_cache = json_parse(_str);
    return global.ph_wordle_cache;
}

/// Load + cache the guess-validation list as a struct map { WORD: true } for O(1)
/// membership. Returns the struct (empty struct if the file is missing).
function ph_load_wordle_allowed() {
    if (variable_global_exists("ph_wordle_allowed")) {
        return global.ph_wordle_allowed;
    }
    var _map = {};
    var _path = working_directory + "wordle_allowed.json";
    if (file_exists(_path)) {
        var _buf = buffer_load(_path);
        var _str = buffer_read(_buf, buffer_string);
        buffer_delete(_buf);
        var _list = json_parse(_str);
        if (is_array(_list)) {
            for (var _i = 0; _i < array_length(_list); _i++) {
                variable_struct_set(_map, string_upper(_list[_i]), true);
            }
        }
    }
    global.ph_wordle_allowed = _map;
    return _map;
}

/// True if a fully-typed guess is an accepted word. The current answer is always
/// allowed, guarding against an answer missing from the validation list.
function ph_wordle_is_allowed(_word, _answer) {
    _word = string_upper(_word);
    if (argument_count > 1 && _word == string_upper(_answer)) return true;
    var _map = ph_load_wordle_allowed();
    return variable_struct_exists(_map, _word);
}

// ── Date selection ────────────────────────────────────────────────────────────

/// Pick the puzzle for a date. Two-pass (mirrors the other puzzles):
///   1. Exact "date" match wins (hand-authored days).
///   2. Else deterministic seed fallback so every calendar day is stable.
function ph_wordle_for_date(_date_key) {
    var _list = ph_load_wordles();
    if (_list == undefined || array_length(_list) == 0) {
        return ph_wordle_make({ answer: "STREAM" });   // never-crash fallback
    }
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _entry = _list[_i];
        if (is_struct(_entry)
            && variable_struct_exists(_entry, "date")
            && _entry.date == _date_key) {
            return ph_wordle_make(_entry);
        }
    }
    var _seed  = ph_seed_from_key(_date_key);
    var _index = _seed mod array_length(_list);
    return ph_wordle_make(_list[_index]);
}

/// Build the runtime struct from a raw data entry.
function ph_wordle_make(_raw) {
    return {
        answer:       string_upper(_raw.answer),
        guesses:      [],
        max_guesses:  PH_WORDLE_GUESSES,
        extra_bought: false,
        hints:        [],
        status:       "in_progress",
    };
}

// ── Scoring ───────────────────────────────────────────────────────────────────

/// Score one guess against the answer using true Wordle two-pass duplicate logic:
///   Pass 1 marks exact-position matches "green" and consumes those answer slots.
///   Pass 2 marks "yellow" only from answer letters not already consumed; else "gray".
/// Returns an array (length PH_WORDLE_LEN) of "green" / "yellow" / "gray".
function ph_wordle_score_guess(_answer, _guess) {
    var _n   = PH_WORDLE_LEN;
    _answer  = string_upper(_answer);
    _guess   = string_upper(_guess);
    var _res = array_create(_n, "gray");
    var _used = array_create(_n, false);   // answer slots already accounted for

    // Pass 1: greens
    for (var _i = 0; _i < _n; _i++) {
        if (string_char_at(_guess, _i + 1) == string_char_at(_answer, _i + 1)) {
            _res[_i]  = "green";
            _used[_i] = true;
        }
    }
    // Pass 2: yellows
    for (var _i = 0; _i < _n; _i++) {
        if (_res[_i] == "green") continue;
        var _gc = string_char_at(_guess, _i + 1);
        for (var _j = 0; _j < _n; _j++) {
            if (!_used[_j] && string_char_at(_answer, _j + 1) == _gc) {
                _res[_i]  = "yellow";
                _used[_j] = true;
                break;
            }
        }
    }
    return _res;
}

/// True if a guess equals the answer (all-green).
function ph_wordle_guess_is_correct(_answer, _guess) {
    return string_upper(_guess) == string_upper(_answer);
}

// ── State transitions (pure on the struct) ────────────────────────────────────

/// Guesses remaining before the board is exhausted.
function ph_wordle_remaining(_puzzle) {
    return _puzzle.max_guesses - array_length(_puzzle.guesses);
}

/// Append a submitted guess and recompute status. Caller is responsible for
/// having validated the guess (length + allow-list) first.
/// Returns the new status: "won" | "lost" | "in_progress".
function ph_wordle_add_guess(_puzzle, _guess) {
    _guess = string_upper(_guess);
    array_push(_puzzle.guesses, _guess);
    if (ph_wordle_guess_is_correct(_puzzle.answer, _guess)) {
        _puzzle.status = "won";
    } else if (array_length(_puzzle.guesses) >= _puzzle.max_guesses) {
        _puzzle.status = "lost";
    } else {
        _puzzle.status = "in_progress";
    }
    return _puzzle.status;
}

/// Apply the one-time extra-moves purchase: extend the board by PH_WORDLE_EXTRA_MOVES
/// rows and re-open a "lost" board. Returns true if applied, false if already used.
function ph_wordle_grant_extra_moves(_puzzle) {
    if (_puzzle.extra_bought) return false;
    _puzzle.extra_bought = true;
    _puzzle.max_guesses += PH_WORDLE_EXTRA_MOVES;
    if (_puzzle.status == "lost") _puzzle.status = "in_progress";
    return true;
}

/// Best-known state per letter across all submitted guesses, for keyboard tinting.
/// Returns a struct { "A": "green"|"yellow"|"gray", ... } (only letters guessed).
/// Priority green > yellow > gray.
function ph_wordle_keyboard_states(_puzzle) {
    var _map = {};
    var _rank = function(_s) {
        if (_s == "green")  return 3;
        if (_s == "yellow") return 2;
        if (_s == "gray")   return 1;
        return 0;
    };
    for (var _g = 0; _g < array_length(_puzzle.guesses); _g++) {
        var _guess = _puzzle.guesses[_g];
        var _score = ph_wordle_score_guess(_puzzle.answer, _guess);
        for (var _i = 0; _i < PH_WORDLE_LEN; _i++) {
            var _ch  = string_char_at(_guess, _i + 1);
            var _new = _score[_i];
            if (!variable_struct_exists(_map, _ch)
                || _rank(_new) > _rank(variable_struct_get(_map, _ch))) {
                variable_struct_set(_map, _ch, _new);
            }
        }
    }
    return _map;
}

// ── Serialise / restore (for save resume — called by the save layer in Phase 3) ──

/// Submitted guesses -> "STREAM;PLANTS" (empty string if none).
function ph_wordle_guesses_to_str(_puzzle) {
    return string_join_ext(";", _puzzle.guesses);
}

/// "STREAM;PLANTS" -> array of uppercase guesses (empty array if blank).
function ph_wordle_guesses_from_str(_s) {
    if (_s == undefined || _s == "") return [];
    var _parts = string_split(_s, ";");
    for (var _i = 0; _i < array_length(_parts); _i++) {
        _parts[_i] = string_upper(_parts[_i]);
    }
    return _parts;
}

// NOTE: save-struct helpers (ph_wordle_is_done / is_missed / mark, the
// ph_solved_count_on skip rule for WORDLE_MISSED) live in scr_save and are added
// in Phase 3 (win) / Phase 5 (loss), where the save struct is in scope.
