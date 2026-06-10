// ── Word Bend — pure logic ────────────────────────────────────────────────────
//
// Word Bend: the board (4×4 … 6×6) is completely filled with letters. Every letter
// belongs to exactly one hidden word, and the words' cell-paths tile the whole
// board with no gaps and no overlaps. To find a word the player taps its first
// letter and drags across the rest; the path may BEND at right angles but only
// steps orthogonally (no diagonals). There is no loss state and no bonus word.
//
// Puzzle data (datafiles/puzzles_wordbend.json) is a plain array of entries:
//
//   { "date": "YYYY-MM-DD"  (optional — exact-date authoring),
//     "size": 6,
//     "words": [ { "text":"WORD", "path":[[r,c],[r,c], ...] }, ... ] }
//
// `path` lists the cells the word occupies, in spelling order (path[k] holds
// text[k]). The union of every word's path must cover all size×size cells exactly
// once, so the board is always fully solvable. `path` also powers the hint
// (reveal the first letter of the longest still-unfound word).
//
// ph_wordbend_make() normalises a raw entry into the runtime struct:
//   { size, grid:[[char,..],..], words:[ { text, cells:[{r,c},..], len } ] }
// The live "found" state is owned by obj_wordbend (one bool per word). Solved is
// checked here.

// ── Load / select ─────────────────────────────────────────────────────────────
function ph_load_wordbends() {
    if (variable_global_exists("ph_wordbend_cache")) {
        return global.ph_wordbend_cache;   // may be undefined sentinel (file missing)
    }
    var _path = working_directory + "puzzles_wordbend.json";
    if (!file_exists(_path)) {
        global.ph_wordbend_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_wordbend_cache = json_parse(_str);
    return global.ph_wordbend_cache;
}

/// Pick the puzzle for a date: exact "date" match wins, else deterministic seed.
function ph_wordbend_for_date(_date_key) {
    var _list = ph_load_wordbends();
    if (_list == undefined || array_length(_list) == 0) return ph_wordbend_fallback();
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        if (is_struct(_e) && variable_struct_exists(_e, "date") && _e.date == _date_key) {
            return ph_wordbend_make(_e);
        }
    }
    var _seed = ph_seed_from_key(_date_key);
    return ph_wordbend_make(_list[_seed mod array_length(_list)]);
}

/// Normalise a raw JSON entry → runtime struct. Builds the letter grid by placing
/// each word's characters along its path.
function ph_wordbend_make(_raw) {
    var _n = variable_struct_exists(_raw, "size") ? _raw.size : 6;

    var _grid = array_create(_n);
    for (var _r = 0; _r < _n; _r++) {
        _grid[_r] = array_create(_n, "");
    }

    var _words = [];
    var _src = _raw.words;
    for (var _i = 0; _i < array_length(_src); _i++) {
        var _w    = _src[_i];
        var _text = string_upper(string(_w.text));
        var _cells = [];
        for (var _p = 0; _p < array_length(_w.path); _p++) {
            var _cr = _w.path[_p][0];
            var _cc = _w.path[_p][1];
            array_push(_cells, { r: _cr, c: _cc });
            // Place this word's letter on the board (skip if path runs longer than text).
            if (_p < string_length(_text) && _cr >= 0 && _cr < _n && _cc >= 0 && _cc < _n) {
                _grid[_cr][_cc] = string_char_at(_text, _p + 1);
            }
        }
        array_push(_words, {
            text:  _text,
            cells: _cells,
            len:   array_length(_cells),
        });
    }
    return { size: _n, grid: _grid, words: _words };
}

/// Hardcoded fallback (a validated 4×4 board) when the data file is missing.
function ph_wordbend_fallback() {
    var _raw = {
        size: 4,
        words: [
            { text: "CARD", path: [[0,0],[0,1],[0,2],[0,3]] },
            { text: "MOON", path: [[1,0],[1,1],[1,2],[1,3]] },
            { text: "LIME", path: [[2,0],[2,1],[2,2],[2,3]] },
            { text: "SNAP", path: [[3,0],[3,1],[3,2],[3,3]] },
        ],
    };
    return ph_wordbend_make(_raw);
}

