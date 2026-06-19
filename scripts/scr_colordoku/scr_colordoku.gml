// ── Colordoku puzzle helpers ──────────────────────────────────────────────────
//
// Colordoku is the "Queens / Meowdoku" genre: an N×N board split into N coloured
// regions. The player places exactly one queen (a teal gem) so that:
//   - every ROW has exactly one queen,
//   - every COLUMN has exactly one queen,
//   - every COLOUR REGION has exactly one queen,
//   - no two queens TOUCH, including diagonally (the LinkedIn-Queens / Meowdoku
//     rule: "Queens cannot touch other Queens"). Two queens may share a long
//     diagonal as long as they aren't in adjacent cells.
// There is no loss state (like Hue Sort / Color Link): the player just keeps
// refining placements until the board is correct.
//
// Cell state (live board) is an int per cell:
//   0 = empty, 1 = ruled-out X, 2 = queen.
// Tap toggles X (empty↔X, or clears a queen); double-tap places/removes a queen.
//
// Puzzle data (datafiles/puzzles_colordoku.json), one entry:
//
//   { "date":"YYYY-MM-DD"   (optional — exact-date authoring),
//     "size": 6,
//     "regions":  [N*N ints 0..N-1 row-major],   // colour-region id per cell
//     "solution": [N*N ints 0/1 row-major] }      // 1 = queen (unique solution)
//
// Boards ship pre-verified unique (tools/gen_colordoku.py), so the genre's
// "no guessing" promise holds. The solution array powers the win recap; the live
// win-check is rule-based (and, because the layout is unique, the only complete
// valid placement IS the solution).
//
// ph_colordoku_make() normalises a raw entry into the runtime struct:
//   { size, regions:[..], solution:[..] }

function ph_load_colordoku() {
    if (variable_global_exists("ph_colordoku_cache")) {
        return global.ph_colordoku_cache;   // may be undefined sentinel (file missing)
    }
    var _path = PH_ASSETS_PATH + "puzzles_colordoku.json";
    if (!file_exists(_path)) {
        global.ph_colordoku_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_colordoku_cache = json_parse(_str);
    return global.ph_colordoku_cache;
}

// ── Region colours (one per region id 0..N-1) ─────────────────────────────────
// Distinct bold pastels in the Meowdoku spirit. Deliberately avoids the bright
// teal accent (#5af2bc) used for the queen gem so the gem always reads on top.
function ph_colordoku_region_color(_idx) {
    static _pal = [
        make_color_rgb(240,101, 79),   // 0 coral
        make_color_rgb(242,193, 78),   // 1 amber
        make_color_rgb(155,140,255),   // 2 lavender
        make_color_rgb( 90,169,230),   // 3 sky blue
        make_color_rgb(155,207, 59),   // 4 lime
        make_color_rgb(239,127,182),   // 5 pink
        make_color_rgb(120,200,190),   // 6 spare (muted teal, distinct from gem)
        make_color_rgb(214,160,110),   // 7 spare (tan)
    ];
    return _pal[_idx mod array_length(_pal)];
}

// ── Puzzle build / selection ──────────────────────────────────────────────────

/// Pick the puzzle for a given date. 1) exact "date" match, 2) seed fallback.
function ph_colordoku_for_date(_date_key) {
    var _list = ph_load_colordoku();
    if (_list == undefined || array_length(_list) == 0) {
        return ph_colordoku_fallback();
    }
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        if (is_struct(_e) && variable_struct_exists(_e, "date") && _e.date == _date_key) {
            return ph_colordoku_make(_e);
        }
    }
    var _seed = ph_seed_from_key(_date_key);
    return ph_colordoku_make(_list[_seed mod array_length(_list)]);
}

/// Normalise a raw JSON entry into the runtime struct.
function ph_colordoku_make(_raw) {
    var _n = variable_struct_exists(_raw, "size") ? _raw.size : 6;
    var _regions  = [];
    var _solution = [];
    var _rsrc = _raw.regions;
    var _ssrc = variable_struct_exists(_raw, "solution") ? _raw.solution : [];
    for (var _i = 0; _i < _n * _n; _i++) {
        array_push(_regions,  _rsrc[_i]);
        array_push(_solution, (_i < array_length(_ssrc)) ? _ssrc[_i] : 0);
    }
    return { size: _n, regions: _regions, solution: _solution };
}

