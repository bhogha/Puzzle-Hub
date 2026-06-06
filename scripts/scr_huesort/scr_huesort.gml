// ── Hue Sort puzzle helpers ───────────────────────────────────────────────────
//
// Hue Sort: an N×N grid of colour tiles forms a smooth 2-D gradient. The four
// CORNER tiles are locked anchors; the player swaps the interior tiles (drag and
// drop) until every tile sits in its correct gradient position. Solving is purely
// positional — there is no loss state (unlike Wordle).
//
// Puzzle data (datafiles/puzzles_huesort.json), one entry:
//
//   { "date": "YYYY-MM-DD"   (optional — exact-date authoring),
//     "size": 5,
//     "corners": { "tl":"RRGGBB", "tr":"RRGGBB", "bl":"RRGGBB", "br":"RRGGBB" } }
//
// The four corner colours fully define the board: every cell's target colour is
// the bilinear interpolation of the corners, so authoring stays tiny.
//
// ph_huesort_make() normalises a raw entry into the runtime struct:
//
//   { size, target:[{r,g,b}, ..]  (row-major),
//            locked:[bool, ..] }   (true at the four corners)
//
// The live board is an array of {r,g,b} (one per position); a swap exchanges two
// non-locked entries. Solved = every position's colour equals its target colour.

function ph_load_huesorts() {
    if (variable_global_exists("ph_huesort_cache")) {
        return global.ph_huesort_cache;   // may be undefined sentinel (file missing)
    }
    var _path = working_directory + "puzzles_huesort.json";
    if (!file_exists(_path)) {
        global.ph_huesort_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_huesort_cache = json_parse(_str);
    return global.ph_huesort_cache;
}

// ── Colour helpers (hex ⇄ {r,g,b}) ────────────────────────────────────────────

/// Single hex char ("0".."F") → 0..15.
function ph_huesort_hex_digit(_ch) {
    var _p = string_pos(string_upper(_ch), "0123456789ABCDEF");
    return (_p > 0) ? (_p - 1) : 0;
}

/// Two hex chars → 0..255.
function ph_huesort_hex_pair(_pair) {
    return ph_huesort_hex_digit(string_char_at(_pair, 1)) * 16
         + ph_huesort_hex_digit(string_char_at(_pair, 2));
}

/// "RRGGBB" (tolerates a leading '#') → {r,g,b}.
function ph_huesort_hex(_hex) {
    var _s = string_upper(string(_hex));
    if (string_char_at(_s, 1) == "#") _s = string_copy(_s, 2, string_length(_s) - 1);
    return {
        r: ph_huesort_hex_pair(string_copy(_s, 1, 2)),
        g: ph_huesort_hex_pair(string_copy(_s, 3, 2)),
        b: ph_huesort_hex_pair(string_copy(_s, 5, 2)),
    };
}

/// 0..255 → two hex chars.
function ph_huesort_hex2(_n) {
    var _v = clamp(round(_n), 0, 255);
    var _digits = "0123456789ABCDEF";
    return string_char_at(_digits, (_v div 16) + 1) + string_char_at(_digits, (_v mod 16) + 1);
}

/// {r,g,b} → "RRGGBB" (used for save serialisation).
function ph_huesort_to_hex(_rgb) {
    return ph_huesort_hex2(_rgb.r) + ph_huesort_hex2(_rgb.g) + ph_huesort_hex2(_rgb.b);
}

/// {r,g,b} → a GameMaker colour value (for drawing).
function ph_huesort_col(_rgb) {
    return make_color_rgb(_rgb.r, _rgb.g, _rgb.b);
}

/// Component-wise lerp of two {r,g,b} at fraction _t (0..1).
function ph_huesort_lerp_rgb(_a, _b, _t) {
    return {
        r: round(lerp(_a.r, _b.r, _t)),
        g: round(lerp(_a.g, _b.g, _t)),
        b: round(lerp(_a.b, _b.b, _t)),
    };
}

/// True when two {r,g,b} structs are component-equal.
function ph_huesort_rgb_eq(_a, _b) {
    return (_a.r == _b.r && _a.g == _b.g && _a.b == _b.b);
}

// ── Puzzle build / selection ──────────────────────────────────────────────────

/// Pick the puzzle for a given date. Selection mirrors the other games:
///   1. Exact "date" match wins.
///   2. Otherwise deterministic seed fallback so every calendar day is stable.
function ph_huesort_for_date(_date_key) {
    var _list = ph_load_huesorts();
    if (_list == undefined || array_length(_list) == 0) {
        return ph_huesort_fallback();
    }
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        if (is_struct(_e) && variable_struct_exists(_e, "date") && _e.date == _date_key) {
            return ph_huesort_make(_e);
        }
    }
    var _seed = ph_seed_from_key(_date_key);
    return ph_huesort_make(_list[_seed mod array_length(_list)]);
}

/// Build the runtime struct from a raw JSON entry (bilinear corner gradient).
function ph_huesort_make(_raw) {
    var _n  = variable_struct_exists(_raw, "size") ? _raw.size : PH_HUESORT_SIZE;
    var _c  = _raw.corners;
    var _tl = ph_huesort_hex(_c.tl);
    var _tr = ph_huesort_hex(_c.tr);
    var _bl = ph_huesort_hex(_c.bl);
    var _br = ph_huesort_hex(_c.br);

    var _target = [];
    var _locked = [];
    for (var _r = 0; _r < _n; _r++) {
        var _fy = (_n > 1) ? (_r / (_n - 1)) : 0;
        for (var _col = 0; _col < _n; _col++) {
            var _fx  = (_n > 1) ? (_col / (_n - 1)) : 0;
            var _top = ph_huesort_lerp_rgb(_tl, _tr, _fx);
            var _bot = ph_huesort_lerp_rgb(_bl, _br, _fx);
            array_push(_target, ph_huesort_lerp_rgb(_top, _bot, _fy));
            var _is_corner = ((_r == 0 || _r == _n - 1) && (_col == 0 || _col == _n - 1));
            array_push(_locked, _is_corner);
        }
    }
    return { size: _n, target: _target, locked: _locked };
}

