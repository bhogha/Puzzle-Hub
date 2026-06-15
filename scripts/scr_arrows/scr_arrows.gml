// ── Arrows — pure logic ───────────────────────────────────────────────────────
//
// Arrows (Arrows – Puzzle Escape): the board is packed with bent, multi-cell
// "snake" arrows. Each arrow occupies a connected orthogonal path of cells and
// ends in an arrowhead at cells[0] pointing one of 4 directions (U/D/L/R). The
// cell behind the head (cells[1]) is opposite the head direction, so the head
// visually points `head` and the tip is always the frontmost cell. Tapping
// launches the arrow SNAKE-STYLE: the tip travels straight out in the head
// direction and the body follows its own trail head-first off the board. So the
// only cells that must be clear are the straight LANE in front of the tip (from
// tip+dir to the board edge) — the body slithers through cells the arrow already
// occupied. An arrow escapes iff that tip-lane is clear of OTHER arrows
// (ph_arrows_sweep_clear). Clearing all arrows wins. There is NO loss
// state — a blocked tap only costs time (PH_ARROWS_PENALTY_SECS). See
// ARROWS_PLAN.md.
//
// Data (datafiles/puzzles_arrows.json), a plain array of entries:
//   { "date":"YYYY-MM-DD"(optional), "size":8,
//     "arrows":[ { "head":"R", "cells":[[r,c],[r,c],...] }, ... ] }
// cells[0] is the head cell; the rest trail behind in order (4-connected). The
// union of all arrows places each occupied cell in exactly one arrow with no
// overlaps, and every board is generated REVERSE-solvable (see tools/gen_arrows.py),
// so a full clear order always exists and the player can never get stuck.
//
// Runtime "alive" state (one bool per arrow — true = still on the board) is owned
// by obj_arrows; the immutable puzzle struct holds the original layout (also used
// for the win recap). Solved / sweep / hint queries live here.

// ── Load / select ─────────────────────────────────────────────────────────────
function ph_load_arrows() {
    if (variable_global_exists("ph_arrows_cache")) {
        return global.ph_arrows_cache;   // may be undefined sentinel (file missing)
    }
    var _path = working_directory + "puzzles_arrows.json";
    if (!file_exists(_path)) {
        global.ph_arrows_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_arrows_cache = json_parse(_str);
    return global.ph_arrows_cache;
}

/// Pick the puzzle for a date: exact "date" match wins, else deterministic seed.
function ph_arrows_for_date(_date_key) {
    var _list = ph_load_arrows();
    if (_list == undefined || array_length(_list) == 0) return ph_arrows_fallback();
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        if (is_struct(_e) && variable_struct_exists(_e, "date") && _e.date == _date_key) {
            return ph_arrows_make(_e);
        }
    }
    var _seed = ph_seed_from_key(_date_key);
    return ph_arrows_make(_list[_seed mod array_length(_list)]);
}

/// Normalise a raw JSON entry → runtime struct:
///   { rows, cols, arrows:[ { head, cells:[{r,c},..], len, color_idx } ] }
/// Accepts non-square boards via `rows`/`cols`; a legacy square `size` (or the
/// PH_ARROWS_ROWS/COLS defaults) is tolerated for back-compat.
function ph_arrows_make(_raw) {
    var _rows, _cols;
    if (variable_struct_exists(_raw, "rows") && variable_struct_exists(_raw, "cols")) {
        _rows = _raw.rows; _cols = _raw.cols;
    } else if (variable_struct_exists(_raw, "size")) {
        _rows = _raw.size; _cols = _raw.size;
    } else {
        _rows = PH_ARROWS_ROWS; _cols = PH_ARROWS_COLS;
    }
    var _arrows = [];
    var _src = _raw.arrows;
    for (var _i = 0; _i < array_length(_src); _i++) {
        var _a = _src[_i];
        var _head = string_upper(string(_a.head));
        var _cells = [];
        for (var _k = 0; _k < array_length(_a.cells); _k++) {
            array_push(_cells, { r: _a.cells[_k][0], c: _a.cells[_k][1] });
        }
        array_push(_arrows, {
            head:      _head,
            cells:     _cells,
            len:       array_length(_cells),
            color_idx: _i,
        });
    }
    return { rows: _rows, cols: _cols, arrows: _arrows };
}

