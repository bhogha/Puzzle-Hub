function ph_save_load() {
    var _path = working_directory + PH_SAVE_FILE;
    if (file_exists(_path)) {
        var _buf = buffer_load(_path);
        var _str = buffer_read(_buf, buffer_string);
        buffer_delete(_buf);
        try {
            var _data = json_parse(_str);
            // Forward-compat: fields added in later versions
            if (!variable_struct_exists(_data, "xp")) _data.xp = 0;
            if (!variable_struct_exists(_data, "coins")) _data.coins = 0;
            if (!variable_struct_exists(_data, "puzzles_solved")) _data.puzzles_solved = {};
            if (!variable_struct_exists(_data, "gift_claimed_dates")) _data.gift_claimed_dates = [];
            if (!variable_struct_exists(_data, "anygram_bonus")) _data.anygram_bonus = {};
            if (!variable_struct_exists(_data, "streak")) _data.streak = 0;
            if (!variable_struct_exists(_data, "version")) _data.version = 1;
            ph_update_streak(_data);
            return _data;
        } catch (_e) {}
    }
    // Fresh save — new players begin with the starting XP/coins defined in the GDD.
    return {
        version:            1,
        xp:                 PH_INITIAL_XP,
        coins:              PH_INITIAL_COINS,
        puzzles_solved:     {},
        gift_claimed_dates: [],
        anygram_bonus:      {},
        streak:             0,
    };
}

function ph_save_write(_data) {
    var _str = json_stringify(_data);
    var _buf = buffer_create(1024, buffer_grow, 1);
    buffer_write(_buf, buffer_string, _str);
    buffer_save(_buf, working_directory + PH_SAVE_FILE);
    buffer_delete(_buf);
}

/// Wipe save progress: deletes the on-disk save file and returns a fresh save
/// struct (same defaults as a brand-new install). Callers should assign the
/// result to `global.save`. Used by the Profile-screen triple-tap easter egg.
function ph_save_reset() {
    var _path = working_directory + PH_SAVE_FILE;
    if (file_exists(_path)) file_delete(_path);
    return {
        version:            1,
        xp:                 PH_INITIAL_XP,
        coins:              PH_INITIAL_COINS,
        puzzles_solved:     {},
        gift_claimed_dates: [],
        anygram_bonus:      {},
        streak:             0,
    };
}

function ph_is_solved(_save, _date_key, _puzzle_name) {
    if (!variable_struct_exists(_save.puzzles_solved, _date_key)) return false;
    var _day = _save.puzzles_solved[$ _date_key];
    return variable_struct_exists(_day, _puzzle_name) && _day[$ _puzzle_name];
}

function ph_solved_count_on(_save, _date_key) {
    if (!variable_struct_exists(_save.puzzles_solved, _date_key)) return 0;
    var _day = _save.puzzles_solved[$ _date_key];
    var _count = 0;

    // Anygram counts as solved when:
    //   - the explicit ANYGRAM_DONE flag is set (new N-word format), OR
    //   - legacy ANYGRAM_M1 && ANYGRAM_M2 are both true (pre-refactor saves).
    if (ph_anygram_is_done(_save, _date_key)) {
        _count += 1;
    }

    // Other games (SUDOKU, WORD WAVE, MIX-UP etc.) — keyed by their own names.
    // Skip every Anygram bookkeeping key so we don't double-count.
    var _names = variable_struct_get_names(_day);
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _n = _names[_i];
        if (string_pos("ANYGRAM_", _n) == 1) continue;
        if (string_pos("WW_W", _n) == 1) continue;   // Word Wave per-word flags
        if (_day[$ _n]) _count += 1;
    }
    return _count;
}

/// True if Anygram for the given date has been completed (any save format).
function ph_anygram_is_done(_save, _date_key) {
    if (!variable_struct_exists(_save.puzzles_solved, _date_key)) return false;
    var _day = _save.puzzles_solved[$ _date_key];
    // New format
    if (variable_struct_exists(_day, "ANYGRAM_DONE") && _day.ANYGRAM_DONE) return true;
    // Legacy: both 2-word flags must be set
    var _has_m1 = variable_struct_exists(_day, "ANYGRAM_M1") && _day.ANYGRAM_M1;
    var _has_m2 = variable_struct_exists(_day, "ANYGRAM_M2") && _day.ANYGRAM_M2;
    return (_has_m1 && _has_m2);
}

/// Mark a single Anygram word (by index) as found. Idempotent.
function ph_anygram_mark_word(_save, _date_key, _word_index) {
    ph_mark_solved(_save, _date_key, "ANYGRAM_W" + string(_word_index));
}

/// True if a specific Anygram word has been marked found previously.
function ph_anygram_is_word_found(_save, _date_key, _word_index) {
    return ph_is_solved(_save, _date_key, "ANYGRAM_W" + string(_word_index));
}

/// Mark Anygram puzzle complete. Hub reads this single flag.
function ph_anygram_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "ANYGRAM_DONE");
}

function ph_update_streak(_save) {
    var _today_key = ph_today_key();
    var _dt = date_current_datetime();
    
    // Check if we solved at least one puzzle today
    var _solved_today = ph_solved_count_on(_save, _today_key) > 0;
    
    // Check consecutive days backwards
    var _streak = 0;
    var _current_dt = _dt;
    if (!_solved_today) {
        // If not solved today, check if yesterday was solved.
        // If yesterday was solved, the streak is still active (ends yesterday).
        // If yesterday was also not solved, the streak is broken (0).
        _current_dt = ph_date_add_days(_dt, -1);
    }
    
    while (true) {
        var _key = ph_date_key(_current_dt);
        if (ph_solved_count_on(_save, _key) > 0) {
            _streak++;
            _current_dt = ph_date_add_days(_current_dt, -1);
        } else {
            break;
        }
    }
    
    _save.streak = _streak;
}