/// Minimal hard-coded puzzle used when the data file is missing.
function ph_huesort_fallback() {
    return ph_huesort_make({
        size: PH_HUESORT_SIZE,
        corners: { tl: "FF3B6B", tr: "FFC233", bl: "7B3FF2", br: "14B8A6" },
    });
}

// ── Scramble + solved checks ──────────────────────────────────────────────────

/// Build the scrambled starting board: a copy of the target colours with the
/// interior (non-locked) tiles shuffled deterministically by the date seed, so
/// every player sees the same puzzle on the same calendar day.
function ph_huesort_scramble(_puzzle, _date_key) {
    var _n2  = _puzzle.size * _puzzle.size;
    var _cur = array_create(_n2);
    for (var _i = 0; _i < _n2; _i++) _cur[_i] = _puzzle.target[_i];

    // Movable (non-corner) positions.
    var _free = [];
    for (var _i = 0; _i < _n2; _i++) if (!_puzzle.locked[_i]) array_push(_free, _i);
    var _m = array_length(_free);
    if (_m < 2) return _cur;

    random_set_seed(ph_seed_from_key(_date_key));
    // Fisher-Yates over the free positions only.
    for (var _i = _m - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _a = _free[_i], _b = _free[_j];
        var _t = _cur[_a]; _cur[_a] = _cur[_b]; _cur[_b] = _t;
    }
    randomize();   // restore non-deterministic RNG for the rest of the game

    // Guarantee the board isn't already solved (degenerate / tiny gradients):
    // rotate the free tiles by one, which changes the arrangement unless every
    // free tile is identical (impossible for a real gradient).
    if (ph_huesort_is_solved_arr(_puzzle, _cur)) {
        var _first = _cur[_free[0]];
        for (var _k = 0; _k < _m - 1; _k++) _cur[_free[_k]] = _cur[_free[_k + 1]];
        _cur[_free[_m - 1]] = _first;
    }
    return _cur;
}

/// True when board arrangement _cur matches the puzzle's target everywhere.
function ph_huesort_is_solved_arr(_puzzle, _cur) {
    var _n2 = _puzzle.size * _puzzle.size;
    if (array_length(_cur) != _n2) return false;
    for (var _i = 0; _i < _n2; _i++) {
        if (!ph_huesort_rgb_eq(_cur[_i], _puzzle.target[_i])) return false;
    }
    return true;
}

// ── Save (serialise / restore in-progress board) ──────────────────────────────
//
// The live board is stored as "RRGGBB,RRGGBB,..." and hint-locked indices as
// "i,j,k", both keyed by date under save.huesort_state[date] = {tiles, hints}.
// Mirrors the Shikaku state layout. (huesort_state is created lazily, so older
// saves need no backfill in ph_save_load.)

function ph_huesort_arr_to_str(_cur) {
    var _s = "";
    for (var _i = 0; _i < array_length(_cur); _i++) {
        if (_i > 0) _s += ",";
        _s += ph_huesort_to_hex(_cur[_i]);
    }
    return _s;
}

function ph_huesort_str_to_arr(_s) {
    var _out = [];
    if (!is_string(_s) || _s == "") return _out;
    var _parts = string_split(_s, ",");
    for (var _i = 0; _i < array_length(_parts); _i++) {
        array_push(_out, ph_huesort_hex(_parts[_i]));
    }
    return _out;
}

/// Persist the live board + revealed hint positions for resume.
function ph_huesort_save_state(_save, _date_key, _cur, _hint_indices) {
    if (!variable_struct_exists(_save, "huesort_state")) _save.huesort_state = {};
    var _hints = "";
    for (var _i = 0; _i < array_length(_hint_indices); _i++) {
        if (_i > 0) _hints += ",";
        _hints += string(_hint_indices[_i]);
    }
    _save.huesort_state[$ _date_key] = {
        tiles: ph_huesort_arr_to_str(_cur),
        hints: _hints,
    };
}

/// Read a saved {tiles:[{r,g,b}..], hints:[...]} for a date, or undefined.
function ph_huesort_load_state(_save, _date_key) {
    if (!variable_struct_exists(_save, "huesort_state")) return undefined;
    if (!variable_struct_exists(_save.huesort_state, _date_key)) return undefined;
    var _st = _save.huesort_state[$ _date_key];
    var _hints = [];
    if (variable_struct_exists(_st, "hints") && is_string(_st.hints) && _st.hints != "") {
        var _hp = string_split(_st.hints, ",");
        for (var _i = 0; _i < array_length(_hp); _i++) array_push(_hints, real(_hp[_i]));
    }
    return {
        tiles: ph_huesort_str_to_arr(variable_struct_exists(_st, "tiles") ? _st.tiles : ""),
        hints: _hints,
    };
}

// ── Completion tracking ───────────────────────────────────────────────────────
// Completion is tracked through the generic puzzles_solved map under the
// "HUESORT" key, so ph_solved_count_on() picks it up automatically (single flag,
// no per-tile bookkeeping keys, so no skip rule is needed).

/// True if Hue Sort for the given date has been completed.
function ph_huesort_is_done(_save, _date_key) {
    return ph_is_solved(_save, _date_key, "HUESORT");
}

/// Mark Hue Sort complete for the given date. Hub reads this single flag.
function ph_huesort_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "HUESORT");
}
