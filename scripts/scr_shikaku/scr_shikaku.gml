// ── Shikaku puzzle helpers ────────────────────────────────────────────────────
//
// Shikaku ("divide by squares"): partition the grid into rectangles so that each
// rectangle contains exactly one number and that number equals the rectangle's
// area (cell count). Every cell ends up inside exactly one rectangle.
//
// Puzzle data is loaded from datafiles/puzzles_shikaku.json. Each entry:
//
//   { "date": "YYYY-MM-DD"   (optional — exact-date authoring),
//     "size": 6,
//     "rects": [ {"r","c","w","h","cr","cc"}, .. ] }
//
// where (r,c) = rectangle top-left, w = width (cols), h = height (rows),
// value = w*h, and (cr,cc) = the cell that hosts the printed number (inside the
// rectangle). The "rects" list is BOTH the clue source and the (unique) solution.
//
// ph_shikaku_make() normalizes a raw entry into the runtime struct:
//
//   {
//     size:      6,
//     clues:     [{r,c,val}, ..],          // numbers shown on the grid
//     sol_rects: [{r,c,w,h,val}, ..],      // solution rect, parallel to clues[i]
//   }
//
// clue[i] sits inside sol_rects[i]. Indexing for grids elsewhere is row-major.

function ph_load_shikakus() {
    if (variable_global_exists("ph_shikaku_cache")) {
        return global.ph_shikaku_cache;   // may be undefined sentinel (file missing)
    }
    var _path = PH_ASSETS_PATH + "puzzles_shikaku.json";
    if (!file_exists(_path)) {
        global.ph_shikaku_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_shikaku_cache = json_parse(_str);
    return global.ph_shikaku_cache;
}

/// Pick the puzzle for a given date. Selection mirrors the other games:
///   1. Exact "date" match wins.
///   2. Otherwise deterministic seed fallback so every calendar day is stable.
function ph_shikaku_for_date(_date_key) {
    var _list = ph_load_shikakus();
    if (_list == undefined || array_length(_list) == 0) {
        return ph_shikaku_fallback();
    }
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        if (is_struct(_e) && variable_struct_exists(_e, "date") && _e.date == _date_key) {
            return ph_shikaku_make(_e);
        }
    }
    var _seed = ph_seed_from_key(_date_key);
    return ph_shikaku_make(_list[_seed mod array_length(_list)]);
}

/// Build the runtime struct from a raw JSON entry.
function ph_shikaku_make(_raw) {
    var _size = variable_struct_exists(_raw, "size") ? _raw.size : 6;
    var _rects = _raw.rects;
    var _clues     = [];
    var _sol_rects = [];
    for (var _i = 0; _i < array_length(_rects); _i++) {
        var _d   = _rects[_i];
        var _val = _d.w * _d.h;
        array_push(_clues,     { r: _d.cr, c: _d.cc, val: _val });
        array_push(_sol_rects, { r: _d.r,  c: _d.c,  w: _d.w, h: _d.h, val: _val });
    }
    return {
        size:      _size,
        clues:     _clues,
        sol_rects: _sol_rects,
    };
}

/// Minimal hard-coded puzzle used when the data file is missing.
/// A verified-unique 9×9 board (generator output) so the fallback matches the
/// shipped 9×9 board size.
function ph_shikaku_fallback() {
    return ph_shikaku_make({ size: 9, rects: [
        { r:0, c:0, w:1, h:5, cr:3, cc:0 },
        { r:0, c:1, w:3, h:3, cr:1, cc:3 },
        { r:0, c:4, w:3, h:3, cr:2, cc:5 },
        { r:0, c:7, w:2, h:4, cr:3, cc:8 },
        { r:3, c:1, w:4, h:2, cr:4, cc:3 },
        { r:3, c:5, w:2, h:4, cr:4, cc:6 },
        { r:4, c:7, w:2, h:4, cr:4, cc:8 },
        { r:5, c:0, w:2, h:3, cr:7, cc:0 },
        { r:5, c:2, w:1, h:4, cr:5, cc:2 },
        { r:5, c:3, w:2, h:4, cr:6, cc:3 },
        { r:7, c:5, w:2, h:2, cr:8, cc:5 },
        { r:8, c:0, w:2, h:1, cr:8, cc:0 },
        { r:8, c:7, w:2, h:1, cr:8, cc:8 }
    ] });
}

/// True if cell (r,c) lies inside rectangle _rect (top-left r,c + w,h).
function ph_shikaku_rect_has_cell(_rect, _r, _c) {
    return (_r >= _rect.r && _r < _rect.r + _rect.h
         && _c >= _rect.c && _c < _rect.c + _rect.w);
}

/// Count how many clue cells fall inside a rectangle.
function ph_shikaku_clues_in_rect(_puzzle, _rect) {
    var _n = 0;
    for (var _i = 0; _i < array_length(_puzzle.clues); _i++) {
        if (ph_shikaku_rect_has_cell(_rect, _puzzle.clues[_i].r, _puzzle.clues[_i].c)) _n++;
    }
    return _n;
}

/// True if the player has drawn a rectangle exactly matching (r,c,w,h).
function ph_shikaku_player_has_rect(_player_rects, _r, _c, _w, _h) {
    for (var _i = 0; _i < array_length(_player_rects); _i++) {
        var _p = _player_rects[_i];
        if (_p.r == _r && _p.c == _c && _p.w == _w && _p.h == _h) return true;
    }
    return false;
}

