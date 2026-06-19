// ── Anygram puzzle helpers ────────────────────────────────────────────────────
//
// Puzzle data is loaded from datafiles/puzzles_anygram.json. Two on-disk shapes
// are supported so existing 2-word puzzles continue to work alongside new 4–7
// word puzzles:
//
//   LEGACY (2-word crossword):
//     { "main1", "main2", "cross_letter",
//       "main1_index", "main2_index", "bonus" }
//
//   NEW (N-word crossword) — matches Anygram GDD §10:
//     { "letters":    [..],                                // 5 letters per GDD
//       "words":      [{"text","row","col","dir"}, ..],    // 4–7 main words
//       "bonus":      [..]   (or "bonus_pool" — both accepted) }
//     Optional informational fields the loader ignores: "date", "grid_size".
//
// ph_anygram_make() normalizes both shapes into the SAME runtime struct:
//
//   {
//     words:        [{text, row, col, dir, found}, ..],   // array, N >= 2
//     bonus:        [..],
//     bonus_found:  [bool, ..],
//     cells:        [{r, c, letter, word_indices:[..], filled, hint}, ..],
//     letters:      [..],
//   }
//
// The "shared" flag and per-cell word_h/word_v fields used by the legacy
// drawing code are preserved on each cell for back-compatibility.

function ph_load_anygrams() {
    if (variable_global_exists("ph_anygram_cache")) {
        return global.ph_anygram_cache;   // may be undefined sentinel (file missing)
    }
    var _path = PH_ASSETS_PATH + "puzzles_anygram.json";
    if (!file_exists(_path)) {
        global.ph_anygram_cache = undefined;
        return undefined;
    }
    var _buf  = buffer_load(_path);
    var _str  = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_anygram_cache = json_parse(_str);
    return global.ph_anygram_cache;
}

/// Pick the puzzle for a given date.
/// Selection order:
///   1. Exact match — any puzzle whose "date" field equals _date_key wins.
///      This lets us author specific dates (e.g. holidays, launch day) and
///      know exactly which puzzle the player will see that day.
///   2. Seed fallback — for dates with no exact entry, pick deterministically
///      by `seed mod array_length(_list)` so the player still gets a stable,
///      same-on-every-device puzzle for every calendar day.
function ph_anygram_for_date(_date_key) {
    var _list = ph_load_anygrams();
    if (_list == undefined || array_length(_list) == 0) {
        // Fallback puzzle (legacy 2-word shape) when the data file is missing.
        return ph_anygram_make_legacy("LIVE","VILE","V",2,0,["EVIL","VEIL"]);
    }
    // 1. Exact date match
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _entry = _list[_i];
        if (is_struct(_entry)
            && variable_struct_exists(_entry, "date")
            && _entry.date == _date_key) {
            return ph_anygram_make(_entry);
        }
    }
    // 2. Seed fallback
    var _seed  = ph_seed_from_key(_date_key);
    var _index = _seed mod array_length(_list);
    var _raw   = _list[_index];
    return ph_anygram_make(_raw);
}

/// Dispatch on data shape and return the normalized puzzle struct.
function ph_anygram_make(_raw) {
    if (variable_struct_exists(_raw, "words")) {
        return ph_anygram_make_n(_raw);
    }
    // Fall back to legacy 2-word shape
    var _cross = variable_struct_exists(_raw, "cross_letter") ? _raw.cross_letter : "";
    return ph_anygram_make_legacy(
        _raw.main1, _raw.main2, _cross,
        _raw.main1_index, _raw.main2_index,
        variable_struct_exists(_raw, "bonus") ? _raw.bonus : []
    );
}

