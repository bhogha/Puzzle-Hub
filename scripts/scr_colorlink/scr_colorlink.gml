// ── Color Link (Flow Free) — pure logic ───────────────────────────────────────
//
// Color Link: connect each pair of matching coloured dots with a continuous line
// so that the lines never cross AND every cell of the N×N grid is filled. Classic
// "Flow Free". There is no loss state.
//
// Puzzle data (datafiles/puzzles_colorlink.json) is a plain array of entries:
//
//   { "date": "YYYY-MM-DD"  (optional — exact-date authoring),
//     "size": 6,
//     "flows": [ { "color": 0, "a":[r,c], "b":[r,c],
//                  "path":[[r,c],[r,c], ...] }, ... ] }
//
// `a` / `b` are the two endpoint dots; `path` is the full solution route from a to
// b covering every cell it owns. The union of all flow paths tiles the board, so a
// puzzle is always solvable. `path` also powers the hint (reveal the longest line).
//
// ph_colorlink_make() normalises a raw entry into the runtime struct:
//   { size, flows:[ { color, a:{r,c}, b:{r,c}, path:[{r,c}..], len } ] }
//
// The live board is owned by obj_colorlink as `route` — one ordered array of cell
// indices per flow (empty until the player draws it). Solved is checked here.

// ── Vibrant flow palette (reuses the hub game accents per design note) ────────
/// GameMaker colour for a flow colour index. 10 distinct hues; the 9×7 board uses
/// 6–7 flows, well within the palette without colour reuse (cycled past that).
function ph_colorlink_color(_idx) {
    var _pal = [
        PH_COL_PINK, PH_COL_TEAL,   PH_COL_PURPLE,    PH_COL_ORANGE,
        PH_COL_BLUE, PH_COL_GREEN,  PH_COL_VIOLET,    PH_COL_YELLOW,
        PH_COL_TANGERINE, PH_COL_SKYBLUE,
    ];
    return _pal[_idx mod array_length(_pal)];
}

// ── Load / select ─────────────────────────────────────────────────────────────
function ph_load_colorlinks() {
    if (variable_global_exists("ph_colorlink_cache")) {
        return global.ph_colorlink_cache;   // may be undefined sentinel (file missing)
    }
    var _path = working_directory + "puzzles_colorlink.json";
    if (!file_exists(_path)) {
        global.ph_colorlink_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_colorlink_cache = json_parse(_str);
    return global.ph_colorlink_cache;
}

/// Pick the puzzle for a date: exact "date" match wins, else deterministic seed.
function ph_colorlink_for_date(_date_key) {
    var _list = ph_load_colorlinks();
    if (_list == undefined || array_length(_list) == 0) return ph_colorlink_fallback();
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        if (is_struct(_e) && variable_struct_exists(_e, "date") && _e.date == _date_key) {
            return ph_colorlink_make(_e);
        }
    }
    var _seed = ph_seed_from_key(_date_key);
    return ph_colorlink_make(_list[_seed mod array_length(_list)]);
}

/// Normalise a raw JSON entry → runtime struct (a/b/path as {r,c}, cached length).
/// Supports non-square boards via "rows"/"cols"; legacy square "size" still works.
function ph_colorlink_make(_raw) {
    var _cols = variable_struct_exists(_raw, "cols") ? _raw.cols
              : (variable_struct_exists(_raw, "size") ? _raw.size : 9);
    var _rows = variable_struct_exists(_raw, "rows") ? _raw.rows
              : (variable_struct_exists(_raw, "size") ? _raw.size : _cols);
    var _flows = [];
    var _src = _raw.flows;
    for (var _i = 0; _i < array_length(_src); _i++) {
        var _f = _src[_i];
        var _path = [];
        for (var _p = 0; _p < array_length(_f.path); _p++) {
            array_push(_path, { r: _f.path[_p][0], c: _f.path[_p][1] });
        }
        array_push(_flows, {
            color: variable_struct_exists(_f, "color") ? _f.color : _i,
            a:   { r: _f.a[0], c: _f.a[1] },
            b:   { r: _f.b[0], c: _f.b[1] },
            path: _path,
            len:  array_length(_path),
        });
    }
    // `size` kept = cols for any legacy reader; rows/cols are authoritative.
    return { rows: _rows, cols: _cols, size: _cols, flows: _flows };
}

/// Hardcoded fallback (a validated 9×7, 7-flow board) when the data file is missing.
function ph_colorlink_fallback() {
    var _raw = {
        rows: 9, cols: 7,
        flows: [
            { color: 0, a: [6,0], b: [8,0], path: [[6,0],[6,1],[6,2],[7,2],[7,1],[7,0],[8,0]] },
            { color: 1, a: [8,1], b: [7,4], path: [[8,1],[8,2],[8,3],[8,4],[8,5],[8,6],[7,6],[6,6],[6,5],[7,5],[7,4]] },
            { color: 2, a: [7,3], b: [5,1], path: [[7,3],[6,3],[6,4],[5,4],[5,3],[5,2],[5,1]] },
            { color: 3, a: [5,0], b: [3,2], path: [[5,0],[4,0],[4,1],[4,2],[4,3],[3,3],[3,2]] },
            { color: 4, a: [2,2], b: [0,1], path: [[2,2],[2,1],[3,1],[3,0],[2,0],[1,0],[0,0],[0,1]] },
            { color: 5, a: [1,1], b: [0,4], path: [[1,1],[1,2],[0,2],[0,3],[1,3],[2,3],[2,4],[3,4],[3,5],[2,5],[1,5],[1,4],[0,4]] },
            { color: 6, a: [0,5], b: [4,4], path: [[0,5],[0,6],[1,6],[2,6],[3,6],[4,6],[5,6],[5,5],[4,5],[4,4]] },
        ],
    };
    return ph_colorlink_make(_raw);
}