/// Hardcoded fallback (a generator-verified, densely packed 17×14 board) when the
/// data file is missing. Identical shape to ph_arrows_make's output.
function ph_arrows_fallback() {
    var _raw = { rows: 17, cols: 14, arrows: [
        { head: "L", cells: [[4,7],[4,8],[3,8],[3,9],[2,9],[2,8],[2,7],[1,7],[1,8],[1,9],[0,9],[0,10],[0,11]] },
        { head: "L", cells: [[10,3],[10,4],[11,4],[12,4],[12,5],[13,5],[14,5],[15,5],[15,6],[14,6],[13,6],[13,7],[13,8],[13,9],[12,9],[12,10]] },
        { head: "R", cells: [[7,3],[7,2],[7,1],[7,0],[8,0],[8,1],[8,2],[8,3],[9,3],[9,2],[10,2],[11,2]] },
        { head: "D", cells: [[13,12],[12,12],[12,11],[13,11],[14,11],[14,10],[14,9],[14,8],[15,8],[15,7],[16,7],[16,8],[16,9],[16,10],[15,10]] },
        { head: "R", cells: [[5,2],[5,1],[5,0],[4,0],[4,1],[4,2],[4,3],[3,3],[3,2],[3,1],[2,1],[2,0],[3,0]] },
        { head: "U", cells: [[5,13],[6,13],[6,12],[6,11],[6,10],[6,9],[5,9],[5,8],[6,8],[7,8]] },
        { head: "R", cells: [[7,11],[7,10],[7,9],[8,9]] },
        { head: "U", cells: [[4,4],[5,4],[6,4],[7,4],[8,4],[8,5]] },
        { head: "R", cells: [[9,8],[9,7],[10,7],[10,6],[10,5]] },
        { head: "U", cells: [[0,3],[1,3],[1,2]] },
        { head: "U", cells: [[3,12],[4,12],[4,13],[3,13],[2,13]] },
        { head: "L", cells: [[15,1],[15,2],[14,2],[14,3],[14,4],[15,4],[15,3]] },
        { head: "R", cells: [[10,9],[10,8],[11,8],[12,8],[12,7],[11,7]] },
        { head: "L", cells: [[16,1],[16,2],[16,3],[16,4],[16,5],[16,6]] },
        { head: "U", cells: [[3,6],[4,6],[4,5],[5,5],[5,6],[6,6],[6,7]] },
        { head: "R", cells: [[1,13],[1,12],[1,11],[1,10],[2,10],[2,11],[2,12]] },
        { head: "R", cells: [[9,12],[9,11],[10,11]] },
        { head: "L", cells: [[10,0],[10,1],[9,1]] },
        { head: "L", cells: [[6,2],[6,3],[5,3]] },
        { head: "L", cells: [[1,0],[1,1],[0,1],[0,2]] },
        { head: "L", cells: [[13,0],[13,1],[13,2],[12,2]] },
        { head: "D", cells: [[16,13],[15,13],[14,13],[14,12]] },
        { head: "D", cells: [[16,0],[15,0],[14,0],[14,1]] },
        { head: "R", cells: [[11,13],[11,12],[11,11]] },
        { head: "U", cells: [[1,6],[2,6],[2,5],[3,5],[3,4],[2,4],[2,3]] },
        { head: "L", cells: [[12,0],[12,1],[11,1]] },
        { head: "D", cells: [[16,11],[15,11],[15,12],[16,12]] },
        { head: "R", cells: [[8,12],[8,11],[8,10],[9,10]] },
        { head: "L", cells: [[6,0],[6,1]] },
        { head: "R", cells: [[10,13],[10,12]] },
        { head: "R", cells: [[7,13],[7,12]] },
        { head: "U", cells: [[0,5],[1,5],[1,4],[0,4]] },
        { head: "R", cells: [[0,13],[0,12]] },
    ] };
    return ph_arrows_make(_raw);
}

// ── Geometry ──────────────────────────────────────────────────────────────────
/// [dr, dc] unit step for a head direction.
function ph_arrows_delta(_head) {
    switch (_head) {
        case "U": return [-1,  0];
        case "D": return [ 1,  0];
        case "L": return [ 0, -1];
        case "R": return [ 0,  1];
    }
    return [0, 0];
}

// ── Queries ───────────────────────────────────────────────────────────────────
/// Can arrow `_idx` escape right now? The arrow exits snake-style — the tip leads
/// straight out in the head direction and the body follows its own trail — so it
/// is blocked iff the straight LANE in front of the tip (cells[0]+dir … board
/// edge) holds a cell of ANOTHER currently-alive arrow. `_alive` is a bool array
/// (one per arrow). Mirrors tools/gen_arrows.py's tip_lane_clear exactly.
function ph_arrows_sweep_clear(_puzzle, _alive, _idx) {
    var _rows = _puzzle.rows;
    var _cols = _puzzle.cols;
    var _arr  = _puzzle.arrows[_idx];
    var _d    = ph_arrows_delta(_arr.head);
    var _dr   = _d[0], _dc = _d[1];

    // Occupancy of every OTHER alive arrow (row-major over the rows×cols board).
    var _occ = array_create(_rows * _cols, false);
    for (var _a = 0; _a < array_length(_puzzle.arrows); _a++) {
        if (_a == _idx || !_alive[_a]) continue;
        var _cs = _puzzle.arrows[_a].cells;
        for (var _k = 0; _k < array_length(_cs); _k++) {
            _occ[_cs[_k].r * _cols + _cs[_k].c] = true;
        }
    }

    // Tip-lane: straight from the tip (cells[0]) forward to the board edge.
    var _tip = _arr.cells[0];
    var _r = _tip.r + _dr, _c = _tip.c + _dc;
    while (_r >= 0 && _r < _rows && _c >= 0 && _c < _cols) {
        if (_occ[_r * _cols + _c]) return false;
        _r += _dr; _c += _dc;
    }
    return true;
}