/// Minimal hard-coded puzzle used when the data file is missing (unique 6×6).
function ph_colordoku_fallback() {
    // Solution columns by row: 1,3,5,0,2,4 (one/row, one/col, |Δ|≥2, no touch).
    var _regions = [
        0,0,1,1,2,2,
        0,0,1,1,2,2,
        3,0,1,4,4,2,
        3,3,4,4,5,2,
        3,3,4,5,5,5,
        3,3,4,5,5,5
    ];
    var _solution = [
        0,1,0,0,0,0,
        0,0,0,1,0,0,
        0,0,0,0,0,1,
        1,0,0,0,0,0,
        0,0,1,0,0,0,
        0,0,0,0,1,0
    ];
    return { size: 6, regions: _regions, solution: _solution };
}

// ── Geometry / adjacency helpers ──────────────────────────────────────────────

/// True if two cell indices are 8-neighbour adjacent (touch, incl. diagonally).
function ph_colordoku_adjacent(_a, _b, _n) {
    var _ra = _a div _n, _ca = _a mod _n;
    var _rb = _b div _n, _cb = _b mod _n;
    if (_a == _b) return false;
    return (abs(_ra - _rb) <= 1) && (abs(_ca - _cb) <= 1);
}

/// True if a queen at index _a would conflict with a queen at index _b
/// (same row, same column, same region, or touching).
function ph_colordoku_pair_conflict(_a, _b, _n, _regions) {
    if (_a == _b) return false;
    var _ra = _a div _n, _ca = _a mod _n;
    var _rb = _b div _n, _cb = _b mod _n;
    if (_ra == _rb) return true;                       // same row
    if (_ca == _cb) return true;                       // same column
    if (_regions[_a] == _regions[_b]) return true;     // same colour region
    if (ph_colordoku_adjacent(_a, _b, _n)) return true; // touching
    return false;
}

// ── Live-board queries (state[] = 0 empty / 1 X / 2 queen) ────────────────────

/// Per-cell bool array: true where a placed queen conflicts with another queen.
function ph_colordoku_conflicts(_state, _n, _regions) {
    var _n2 = _n * _n;
    var _bad = array_create(_n2, false);
    for (var _i = 0; _i < _n2; _i++) {
        if (_state[_i] != 2) continue;
        for (var _j = _i + 1; _j < _n2; _j++) {
            if (_state[_j] != 2) continue;
            if (ph_colordoku_pair_conflict(_i, _j, _n, _regions)) {
                _bad[_i] = true;
                _bad[_j] = true;
            }
        }
    }
    return _bad;
}

/// Number of queens currently on the board.
function ph_colordoku_queen_count(_state) {
    var _c = 0;
    for (var _i = 0; _i < array_length(_state); _i++) if (_state[_i] == 2) _c++;
    return _c;
}

/// True when the board is correctly solved: exactly N queens, zero conflicts.
/// (One queen per row/col/region + no touch all fall out of "N queens, no
/// conflict" because there are N rows/cols/regions.)
function ph_colordoku_is_solved(_state, _n, _regions) {
    if (ph_colordoku_queen_count(_state) != _n) return false;
    var _bad = ph_colordoku_conflicts(_state, _n, _regions);
    for (var _i = 0; _i < _n * _n; _i++) if (_bad[_i]) return false;
    return true;
}

/// Indices of EMPTY cells that are logically ruled out by a currently-placed
/// queen (share its row / column / region, or touch it). These are the "obvious
/// X" cells the hint fills in one click. X cells and queens are left untouched.
function ph_colordoku_forced_x(_state, _n, _regions) {
    var _n2 = _n * _n;
    var _out = [];
    for (var _i = 0; _i < _n2; _i++) {
        if (_state[_i] != 0) continue;                 // only blanks become X
        var _ruled = false;
        for (var _q = 0; _q < _n2; _q++) {
            if (_state[_q] != 2) continue;
            if (ph_colordoku_pair_conflict(_i, _q, _n, _regions)) { _ruled = true; break; }
        }
        if (_ruled) array_push(_out, _i);
    }
    return _out;
}