/// Validate a single player rectangle against the puzzle. A rectangle is "good"
/// (correct) when it contains exactly one clue AND its area equals that clue.
/// Returns true/false. Used for live per-rectangle colouring feedback.
function ph_shikaku_rect_is_correct(_puzzle, _rect) {
    var _hit = -1;
    for (var _i = 0; _i < array_length(_puzzle.clues); _i++) {
        if (ph_shikaku_rect_has_cell(_rect, _puzzle.clues[_i].r, _puzzle.clues[_i].c)) {
            if (_hit != -1) return false;   // more than one clue inside
            _hit = _i;
        }
    }
    if (_hit == -1) return false;           // no clue inside
    return (_rect.w * _rect.h == _puzzle.clues[_hit].val);
}

/// True when the player's rectangles form a complete, valid Shikaku solution:
///   - every cell covered exactly once (no gaps, no overlaps),
///   - every rectangle contains exactly one clue,
///   - every rectangle's area equals that clue's value.
/// This checks the rules directly, so any valid partition wins (generation
/// guarantees the partition is unique anyway).
function ph_shikaku_check_solution(_puzzle, _player_rects) {
    var _n = _puzzle.size;
    var _owner = array_create(_n * _n, -1);

    for (var _i = 0; _i < array_length(_player_rects); _i++) {
        var _rect = _player_rects[_i];
        // bounds
        if (_rect.r < 0 || _rect.c < 0
         || _rect.r + _rect.h > _n || _rect.c + _rect.w > _n) return false;
        // exactly one clue, matching area
        if (!ph_shikaku_rect_is_correct(_puzzle, _rect)) return false;
        // no overlap
        for (var _dr = 0; _dr < _rect.h; _dr++) {
            for (var _dc = 0; _dc < _rect.w; _dc++) {
                var _idx = (_rect.r + _dr) * _n + (_rect.c + _dc);
                if (_owner[_idx] != -1) return false;
                _owner[_idx] = _i;
            }
        }
    }
    // full coverage
    for (var _k = 0; _k < _n * _n; _k++) {
        if (_owner[_k] == -1) return false;
    }
    return true;
}

// ── Save (serialise / restore in-progress state) ──────────────────────────────
//
// Player rectangles are stored as "r,c,w,h;r,c,w,h;..." and hinted clue indices
// as "i,j,k". Both keyed by date under save.shikaku_state[date] = {rects, hints}.

/// Serialise a player-rect array to "r,c,w,h;..." (empty string if none).
function ph_shikaku_rects_to_str(_player_rects) {
    var _s = "";
    for (var _i = 0; _i < array_length(_player_rects); _i++) {
        var _p = _player_rects[_i];
        if (_i > 0) _s += ";";
        _s += string(_p.r) + "," + string(_p.c) + "," + string(_p.w) + "," + string(_p.h);
    }
    return _s;
}

/// Parse "r,c,w,h;..." back into a player-rect array.
function ph_shikaku_str_to_rects(_s) {
    var _out = [];
    if (!is_string(_s) || _s == "") return _out;
    var _parts = string_split(_s, ";");
    for (var _i = 0; _i < array_length(_parts); _i++) {
        var _f = string_split(_parts[_i], ",");
        if (array_length(_f) == 4) {
            array_push(_out, {
                r: real(_f[0]), c: real(_f[1]), w: real(_f[2]), h: real(_f[3]),
            });
        }
    }
    return _out;
}

/// Persist the player's rectangles + hinted clue indices for resume.
function ph_shikaku_save_state(_save, _date_key, _player_rects, _hint_indices) {
    if (!variable_struct_exists(_save, "shikaku_state")) _save.shikaku_state = {};
    var _hints = "";
    for (var _i = 0; _i < array_length(_hint_indices); _i++) {
        if (_i > 0) _hints += ",";
        _hints += string(_hint_indices[_i]);
    }
    _save.shikaku_state[$ _date_key] = {
        rects: ph_shikaku_rects_to_str(_player_rects),
        hints: _hints,
    };
}

/// Read a saved {rects:[...], hints:[...]} for a date, or undefined if none.
function ph_shikaku_load_state(_save, _date_key) {
    if (!variable_struct_exists(_save, "shikaku_state")) return undefined;
    if (!variable_struct_exists(_save.shikaku_state, _date_key)) return undefined;
    var _st = _save.shikaku_state[$ _date_key];
    var _hints = [];
    if (variable_struct_exists(_st, "hints") && is_string(_st.hints) && _st.hints != "") {
        var _hp = string_split(_st.hints, ",");
        for (var _i = 0; _i < array_length(_hp); _i++) array_push(_hints, real(_hp[_i]));
    }
    return {
        rects: ph_shikaku_str_to_rects(variable_struct_exists(_st, "rects") ? _st.rects : ""),
        hints: _hints,
    };
}

// ── Completion tracking ───────────────────────────────────────────────────────
// Completion is tracked through the generic puzzles_solved map under the
// "SHIKAKU" key, so ph_solved_count_on() picks it up automatically.

/// True if Shikaku for the given date has been completed.
function ph_shikaku_is_done(_save, _date_key) {
    return ph_is_solved(_save, _date_key, "SHIKAKU");
}

/// Mark Shikaku complete for the given date. Hub reads this single flag.
function ph_shikaku_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "SHIKAKU");
}
