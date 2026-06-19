// ── scr_ladder ────────────────────────────────────────────────────────────────
// Ladder (Word Ladder) puzzle logic — pure functions, ph_ladder_ prefix. No UI
// and no save-struct access here (the controller and scr_save own those).
//
// Data file (datafiles/, copied to PH_ASSETS_PATH at runtime):
//   puzzles_ladder.json : array of
//     { "date"?: "YYYY-MM-DD", "length": N, "start": "<N letters>",
//       "steps": [ { "word": "<N letters>", "clue": "..." } × 10 ] }
//
// The chain is  start → steps[0].word → … → steps[9].word  (11 words, 10 to find).
// Consecutive words (incl. start→steps[0]) must differ by exactly one position;
// all words share `length`. Authoring is validated offline.
//
// Runtime puzzle struct (ph_ladder_make):
//   {
//     length : 5,                       // letters per word this day
//     start  : "COLD",                  // seed word (shown pre-filled)
//     words  : [ "CORD", "WORD", … ],   // 10 target words, uppercase
//     clues  : [ "A thin rope…", … ],   // 10 clues, parallel to words
//     count  : 10,                      // == array_length(words)
//   }

// ── Loaders / caches ──────────────────────────────────────────────────────────

/// Load + cache the ladder pool. Returns an array (undefined sentinel if missing).
function ph_load_ladders() {
    if (variable_global_exists("ph_ladder_cache")) {
        return global.ph_ladder_cache;   // may be undefined (file missing)
    }
    var _path = PH_ASSETS_PATH + "puzzles_ladder.json";
    if (!file_exists(_path)) {
        global.ph_ladder_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_ladder_cache = json_parse(_str);
    return global.ph_ladder_cache;
}

// ── Date selection ────────────────────────────────────────────────────────────

/// Pick the ladder for a date. Two-pass (mirrors the other puzzles):
///   1. Exact "date" match wins (hand-authored days).
///   2. Else deterministic seed fallback so every calendar day is stable.
function ph_ladder_for_date(_date_key) {
    var _list = ph_load_ladders();
    if (_list == undefined || array_length(_list) == 0) {
        return ph_ladder_make(ph_ladder_fallback_raw());
    }
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _entry = _list[_i];
        if (is_struct(_entry)
            && variable_struct_exists(_entry, "date")
            && _entry.date == _date_key) {
            return ph_ladder_make(_entry);
        }
    }
    var _seed  = ph_seed_from_key(_date_key);
    var _index = _seed mod array_length(_list);
    return ph_ladder_make(_list[_index]);
}

/// Build the runtime struct from a raw data entry. Defensive: clamps to whatever
/// `steps` are present and derives `length` from `start` if absent.
function ph_ladder_make(_raw) {
    var _start = string_upper(string(_raw.start));
    var _len   = variable_struct_exists(_raw, "length") ? _raw.length : string_length(_start);
    var _words = [];
    var _clues = [];
    if (variable_struct_exists(_raw, "steps") && is_array(_raw.steps)) {
        for (var _i = 0; _i < array_length(_raw.steps); _i++) {
            var _s = _raw.steps[_i];
            array_push(_words, string_upper(string(_s.word)));
            array_push(_clues, variable_struct_exists(_s, "clue") ? string(_s.clue) : "");
        }
    }
    return {
        length : _len,
        start  : _start,
        words  : _words,
        clues  : _clues,
        count  : array_length(_words),
    };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Index (0-based) of the single position where two equal-length words differ,
/// or -1 if they are identical. If they differ in more than one place, returns
/// the first differing index (authoring should keep it to exactly one).
function ph_ladder_diff_pos(_a, _b) {
    _a = string_upper(_a);
    _b = string_upper(_b);
    var _n = min(string_length(_a), string_length(_b));
    for (var _i = 0; _i < _n; _i++) {
        if (string_char_at(_a, _i + 1) != string_char_at(_b, _i + 1)) return _i;
    }
    return -1;
}

/// The current word for a given solved-step count: step 0 shows `start`, step k
/// shows words[k-1] (the last word the player completed).
function ph_ladder_current_word(_puzzle, _step) {
    if (_step <= 0) return _puzzle.start;
    return _puzzle.words[min(_step, _puzzle.count) - 1];
}

// ── Fallback (file missing) ───────────────────────────────────────────────────
// A valid 5-letter ladder: each consecutive pair differs by exactly one letter.
function ph_ladder_fallback_raw() {
    return {
        length: 4,
        start:  "COLD",
        steps: [
            { word: "CORD", clue: "A thin rope or string" },
            { word: "WORD", clue: "A single unit of language" },
            { word: "WARD", clue: "A section of a hospital" },
            { word: "WARM", clue: "Pleasantly hot" },
            { word: "WARE", clue: "Goods or pottery (as in 'soft-___')" },
            { word: "BARE", clue: "Naked or uncovered" },
            { word: "BARN", clue: "A farm building for animals" },
            { word: "BORN", clue: "Brought into life" },
            { word: "CORN", clue: "A yellow grain on a cob" },
            { word: "CORK", clue: "A stopper for a wine bottle" },
        ],
    };
}
