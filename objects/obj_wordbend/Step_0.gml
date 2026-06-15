// ── Word Bend — Step ──────────────────────────────────────────────────────────

// Win screen (shared controller) — runs first and exits when complete.
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

// Cell pop animation.
for (var _i = 0; _i < NCELLS; _i++) {
    if (cell_flash[_i] > 0) {
        cell_flash[_i]--;
        cell_scale[_i] = lerp(cell_scale[_i], 1.12, 0.25);
    } else {
        cell_scale[_i] = lerp(cell_scale[_i], 1.0, 0.22);
    }
}

if (toast_timer > 0) toast_timer--;
if (coin_pulse_t < 1)     coin_pulse_t     = min(1, coin_pulse_t + 1/18);
if (coin_overshoot_t < 1) coin_overshoot_t = min(1, coin_overshoot_t + 1/10);

// Shake decay.
if (shake_t > 0) {
    shake_t--;
    var _pct = (SHAKE_DUR - shake_t) / SHAKE_DUR;
    shake_offset_x = sin(_pct * pi * 4) * 22 * (1 - _pct);
} else {
    shake_offset_x = 0;
}

ph_hint_tick(hint);
ph_timer_step(global.save, timer_key, timer_base_secs, session_start_ms);

if (current_time < global.input_locked_until) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Bonus-words modal — eats taps while open (close on X or tap outside the panel).
if (bonus_modal_open) {
    if (device_mouse_check_button_pressed(0, mb_left)) {
        var _px1 = 80, _py1 = 360, _px2 = PH_W - 80, _py2 = 1240;
        if (ph_point_in_circle(_mx, _my, _px2 - 70, _py1 + 70, 54)
            || !ph_point_in_rect(_mx, _my, _px1, _py1, _px2, _py2)) {
            bonus_modal_open = false;
        }
    }
    exit;
}

// Hint overlay (modal + placeholder video) eats taps while open.
var _hr = ph_hint_input(hint);
if (_hr != "none") {
    if (_hr == "paid") {
        toast_text = "HINT  •  -" + string(PH_HINT_COST) + " COINS";
        toast_col = PH_COL_YELLOW; toast_timer = TOAST_DUR;
    } else if (_hr == "freed") {
        toast_text = "FIRST LETTER REVEALED"; toast_col = ACCENT; toast_timer = TOAST_DUR;
    } else if (_hr == "poor") {
        toast_text = "NOT ENOUGH COINS"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
    }
    exit;
}

// ── Press ─────────────────────────────────────────────────────────────────────
if (device_mouse_check_button_pressed(0, mb_left)) {
    // Back arrow (top-left of HUD strip).
    if (ph_point_in_rect(_mx, _my, 0, 40 + global.safe_top_gui, 130, 150 + global.safe_top_gui)) {
        global.input_locked_until = current_time + 200;
        ph_timer_commit(global.save, timer_key, timer_base_secs, session_start_ms);
        wb_save();
        room_goto(rm_hub);
        exit;
    }

    // HINT pill (bottom-right). Bounds set by Draw.
    if (ph_point_in_rect(_mx, _my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
        if (!wb_can_hint()) {
            toast_text = "NO MORE HINTS"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
        } else {
            ph_hint_open(hint);
        }
        exit;
    }

    // BONUS pill (bottom-left). Bounds set by Draw — opens the bonus-words modal.
    if (ph_point_in_rect(_mx, _my, BONUS_PILL_L, BONUS_PILL_T, BONUS_PILL_R, BONUS_PILL_B)) {
        bonus_modal_open = true;
        exit;
    }

    // Start a trace on a board cell (unless it belongs to a found word).
    var _ci = wb_cell_at(_mx, _my);
    if (_ci != -1 && cell_owner[_ci] == -1) {
        dragging = true;
        sel_path = [_ci];
    }
    exit;
}

// ── Drag: extend / backtrack the trace one orthogonal step at a time ──────────
if (dragging && device_mouse_check_button(0, mb_left)) {
    var _fc = wb_cell_at(_mx, _my);
    if (_fc != -1) {
        var _len = array_length(sel_path);
        var _head = sel_path[_len - 1];
        if (_fc != _head) {
            var _in = wb_path_index(_fc);
            if (_in != -1) {
                // Re-touching an earlier cell → trim the tail back to it.
                for (var _k = _len - 1; _k > _in; _k--) array_pop(sel_path);
            } else if (wb_manhattan(_head, _fc) == 1 && cell_owner[_fc] == -1) {
                // Orthogonally adjacent, not yet used, not in a found word → extend.
                array_push(sel_path, _fc);
            }
        }
    }
    exit;
}

// ── Release: evaluate the traced path ─────────────────────────────────────────
if (dragging && device_mouse_check_button_released(0, mb_left)) {
    dragging = false;
    if (array_length(sel_path) >= 2) {
        var _idx = ph_wordbend_match(puzzle, sel_path, found, N);
        if (_idx >= 0) {
            found[_idx] = true;
            wb_rebuild_owner();
            var _cells_idx = [];
            var _cs = puzzle.words[_idx].cells;
            for (var _k = 0; _k < array_length(_cs); _k++) array_push(_cells_idx, _cs[_k].r * N + _cs[_k].c);
            wb_flash_cells(_cells_idx);
            toast_text  = "FOUND  •  " + puzzle.words[_idx].text;
            toast_col   = word_colors[_idx];
            toast_timer = TOAST_DUR;
            wb_check_win();
            if (win_phase == 0) wb_save();
        } else {
            // Not a hidden word — award a coin bonus if it's a real ≥4-letter
            // dictionary word we haven't already credited this puzzle.
            var _word = ph_wordbend_path_word(puzzle, sel_path, N);
            if (string_length(_word) >= 4
                && !ph_wordbend_is_hidden_word(puzzle, _word)
                && ph_wordbend_is_dict_word(_word)) {
                if (wb_bonus_has(_word)) {
                    // Already-credited bonus word — no re-award, gentle reminder.
                    toast_text = "ALREADY FOUND"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
                } else {
                    array_push(bonus_words, _word);
                    ph_grant_coins(global.save, PH_BONUS_WORD_COINS); ph_week_record_bonus_word(global.save, _word);
                    wb_flash_cells(sel_path);
                    coin_pulse_t = 0; coin_overshoot_t = 0;          // pulse the coin balance
                    toast_text  = "BONUS  +" + string(PH_BONUS_WORD_COINS) + " COINS  -  " + _word;
                    toast_col   = PH_COL_PURPLE; toast_timer = TOAST_DUR;
                    wb_save();
                }
            } else {
                toast_text = "NOT IN THE LIST"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
                shake_t = SHAKE_DUR;
            }
        }
    }
    sel_path = [];
    exit;
}