/// Build the runtime puzzle from a NEW-format raw struct.
function ph_anygram_make_n(_raw) {
    var _words_raw = _raw.words;
    // Accept either "bonus" (legacy / current data files) or "bonus_pool"
    // (matches the field name spelled out in the Anygram GDD §10 example).
    var _bonus = [];
    if      (variable_struct_exists(_raw, "bonus"))      _bonus = _raw.bonus;
    else if (variable_struct_exists(_raw, "bonus_pool")) _bonus = _raw.bonus_pool;

    // Normalize words into runtime structs (uppercase text, found flag).
    var _words = [];
    for (var _i = 0; _i < array_length(_words_raw); _i++) {
        var _w = _words_raw[_i];
        array_push(_words, {
            text:  string_upper(_w.text),
            row:   _w.row,
            col:   _w.col,
            dir:   _w.dir,             // "H" or "V"
            found: false,
        });
    }

    // Build cells from words, merging overlaps. Cells remember every word that
    // touches them so reveal/hint logic can act per-word.
    var _by_key = {};   // "r,c" -> cell index in _cells
    var _cells  = [];
    for (var _wi = 0; _wi < array_length(_words); _wi++) {
        var _w   = _words[_wi];
        var _len = string_length(_w.text);
        for (var _k = 0; _k < _len; _k++) {
            var _r  = _w.row + ((_w.dir == "V") ? _k : 0);
            var _c  = _w.col + ((_w.dir == "H") ? _k : 0);
            var _ch = string_char_at(_w.text, _k + 1);
            var _key = string(_r) + "," + string(_c);
            if (variable_struct_exists(_by_key, _key)) {
                var _idx     = _by_key[$ _key];
                var _existing = _cells[_idx];
                if (_existing.letter != _ch) {
                    show_debug_message(
                        "ANYGRAM: cell (" + string(_r) + "," + string(_c) +
                        ") disagrees: " + _existing.letter + " vs " + _ch);
                }
                array_push(_existing.word_indices, _wi);
                _existing.shared = true;
                _cells[_idx] = _existing;
            } else {
                var _cell = {
                    r:             _r,
                    c:             _c,
                    letter:        _ch,
                    word_indices:  [_wi],
                    shared:        false,
                    filled:        false,
                    hint:          false,
                    // Legacy fields preserved so old Draw code keeps working
                    word_h:        (_w.dir == "H") ? _w.text : "",
                    word_v:        (_w.dir == "V") ? _w.text : "",
                    hi:            (_w.dir == "H") ? _k : -1,
                    vi:            (_w.dir == "V") ? _k : -1,
                };
                _by_key[$ _key] = array_length(_cells);
                array_push(_cells, _cell);
            }
        }
    }
    // Now that we know which cells are shared, fix the legacy word_h/word_v
    // by replaying words and only setting when the cell touches that direction.
    for (var _wi = 0; _wi < array_length(_words); _wi++) {
        var _w   = _words[_wi];
        var _len = string_length(_w.text);
        for (var _k = 0; _k < _len; _k++) {
            var _r  = _w.row + ((_w.dir == "V") ? _k : 0);
            var _c  = _w.col + ((_w.dir == "H") ? _k : 0);
            var _key = string(_r) + "," + string(_c);
            var _idx = _by_key[$ _key];
            var _cell = _cells[_idx];
            if (_w.dir == "H") { _cell.word_h = _w.text; _cell.hi = _k; }
            else               { _cell.word_v = _w.text; _cell.vi = _k; }
            _cells[_idx] = _cell;
        }
    }

    // Wheel letters: prefer authored "letters" if present, else infer from words.
    var _letters = [];
    if (variable_struct_exists(_raw, "letters") && array_length(_raw.letters) > 0) {
        for (var _li = 0; _li < array_length(_raw.letters); _li++) {
            array_push(_letters, string_upper(_raw.letters[_li]));
        }
    } else {
        // Union of every distinct letter across all words, capped at 7
        for (var _wi = 0; _wi < array_length(_words); _wi++) {
            var _t = _words[_wi].text;
            for (var _k = 1; _k <= string_length(_t); _k++) {
                var _ch = string_char_at(_t, _k);
                var _seen = false;
                for (var _li = 0; _li < array_length(_letters); _li++) {
                    if (_letters[_li] == _ch) { _seen = true; break; }
                }
                if (!_seen) array_push(_letters, _ch);
                if (array_length(_letters) >= 7) break;
            }
            if (array_length(_letters) >= 7) break;
        }
    }

    return {
        words:       _words,
        bonus:       _bonus,
        bonus_found: array_create(array_length(_bonus), false),
        cells:       _cells,
        letters:     _letters,
    };
}