// ── Queries ───────────────────────────────────────────────────────────────────
/// Index of the word whose ordered cell-path equals the traced cell-index list
/// `_seq` (forward OR reversed) and that is not already found, or -1 if none.
/// `_found` is a bool array (one per word). N is the board size.
function ph_wordbend_match(_puzzle, _seq, _found, _n) {
    var _len = array_length(_seq);
    if (_len < 2) return -1;
    for (var _w = 0; _w < array_length(_puzzle.words); _w++) {
        if (_found[_w]) continue;
        var _cells = _puzzle.words[_w].cells;
        if (array_length(_cells) != _len) continue;
        // Forward
        var _fwd = true;
        for (var _i = 0; _i < _len; _i++) {
            if (_cells[_i].r * _n + _cells[_i].c != _seq[_i]) { _fwd = false; break; }
        }
        if (_fwd) return _w;
        // Reversed
        var _rev = true;
        for (var _i = 0; _i < _len; _i++) {
            if (_cells[_len-1-_i].r * _n + _cells[_len-1-_i].c != _seq[_i]) { _rev = false; break; }
        }
        if (_rev) return _w;
    }
    return -1;
}

/// True when every word has been found.
function ph_wordbend_is_solved(_puzzle, _found) {
    for (var _w = 0; _w < array_length(_puzzle.words); _w++) {
        if (!_found[_w]) return false;
    }
    return true;
}

/// Index of the LONGEST still-unfound word, or -1 if none remain. Used by the hint
/// (reveal the first letter of the longest word).
function ph_wordbend_longest_unfound(_puzzle, _found) {
    var _best = -1, _best_len = -1;
    for (var _w = 0; _w < array_length(_puzzle.words); _w++) {
        if (_found[_w]) continue;
        if (_puzzle.words[_w].len > _best_len) { _best_len = _puzzle.words[_w].len; _best = _w; }
    }
    return _best;
}

// ── Save serialise / restore ──────────────────────────────────────────────────
// found-word indices and hinted-word indices are each stored as a comma string
// under save.wordbend_state[date] = { found, hints } (lazy, no backfill needed).

function ph_wordbend_serialize_indices(_bools) {
    var _s = "";
    var _first = true;
    for (var _i = 0; _i < array_length(_bools); _i++) {
        if (_bools[_i]) {
            if (!_first) _s += ",";
            _s += string(_i);
            _first = false;
        }
    }
    return _s;
}

function ph_wordbend_deserialize_indices(_s, _count) {
    var _bools = array_create(_count, false);
    if (!is_string(_s) || _s == "") return _bools;
    var _parts = string_split(_s, ",");
    for (var _i = 0; _i < array_length(_parts); _i++) {
        if (_parts[_i] == "") continue;
        var _idx = real(_parts[_i]);
        if (_idx >= 0 && _idx < _count) _bools[_idx] = true;
    }
    return _bools;
}

function ph_wordbend_save_state(_save, _date_key, _found, _hinted) {
    if (!variable_struct_exists(_save, "wordbend_state")) _save.wordbend_state = {};
    _save.wordbend_state[$ _date_key] = {
        found: ph_wordbend_serialize_indices(_found),
        hints: ph_wordbend_serialize_indices(_hinted),
    };
}

function ph_wordbend_load_state(_save, _date_key, _count) {
    if (!variable_struct_exists(_save, "wordbend_state")) return undefined;
    if (!variable_struct_exists(_save.wordbend_state, _date_key)) return undefined;
    var _st = _save.wordbend_state[$ _date_key];
    return {
        found:  ph_wordbend_deserialize_indices(
                    variable_struct_exists(_st, "found") ? _st.found : "", _count),
        hinted: ph_wordbend_deserialize_indices(
                    variable_struct_exists(_st, "hints") ? _st.hints : "", _count),
    };
}

// ── Completion tracking ───────────────────────────────────────────────────────
// Single "WORDBEND" flag in the generic puzzles_solved map, so ph_solved_count_on
// picks it up automatically (no per-cell bookkeeping keys → no skip rule needed).

function ph_wordbend_is_done(_save, _date_key) {
    return ph_is_solved(_save, _date_key, "WORDBEND");
}

function ph_wordbend_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "WORDBEND");
}
