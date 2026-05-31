// ── Sudoku puzzle helpers ─────────────────────────────────────────────────────
//
// Puzzle data is loaded from datafiles/puzzles_sudoku.json. Each entry is:
//
//   {
//     "date":       "YYYY-MM-DD"   (optional — exact-date authoring),
//     "difficulty": "easy"         (informational only),
//     "givens":     "<81 chars>",  // '0' = blank, '1'..'9' = pre-filled clue
//     "solution":   "<81 chars>"   // full solved grid, row-major
//   }
//
// ph_sudoku_make() normalizes a raw entry into the runtime struct:
//
//   {
//     givens:   [int x81],   // 0 = editable, 1..9 = locked clue
//     solution: [int x81],   // the answer
//     grid:     [int x81],   // current player state (0 = empty)
//     hinted:   [bool x81],  // cells revealed via the Hint button
//   }
//
// Indexing is row-major: index = row*9 + col  (row,col both 0..8).

function ph_load_sudokus() {
    if (variable_global_exists("ph_sudoku_cache")) {
        return global.ph_sudoku_cache;   // may be undefined sentinel (file missing)
    }
    var _path = working_directory + "puzzles_sudoku.json";
    if (!file_exists(_path)) {
        global.ph_sudoku_cache = undefined;
        return undefined;
    }
    var _buf = buffer_load(_path);
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    global.ph_sudoku_cache = json_parse(_str);
    return global.ph_sudoku_cache;
}

/// Convert an 81-char string into an array of 81 ints.
function ph_sudoku_str_to_arr(_s) {
    var _arr = array_create(81, 0);
    for (var _i = 0; _i < 81; _i++) {
        _arr[_i] = real(string_char_at(_s, _i + 1));
    }
    return _arr;
}

/// Pick the puzzle for a given date. Selection order mirrors Anygram:
///   1. Exact "date" match wins.
///   2. Otherwise deterministic seed fallback so every calendar day is stable.
function ph_sudoku_for_date(_date_key) {
    var _list = ph_load_sudokus();
    if (_list == undefined || array_length(_list) == 0) {
        // Hard-coded fallback puzzle so the room never crashes if the file is missing.
        return ph_sudoku_make({
            givens:   "530070000600195000098000060800060003400803001700020006060000280000419005000080079",
            solution: "534678912672195348198342567859761423426853791713924856961537284287419635345286179",
        });
    }
    // 1. Exact date match
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _entry = _list[_i];
        if (is_struct(_entry)
            && variable_struct_exists(_entry, "date")
            && _entry.date == _date_key) {
            return ph_sudoku_make(_entry);
        }
    }
    // 2. Seed fallback
    var _seed  = ph_seed_from_key(_date_key);
    var _index = _seed mod array_length(_list);
    return ph_sudoku_make(_list[_index]);
}

/// Build the runtime struct from a raw data entry.
function ph_sudoku_make(_raw) {
    var _givens   = ph_sudoku_str_to_arr(_raw.givens);
    var _solution = ph_sudoku_str_to_arr(_raw.solution);
    var _grid     = array_create(81, 0);
    for (var _i = 0; _i < 81; _i++) _grid[_i] = _givens[_i];
    return {
        givens:   _givens,
        solution: _solution,
        grid:     _grid,
        hinted:   array_create(81, false),
    };
}

/// True if the cell at index is a locked given (cannot be edited).
function ph_sudoku_is_given(_puzzle, _idx) {
    return _puzzle.givens[_idx] != 0;
}

/// True if the value the player placed at _idx conflicts with another non-empty
/// cell in the same row, column, or 3×3 box. Empty cells (0) never conflict.
function ph_sudoku_cell_conflicts(_puzzle, _idx) {
    var _v = _puzzle.grid[_idx];
    if (_v == 0) return false;
    var _r = _idx div 9;
    var _c = _idx mod 9;
    // Row + column
    for (var _k = 0; _k < 9; _k++) {
        var _ri = _r * 9 + _k;
        if (_ri != _idx && _puzzle.grid[_ri] == _v) return true;
        var _ci = _k * 9 + _c;
        if (_ci != _idx && _puzzle.grid[_ci] == _v) return true;
    }
    // 3×3 box
    var _br = (_r div 3) * 3;
    var _bc = (_c div 3) * 3;
    for (var _dr = 0; _dr < 3; _dr++) {
        for (var _dc = 0; _dc < 3; _dc++) {
            var _bi = (_br + _dr) * 9 + (_bc + _dc);
            if (_bi != _idx && _puzzle.grid[_bi] == _v) return true;
        }
    }
    return false;
}

/// True if a row (0..8) is completely & correctly filled (matches the solution).
function ph_sudoku_row_solved(_puzzle, _r) {
    for (var _c = 0; _c < 9; _c++) {
        var _i = _r * 9 + _c;
        if (_puzzle.grid[_i] == 0 || _puzzle.grid[_i] != _puzzle.solution[_i]) return false;
    }
    return true;
}

/// True if a column (0..8) is completely & correctly filled.
function ph_sudoku_col_solved(_puzzle, _c) {
    for (var _r = 0; _r < 9; _r++) {
        var _i = _r * 9 + _c;
        if (_puzzle.grid[_i] == 0 || _puzzle.grid[_i] != _puzzle.solution[_i]) return false;
    }
    return true;
}

/// True if a 3×3 box (box_r,box_c each 0..2) is completely & correctly filled.
function ph_sudoku_box_solved(_puzzle, _box_r, _box_c) {
    for (var _dr = 0; _dr < 3; _dr++) {
        for (var _dc = 0; _dc < 3; _dc++) {
            var _i = (_box_r * 3 + _dr) * 9 + (_box_c * 3 + _dc);
            if (_puzzle.grid[_i] == 0 || _puzzle.grid[_i] != _puzzle.solution[_i]) return false;
        }
    }
    return true;
}

/// True when every cell matches the solution — the whole puzzle is solved.
function ph_sudoku_all_solved(_puzzle) {
    for (var _i = 0; _i < 81; _i++) {
        if (_puzzle.grid[_i] != _puzzle.solution[_i]) return false;
    }
    return true;
}

/// Serialize the current player grid to an 81-char string (for save/resume).
function ph_sudoku_grid_to_str(_puzzle) {
    var _s = "";
    for (var _i = 0; _i < 81; _i++) _s += string(_puzzle.grid[_i]);
    return _s;
}