/// Build the runtime puzzle from a LEGACY 2-word raw struct.
function ph_anygram_make_legacy(_main1, _main2, _cross, _idx1, _idx2, _bonus) {
    var _raw = {
        letters: [],     // inferred from words
        words: [
            { text: string_upper(_main1), row: _idx2, col: 0,     dir: "H" },
            { text: string_upper(_main2), row: 0,     col: _idx1, dir: "V" },
        ],
        bonus: _bonus,
    };
    return ph_anygram_make_n(_raw);
}

/// Classify a spelled word against the puzzle.
/// Returns a struct:
///   { kind: "main"|"bonus"|"dup"|"neutral"|"bad", index: int }
/// `index` is the word index (into puzzle.words for "main", into puzzle.bonus
/// for "bonus") or -1 when not applicable.
function ph_classify_word(_puzzle, _word) {
    _word = string_upper(_word);
    if (string_length(_word) < 2) return { kind: "bad", index: -1 };

    // Main words
    for (var _i = 0; _i < array_length(_puzzle.words); _i++) {
        if (_puzzle.words[_i].text == _word) {
            if (_puzzle.words[_i].found) return { kind: "dup", index: _i };
            return { kind: "main", index: _i };
        }
    }
    // Bonus words
    var _bf = variable_struct_exists(_puzzle, "bonus_found") ? _puzzle.bonus_found : undefined;
    for (var _i = 0; _i < array_length(_puzzle.bonus); _i++) {
        if (string_upper(_puzzle.bonus[_i]) == _word) {
            if (_bf != undefined && _i < array_length(_bf) && _bf[_i]) {
                return { kind: "dup", index: _i };
            }
            return { kind: "bonus", index: _i };
        }
    }
    // Must use only wheel letters to be even "neutral"
    var _letters = _puzzle.letters;
    for (var _i = 1; _i <= string_length(_word); _i++) {
        var _ch = string_char_at(_word, _i);
        var _ok = false;
        for (var _j = 0; _j < array_length(_letters); _j++) {
            if (_letters[_j] == _ch) { _ok = true; break; }
        }
        if (!_ok) return { kind: "bad", index: -1 };
    }
    return { kind: "neutral", index: -1 };
}

/// True if every main word in the puzzle is marked found.
function ph_anygram_all_solved(_puzzle) {
    for (var _i = 0; _i < array_length(_puzzle.words); _i++) {
        if (!_puzzle.words[_i].found) return false;
    }
    return true;
}

/// Return the array of cells belonging to a given main word, in left-to-right
/// (H) / top-to-bottom (V) order. Used to drive the letter-tile fly animation.
function ph_anygram_cells_for_word(_puzzle, _word_index) {
    var _w   = _puzzle.words[_word_index];
    var _out = array_create(string_length(_w.text), undefined);
    for (var _i = 0; _i < array_length(_puzzle.cells); _i++) {
        var _c = _puzzle.cells[_i];
        for (var _j = 0; _j < array_length(_c.word_indices); _j++) {
            if (_c.word_indices[_j] == _word_index) {
                var _k = (_w.dir == "H") ? (_c.c - _w.col) : (_c.r - _w.row);
                if (_k >= 0 && _k < string_length(_w.text)) {
                    _out[_k] = _c;
                }
                break;
            }
        }
    }
    return _out;
}