/// True if the hint would do anything (≥1 blank cell is forced to X).
function ph_colordoku_has_forced_x(_state, _n, _regions) {
    return array_length(ph_colordoku_forced_x(_state, _n, _regions)) > 0;
}

// ── Save (serialise / restore in-progress board) ──────────────────────────────
// The live board is stored as a string of N*N digits ("0"/"1"/"2"), keyed by
// date under save.colordoku_state[date] = { cells }. Mirrors the other puzzles.
// colordoku_state is created lazily, so older saves need no backfill.

function ph_colordoku_state_to_str(_state) {
    var _s = "";
    for (var _i = 0; _i < array_length(_state); _i++) _s += string(_state[_i]);
    return _s;
}

function ph_colordoku_str_to_state(_s, _n2) {
    var _out = array_create(_n2, 0);
    if (!is_string(_s)) return _out;
    var _len = min(string_length(_s), _n2);
    for (var _i = 1; _i <= _len; _i++) {
        var _ch = string_char_at(_s, _i);
        _out[_i - 1] = (_ch == "2") ? 2 : ((_ch == "1") ? 1 : 0);
    }
    return _out;
}

/// Persist the live board, plus (optionally) which cells hold a hint-placed
/// LOCKED X — stored as a parallel "0"/"1" string so the no-remove rule survives
/// a resume. _xlock is a bool array (NCELLS) or undefined to keep the existing one.
function ph_colordoku_save_state(_save, _date_key, _state, _xlock = undefined) {
    if (!variable_struct_exists(_save, "colordoku_state")) _save.colordoku_state = {};
    var _rec = { cells: ph_colordoku_state_to_str(_state) };
    if (!is_undefined(_xlock)) {
        var _s = "";
        for (var _i = 0; _i < array_length(_xlock); _i++) _s += _xlock[_i] ? "1" : "0";
        _rec.xlock = _s;
    } else if (variable_struct_exists(_save.colordoku_state, _date_key)
            && variable_struct_exists(_save.colordoku_state[$ _date_key], "xlock")) {
        _rec.xlock = _save.colordoku_state[$ _date_key].xlock;   // preserve existing
    }
    _save.colordoku_state[$ _date_key] = _rec;
}

/// Read the saved live board for a date as an int array, or undefined.
function ph_colordoku_load_state(_save, _date_key, _n2) {
    if (!variable_struct_exists(_save, "colordoku_state")) return undefined;
    if (!variable_struct_exists(_save.colordoku_state, _date_key)) return undefined;
    var _st = _save.colordoku_state[$ _date_key];
    if (!variable_struct_exists(_st, "cells")) return undefined;
    return ph_colordoku_str_to_state(_st.cells, _n2);
}

/// Read the saved hint-locked-X mask for a date as a bool array, or undefined.
function ph_colordoku_load_xlock(_save, _date_key, _n2) {
    if (!variable_struct_exists(_save, "colordoku_state")) return undefined;
    if (!variable_struct_exists(_save.colordoku_state, _date_key)) return undefined;
    var _st = _save.colordoku_state[$ _date_key];
    if (!variable_struct_exists(_st, "xlock") || !is_string(_st.xlock)) return undefined;
    var _out = array_create(_n2, false);
    var _len = min(string_length(_st.xlock), _n2);
    for (var _i = 1; _i <= _len; _i++) _out[_i - 1] = (string_char_at(_st.xlock, _i) == "1");
    return _out;
}

// ── Completion tracking ───────────────────────────────────────────────────────
// Single "COLORDOKU" flag in the generic puzzles_solved map, counted by
// ph_solved_count_on() like every other puzzle. The daily goal is "any
// PH_PUZZLES_PER_DAY (10) solves out of all available puzzles" (currently 11),
// so Colordoku counts toward the count / 4th-puzzle gift / streak / perfect day;
// the hub just caps the displayed count at the goal (see obj_hub Draw).

function ph_colordoku_is_done(_save, _date_key) {
    return ph_is_solved(_save, _date_key, "COLORDOKU");
}

function ph_colordoku_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "COLORDOKU");
}