// ── Queries ───────────────────────────────────────────────────────────────────
/// Flow colour index whose endpoint sits at (r,c), or -1 if none.
function ph_colorlink_endpoint_color(_puzzle, _r, _c) {
    for (var _i = 0; _i < array_length(_puzzle.flows); _i++) {
        var _f = _puzzle.flows[_i];
        if ((_f.a.r == _r && _f.a.c == _c) || (_f.b.r == _r && _f.b.c == _c)) return _i;
    }
    return -1;
}

/// True when `route` (one cell-index array per flow) solves the puzzle:
/// every flow connects its two endpoints with a contiguous line, lines never
/// overlap, and every cell is covered. Mirrors the Flow Free win rule.
function ph_colorlink_is_solved(_puzzle, _route) {
    var _cols = _puzzle.cols;
    var _nc   = _puzzle.rows * _cols;
    var _cov = array_create(_nc, -1);
    for (var _f = 0; _f < array_length(_puzzle.flows); _f++) {
        var _r   = _route[_f];
        var _len = array_length(_r);
        if (_len < 2) return false;                       // flow not drawn yet
        var _fl = _puzzle.flows[_f];
        var _a  = _fl.a.r * _cols + _fl.a.c;
        var _b  = _fl.b.r * _cols + _fl.b.c;
        if (!((_r[0] == _a && _r[_len-1] == _b) ||
              (_r[0] == _b && _r[_len-1] == _a))) return false;   // endpoints
        for (var _i = 0; _i < _len; _i++) {
            var _ci = _r[_i];
            if (_ci < 0 || _ci >= _nc) return false;
            if (_cov[_ci] != -1) return false;            // overlap / crossing
            _cov[_ci] = _f;
            if (_i > 0) {                                  // contiguity
                var _pr = _r[_i-1];
                if (abs(_ci div _cols - _pr div _cols) + abs(_ci mod _cols - _pr mod _cols) != 1) return false;
            }
        }
    }
    for (var _i = 0; _i < _nc; _i++) if (_cov[_i] == -1) return false;  // full coverage
    return true;
}

/// Index of the flow with the LONGEST solution path that is not yet correctly
/// drawn, or -1 if none remain. Used by the hint ("unravel the longest line").
/// `_correct` is a bool array (one per flow) flagging already-solved flows.
function ph_colorlink_longest_unsolved(_puzzle, _correct) {
    var _best = -1, _best_len = -1;
    for (var _i = 0; _i < array_length(_puzzle.flows); _i++) {
        if (_correct[_i]) continue;
        if (_puzzle.flows[_i].len > _best_len) { _best_len = _puzzle.flows[_i].len; _best = _i; }
    }
    return _best;
}

// ── Save serialise / restore ──────────────────────────────────────────────────
// `route` is serialised as one cell-index list per flow ("3,9,15"), flows joined
// by "|". Hint-locked flow indices are a separate "i,j" string. Stored under
// save.colorlink_state[date] = { routes, hints } (lazy, no backfill needed).

function ph_colorlink_serialize_routes(_route) {
    var _s = "";
    for (var _f = 0; _f < array_length(_route); _f++) {
        if (_f > 0) _s += "|";
        var _r = _route[_f];
        for (var _i = 0; _i < array_length(_r); _i++) {
            if (_i > 0) _s += ",";
            _s += string(_r[_i]);
        }
    }
    return _s;
}

function ph_colorlink_deserialize_routes(_s, _nflows) {
    var _route = array_create(_nflows);
    for (var _f = 0; _f < _nflows; _f++) _route[_f] = [];
    if (!is_string(_s) || _s == "") return _route;
    var _parts = string_split(_s, "|");
    for (var _f = 0; _f < min(_nflows, array_length(_parts)); _f++) {
        if (_parts[_f] == "") continue;
        var _cells = string_split(_parts[_f], ",");
        for (var _i = 0; _i < array_length(_cells); _i++) array_push(_route[_f], real(_cells[_i]));
    }
    return _route;
}

function ph_colorlink_save_state(_save, _date_key, _route, _hint_indices) {
    if (!variable_struct_exists(_save, "colorlink_state")) _save.colorlink_state = {};
    var _hints = "";
    for (var _i = 0; _i < array_length(_hint_indices); _i++) {
        if (_i > 0) _hints += ",";
        _hints += string(_hint_indices[_i]);
    }
    _save.colorlink_state[$ _date_key] = {
        routes: ph_colorlink_serialize_routes(_route),
        hints:  _hints,
    };
}

function ph_colorlink_load_state(_save, _date_key, _nflows) {
    if (!variable_struct_exists(_save, "colorlink_state")) return undefined;
    if (!variable_struct_exists(_save.colorlink_state, _date_key)) return undefined;
    var _st = _save.colorlink_state[$ _date_key];
    var _hints = [];
    if (variable_struct_exists(_st, "hints") && is_string(_st.hints) && _st.hints != "") {
        var _hp = string_split(_st.hints, ",");
        for (var _i = 0; _i < array_length(_hp); _i++) array_push(_hints, real(_hp[_i]));
    }
    return {
        routes: ph_colorlink_deserialize_routes(
                    variable_struct_exists(_st, "routes") ? _st.routes : "", _nflows),
        hints:  _hints,
    };
}

// ── Completion tracking ───────────────────────────────────────────────────────
// Single "COLORLINK" flag in the generic puzzles_solved map, so ph_solved_count_on
// picks it up automatically (no per-cell bookkeeping keys → no skip rule needed).

function ph_colorlink_is_done(_save, _date_key) {
    return ph_is_solved(_save, _date_key, "COLORLINK");
}

function ph_colorlink_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "COLORLINK");
}