// ── Word Wave puzzle helpers ──────────────────────────────────────────────────
//
// Puzzle data is loaded from datafiles/puzzles_wordwave.json. Each entry:
//
//   { "date":  "YYYY-MM-DD"      (optional; enables exact-date authoring),
//     "grid":  ["ROWSTRING", ..] (8 strings of 8 uppercase letters),
//     "words": [ {"text","row","col","dir"}, .. ],   // hidden words
//     "bonus_pool": ["WORD", ..] }                    // accepted bonus words
//
// `dir` is one of eight named directions; the deltas (drow,dcol) are:
//   H (0,+1)  H_REV (0,-1)  V (+1,0)  V_REV (-1,0)
//   DR (+1,+1)  DL (+1,-1)  UR (-1,+1)  UL (-1,-1)
//
// ph_wordwave_make() normalizes into the runtime struct:
//   { grid:    [[char,..] x8],          // grid[r][c]
//     size:    8,
//     words:   [ {text,row,col,dir,found,cells:[{r,c},..]}, .. ],
//     bonus_pool:  [..],
//     bonus_found: [bool,..] }

/// Direction delta for a named Word Wave direction. Returns {dr,dc}.
function ph_ww_delta(_dir) {
    switch (_dir) {
        case "H":     return { dr: 0,  dc: 1  };
        case "H_REV": return { dr: 0,  dc: -1 };
        case "V":     return { dr: 1,  dc: 0  };
        case "V_REV": return { dr: -1, dc: 0  };
        case "DR":    return { dr: 1,  dc: 1  };
        case "DL":    return { dr: 1,  dc: -1 };
        case "UR":    return { dr: -1, dc: 1  };
        case "UL":    return { dr: -1, dc: -1 };
        default:      return { dr: 0,  dc: 1  };
    }
}

function ph_load_wordwaves() {
    if (variable_global_exists("ph_wordwave_cache")) {
        return global.ph_wordwave_cache;   // may be undefined sentinel (file missing)
    }
    var _path = PH_ASSETS_PATH + "puzzles_wordwave.json";
    if (!file_exists(_path)) {
        global.ph_wordwave_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_wordwave_cache = json_parse(_str);
    return global.ph_wordwave_cache;
}

/// Pick the Word Wave puzzle for a given date (exact match, then seed fallback).
function ph_wordwave_for_date(_date_key) {
    var _list = ph_load_wordwaves();
    if (_list == undefined || array_length(_list) == 0) {
        return ph_wordwave_fallback();
    }
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        if (is_struct(_e) && variable_struct_exists(_e, "date") && _e.date == _date_key) {
            return ph_wordwave_make(_e);
        }
    }
    var _seed = ph_seed_from_key(_date_key);
    return ph_wordwave_make(_list[_seed mod array_length(_list)]);
}

/// Build the runtime puzzle struct from a raw JSON entry.
function ph_wordwave_make(_raw) {
    var _size = 8;
    // Grid → 2D char array.
    var _grid = array_create(_size);
    for (var _r = 0; _r < _size; _r++) {
        var _row_str = (_r < array_length(_raw.grid)) ? string_upper(_raw.grid[_r]) : "";
        var _row = array_create(_size, " ");
        for (var _c = 0; _c < _size; _c++) {
            if (_c < string_length(_row_str)) _row[_c] = string_char_at(_row_str, _c + 1);
        }
        _grid[_r] = _row;
    }
    // Words → runtime structs with precomputed cell lists.
    var _words = [];
    for (var _wi = 0; _wi < array_length(_raw.words); _wi++) {
        var _w  = _raw.words[_wi];
        var _txt = string_upper(_w.text);
        var _d   = ph_ww_delta(_w.dir);
        var _cells = [];
        for (var _k = 0; _k < string_length(_txt); _k++) {
            array_push(_cells, { r: _w.row + _d.dr * _k, c: _w.col + _d.dc * _k });
        }
        array_push(_words, {
            text:  _txt,
            row:   _w.row,
            col:   _w.col,
            dir:   _w.dir,
            found: false,
            cells: _cells,
        });
    }
    var _bonus = [];
    if      (variable_struct_exists(_raw, "bonus_pool")) _bonus = _raw.bonus_pool;
    else if (variable_struct_exists(_raw, "bonus"))      _bonus = _raw.bonus;
    var _bonus_up = [];
    for (var _i = 0; _i < array_length(_bonus); _i++) array_push(_bonus_up, string_upper(_bonus[_i]));

    return {
        grid:        _grid,
        size:        _size,
        words:       _words,
        bonus_pool:  _bonus_up,
        bonus_found: array_create(array_length(_bonus_up), false),
    };
}