function ph_mark_solved(_save, _date_key, _puzzle_name) {
    if (!variable_struct_exists(_save.puzzles_solved, _date_key)) {
        _save.puzzles_solved[$ _date_key] = {};
    }
    _save.puzzles_solved[$ _date_key][$ _puzzle_name] = true;
}

function ph_has_gift_been_claimed(_save, _date_key) {
    var _arr = _save.gift_claimed_dates;
    for (var _i = 0; _i < array_length(_arr); _i++) {
        if (_arr[_i] == _date_key) return true;
    }
    return false;
}

function ph_claim_gift(_save, _date_key) {
    array_push(_save.gift_claimed_dates, _date_key);
}

// ── Anygram bonus-word tracking ──────────────────────────────────────────────
function ph_anygram_is_bonus_found(_save, _date_key, _word) {
    if (!variable_struct_exists(_save, "anygram_bonus")) return false;
    if (!variable_struct_exists(_save.anygram_bonus, _date_key)) return false;
    return variable_struct_exists(_save.anygram_bonus[$ _date_key], string_lower(_word));
}

function ph_anygram_mark_bonus(_save, _date_key, _word) {
    if (!variable_struct_exists(_save, "anygram_bonus")) {
        _save.anygram_bonus = {};
    }
    if (!variable_struct_exists(_save.anygram_bonus, _date_key)) {
        _save.anygram_bonus[$ _date_key] = {};
    }
    _save.anygram_bonus[$ _date_key][$ string_lower(_word)] = true;
}

// ── Sudoku tracking ───────────────────────────────────────────────────────────
// Completion is tracked through the generic puzzles_solved map under the
// "SUDOKU" key, so ph_solved_count_on() picks it up automatically alongside
// the other games. Finish time and mid-puzzle grid live in dedicated save keys.

/// True if Sudoku for the given date has been completed.
function ph_sudoku_is_done(_save, _date_key) {
    return ph_is_solved(_save, _date_key, "SUDOKU");
}

/// Mark Sudoku complete for the given date. Hub reads this single flag.
function ph_sudoku_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "SUDOKU");
}

/// Persist the player's in-progress grid (81-char string) so leaving and
/// returning mid-puzzle restores their entries.
function ph_sudoku_save_grid(_save, _date_key, _grid_str) {
    if (!variable_struct_exists(_save, "sudoku_grid")) {
        _save.sudoku_grid = {};
    }
    _save.sudoku_grid[$ _date_key] = _grid_str;
}

/// Read a previously-saved grid string, or undefined if none stored.
function ph_sudoku_load_grid(_save, _date_key) {
    if (!variable_struct_exists(_save, "sudoku_grid")) return undefined;
    if (!variable_struct_exists(_save.sudoku_grid, _date_key)) return undefined;
    return _save.sudoku_grid[$ _date_key];
}

// ── Word Wave tracking ────────────────────────────────────────────────────────
// Completion is tracked through the generic puzzles_solved map under the
// "WORDWAVE" key, so ph_solved_count_on() picks it up automatically (it only
// skips "ANYGRAM_"-prefixed bookkeeping keys). Per-word found flags use the
// "WW_W<index>" keys, also skipped from the count because they live under the
// same day struct only after WORDWAVE is set — but to be safe we still namespace
// them so they never collide with another puzzle's single-flag entry.

/// True if Word Wave for the given date has been completed.
function ph_wordwave_is_done(_save, _date_key) {
    return ph_is_solved(_save, _date_key, "WORDWAVE");
}

/// Mark Word Wave complete for the given date. Hub reads this single flag.
function ph_wordwave_mark_done(_save, _date_key) {
    ph_mark_solved(_save, _date_key, "WORDWAVE");
}

/// Mark a single Word Wave word (by index) as found. Idempotent.
function ph_wordwave_mark_word(_save, _date_key, _word_index) {
    ph_mark_solved(_save, _date_key, "WW_W" + string(_word_index));
}

/// True if a specific Word Wave word has been marked found previously.
function ph_wordwave_is_word_found(_save, _date_key, _word_index) {
    return ph_is_solved(_save, _date_key, "WW_W" + string(_word_index));
}

/// True if a Word Wave bonus word has been discovered before (per date).
function ph_wordwave_is_bonus_found(_save, _date_key, _word) {
    if (!variable_struct_exists(_save, "wordwave_bonus")) return false;
    if (!variable_struct_exists(_save.wordwave_bonus, _date_key)) return false;
    return variable_struct_exists(_save.wordwave_bonus[$ _date_key], string_lower(_word));
}

/// Record a Word Wave bonus word as discovered (per date).
function ph_wordwave_mark_bonus(_save, _date_key, _word) {
    if (!variable_struct_exists(_save, "wordwave_bonus")) _save.wordwave_bonus = {};
    if (!variable_struct_exists(_save.wordwave_bonus, _date_key)) _save.wordwave_bonus[$ _date_key] = {};
    _save.wordwave_bonus[$ _date_key][$ string_lower(_word)] = true;
}