/// True when no arrows remain on the board.
function ph_arrows_is_solved(_alive) {
    for (var _i = 0; _i < array_length(_alive); _i++) {
        if (_alive[_i]) return false;
    }
    return true;
}

/// Index of an alive arrow whose sweep is currently clear (a guaranteed-safe next
/// move — the hint target), or -1 if none/solved. Prefers the longest such arrow
/// so the hint feels substantial.
function ph_arrows_first_clear(_puzzle, _alive) {
    var _best = -1, _best_len = -1;
    for (var _i = 0; _i < array_length(_puzzle.arrows); _i++) {
        if (!_alive[_i]) continue;
        if (ph_arrows_sweep_clear(_puzzle, _alive, _i)) {
            if (_puzzle.arrows[_i].len > _best_len) { _best_len = _puzzle.arrows[_i].len; _best = _i; }
        }
    }
    return _best;
}

/// For a BLOCKED arrow `_idx`, describe what stops it: the number of clear cells
/// its tip can advance before it would enter an occupied cell (`gap`), and the
/// index of the OTHER alive arrow sitting in that first blocking cell (`blocker`).
/// Used by the blocked-tap feedback (lunge the arrow up to the blocker, flash both
/// red). Returns { gap:-1, blocker:-1 } if the lane is actually clear.
function ph_arrows_block_info(_puzzle, _alive, _idx) {
    var _rows = _puzzle.rows, _cols = _puzzle.cols;
    var _arr  = _puzzle.arrows[_idx];
    var _d    = ph_arrows_delta(_arr.head);
    var _dr   = _d[0], _dc = _d[1];

    // Cell → owning alive-arrow index (-1 if empty), for every OTHER alive arrow.
    var _owner = array_create(_rows * _cols, -1);
    for (var _a = 0; _a < array_length(_puzzle.arrows); _a++) {
        if (_a == _idx || !_alive[_a]) continue;
        var _cs = _puzzle.arrows[_a].cells;
        for (var _k = 0; _k < array_length(_cs); _k++) {
            _owner[_cs[_k].r * _cols + _cs[_k].c] = _a;
        }
    }

    var _tip = _arr.cells[0];
    var _r = _tip.r + _dr, _c = _tip.c + _dc;
    var _gap = 0;
    while (_r >= 0 && _r < _rows && _c >= 0 && _c < _cols) {
        var _o = _owner[_r * _cols + _c];
        if (_o != -1) return { gap: _gap, blocker: _o };
        _gap++;
        _r += _dr; _c += _dc;
    }
    return { gap: -1, blocker: -1 };
}

/// Index of the arrow whose body covers cell (r,c) among alive arrows, or -1.
function ph_arrows_at(_puzzle, _alive, _r, _c) {
    for (var _i = 0; _i < array_length(_puzzle.arrows); _i++) {
        if (!_alive[_i]) continue;
        var _cs = _puzzle.arrows[_i].cells;
        for (var _k = 0; _k < array_length(_cs); _k++) {
            if (_cs[_k].r == _r && _cs[_k].c == _c) return _i;
        }
    }
    return -1;
}

// ── Save serialise / restore ──────────────────────────────────────────────────
// save.arrows_state[date] = { cleared:"comma idx string", penalty:secs }.
// alive[i] = NOT cleared[i]. Lazy (created on first write); no backfill needed.

function ph_arrows_serialize_indices(_bools) {
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

function ph_arrows_deserialize_indices(_s, _count) {
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

function ph_arrows_save_state(_save, _date_key, _alive, _penalty) {
    if (!variable_struct_exists(_save, "arrows_state")) _save.arrows_state = {};
    var _cleared = array_create(array_length(_alive), false);
    for (var _i = 0; _i < array_length(_alive); _i++) _cleared[_i] = !_alive[_i];
    _save.arrows_state[$ _date_key] = {
        cleared: ph_arrows_serialize_indices(_cleared),
        penalty: _penalty,
    };
}

function ph_arrows_load_state(_save, _date_key, _count) {
    if (!variable_struct_exists(_save, "arrows_state")) return undefined;
    if (!variable_struct_exists(_save.arrows_state, _date_key)) return undefined;
    var _st = _save.arrows_state[$ _date_key];
    var _cleared = ph_arrows_deserialize_indices(
        variable_struct_exists(_st, "cleared") ? _st.cleared : "", _count);
    var _alive = array_create(_count, true);
    for (var _i = 0; _i < _count; _i++) _alive[_i] = !_cleared[_i];
    return {
        alive:   _alive,
        penalty: variable_struct_exists(_st, "penalty") ? _st.penalty : 0,
    };
}

// ── Completion tracking ───────────────────────────────────────────────────────
// Single "ARROWS" flag in the generic puzzles_solved map, so ph_solved_count_on
// picks it up automatically (no per-cell bookkeeping keys → no skip rule needed).

function ph_arrows_is_done(_save, _date_key) {
    return ph_is_solved(_save, _date_key, "ARROWS");
}

function ph_arrows_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "ARROWS");
}