/// Minimal hard-coded puzzle used when the data file is missing.
function ph_wordwave_fallback() {
    return ph_wordwave_make({
        grid: [
            "CATXXXXX", "XXXXXXXX", "DOGXXXXX", "XXXXXXXX",
            "XXXXXXXX", "XXXXXXXX", "XXXXXXXX", "XXXXXXXX",
        ],
        words: [
            { text: "CAT", row: 0, col: 0, dir: "H" },
            { text: "DOG", row: 2, col: 0, dir: "H" },
        ],
        bonus_pool: [],
    });
}

/// Read the letters along an arbitrary straight line of grid cells, in order.
/// _path is an array of {r,c}. Returns "" if any cell is off-grid.
function ph_ww_path_word(_puzzle, _path) {
    var _s = "";
    for (var _i = 0; _i < array_length(_path); _i++) {
        var _p = _path[_i];
        if (_p.r < 0 || _p.r >= _puzzle.size || _p.c < 0 || _p.c >= _puzzle.size) return "";
        _s += _puzzle.grid[_p.r][_p.c];
    }
    return _s;
}

/// True if two straight-line paths cover the same set of cells (order-agnostic),
/// so a word swiped in reverse still matches the authored placement.
function ph_ww_paths_match(_a, _b) {
    if (array_length(_a) != array_length(_b)) return false;
    for (var _i = 0; _i < array_length(_a); _i++) {
        var _found = false;
        for (var _j = 0; _j < array_length(_b); _j++) {
            if (_a[_i].r == _b[_j].r && _a[_i].c == _b[_j].c) { _found = true; break; }
        }
        if (!_found) return false;
    }
    return true;
}

/// Classify a swiped path (array of {r,c}) against the puzzle.
/// Returns { kind: "main"|"bonus"|"dup"|"bad", index }.
/// A match requires the swiped CELLS to coincide with a word's cells (either
/// orientation), so the highlight always lands on real grid letters.
function ph_ww_classify_path(_puzzle, _path) {
    if (array_length(_path) < 2) return { kind: "bad", index: -1 };
    var _word = ph_ww_path_word(_puzzle, _path);
    if (_word == "") return { kind: "bad", index: -1 };
    var _rev  = "";
    for (var _i = string_length(_word); _i >= 1; _i--) _rev += string_char_at(_word, _i);

    // Hidden words — match by cells so we highlight the exact authored line.
    for (var _wi = 0; _wi < array_length(_puzzle.words); _wi++) {
        if (ph_ww_paths_match(_path, _puzzle.words[_wi].cells)) {
            if (_puzzle.words[_wi].found) return { kind: "dup", index: _wi };
            return { kind: "main", index: _wi };
        }
    }
    // Bonus words — straight-line path whose reading (either way) is in the pool.
    for (var _i = 0; _i < array_length(_puzzle.bonus_pool); _i++) {
        var _bp = _puzzle.bonus_pool[_i];
        if (_bp == _word || _bp == _rev) {
            if (_i < array_length(_puzzle.bonus_found) && _puzzle.bonus_found[_i]) {
                return { kind: "dup", index: _i };
            }
            return { kind: "bonus", index: _i };
        }
    }
    return { kind: "bad", index: -1 };
}

/// True if every hidden word is marked found.
function ph_wordwave_all_solved(_puzzle) {
    for (var _i = 0; _i < array_length(_puzzle.words); _i++) {
        if (!_puzzle.words[_i].found) return false;
    }
    return true;
}

/// Index of the first not-yet-found word, or -1 if all found. Drives the hint.
function ph_wordwave_first_unfound(_puzzle) {
    for (var _i = 0; _i < array_length(_puzzle.words); _i++) {
        if (!_puzzle.words[_i].found) return _i;
    }
    return -1;
}
