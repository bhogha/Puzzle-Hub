// ── Word Wave — Step ──────────────────────────────────────────────────────────

// Cell pop animation
for (var _i = 0; _i < array_length(cell_scales); _i++) {
    if (cell_flash[_i] > 0) {
        cell_flash[_i]--;
        cell_scales[_i] = lerp(cell_scales[_i], 1.10, 0.25);
    } else {
        cell_scales[_i] = lerp(cell_scales[_i], 1.0, 0.22);
    }
}

// Win slide-in
if (win_phase == 1) win_anim_t = min(win_anim_t + 0.04, 1.0);

// ── Confetti (identical model to Anygram) ─────────────────────────────────────
if (win_phase == 1) {
    var _conf_palette = [PH_COL_PINK, PH_COL_YELLOW, PH_COL_TEAL,
                         PH_COL_PURPLE, PH_COL_WHITE, PH_COL_ORANGE];
    var _conf_n_pal   = array_length(_conf_palette);

    if (confetti_burst_pending) {
        confetti_burst_pending = false;
        confetti_run_frames    = 0;
        var _burst_cx = PH_W / 2;
        var _burst_cy = 600;
        for (var _bi = 0; _bi < 60; _bi++) {
            var _ang   = random(2*pi);
            var _speed = 14 + random(14);
            array_push(confetti_pieces, {
                x: _burst_cx + cos(_ang)*4, y: _burst_cy + sin(_ang)*4,
                vx: cos(_ang)*_speed, vy: sin(_ang)*_speed,
                rot: random(360), vrot: -8 + random(16),
                size: 14 + irandom(10), col: _conf_palette[irandom(_conf_n_pal-1)],
                shape: irandom(2),
            });
        }
    }

    var _confetti_active = (confetti_run_frames < CONFETTI_DURATION_FRAMES);
    confetti_run_frames++;

    if (_confetti_active) {
        while (array_length(confetti_pieces) < CONFETTI_TARGET_FALL) {
            array_push(confetti_pieces, {
                x: random(PH_W), y: -40 - random(400),
                vx: -2 + random(4), vy: 3 + random(4),
                rot: random(360), vrot: -6 + random(12),
                size: 14 + irandom(10), col: _conf_palette[irandom(_conf_n_pal-1)],
                shape: irandom(2),
            });
        }
    }

    for (var _pi = array_length(confetti_pieces) - 1; _pi >= 0; _pi--) {
        var _p = confetti_pieces[_pi];
        _p.vy += 0.35; _p.vx *= 0.985;
        _p.x += _p.vx; _p.y += _p.vy; _p.rot += _p.vrot;
        if (_p.y > PH_H + 60) array_delete(confetti_pieces, _pi, 1);
        else confetti_pieces[_pi] = _p;
    }
}

// Toast timer
if (toast_timer > 0) toast_timer--;

// Shake decay
if (shake_t > 0) {
    shake_t--;
    var _pct = (SHAKE_DUR - shake_t) / SHAKE_DUR;
    shake_offset_x = sin(_pct * pi * 4) * 22 * (1 - _pct);
} else {
    shake_offset_x = 0;
}

// Coin counter pulse decay
if (coin_pulse_t < 1) coin_pulse_t = min(1, coin_pulse_t + 1/14);

// ── Flying coin update ────────────────────────────────────────────────────────
if (is_array(global.fly_tiles)) {
    for (var _fi = array_length(global.fly_tiles) - 1; _fi >= 0; _fi--) {
        var _ft = global.fly_tiles[_fi];
        _ft.t += (1/30);
        if (_ft.t >= 1) {
            coin_pulse_t     = 0;
            coin_overshoot_t = 0;
            array_delete(global.fly_tiles, _fi, 1);
        } else {
            global.fly_tiles[_fi] = _ft;
        }
    }
}
if (coin_overshoot_t < 1) coin_overshoot_t = min(1, coin_overshoot_t + 1/10);

// ── Win-screen input (precedence over everything else) ────────────────────────
if (win_phase == 1) {
    if (device_mouse_check_button_pressed(0, mb_left)) {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        if (win_btn_back_y > 0
            && ph_point_in_rect(_mx,_my, 80, win_btn_back_y, PH_W-80, win_btn_back_y+90)) {
            room_goto(rm_hub);
        }
    }
    exit;
}

// ── Bonus modal — eats taps while open ────────────────────────────────────────
if (bonus_modal_open) {
    if (device_mouse_check_button_pressed(0, mb_left)) {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        var _px1 = 80;  var _py1 = 360;
        var _px2 = PH_W-80; var _py2 = 1240;
        if (ph_point_in_circle(_mx, _my, _px2-70, _py1+70, 40)) {
            bonus_modal_open = false;
        } else if (_mx < _px1 || _mx > _px2 || _my < _py1 || _my > _py2) {
            bonus_modal_open = false;
        }
    }
    exit;
}

// ── Input ─────────────────────────────────────────────────────────────────────
if (current_time < global.input_locked_until) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Toolbar / back-button taps (only on a fresh press, before grid swipe logic).
if (device_mouse_check_button_pressed(0, mb_left)) {
    // Back arrow
    if (ph_point_in_rect(_mx,_my, 0,40,130,150)) {
        global.input_locked_until = current_time + 200;
        room_goto(rm_hub);
        exit;
    }
    // Bonus chest → modal (only if a bonus word has been found)
    if (ph_point_in_circle(_mx, _my, BONUS_ICON_X, BONUS_ICON_Y, BONUS_ICON_R)) {
        var _have_any = false;
        for (var _bi = 0; _bi < array_length(puzzle.bonus_found); _bi++) {
            if (puzzle.bonus_found[_bi]) { _have_any = true; break; }
        }
        if (_have_any) { bonus_modal_open = true; exit; }
    }
    // Hint pill
    if (ph_point_in_rect(_mx,_my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
        if (ph_wordwave_all_solved(puzzle)) {
            toast_text = "PUZZLE COMPLETE"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
        } else {
            // Find an unfound word whose first letter isn't already hinted.
            var _hint_wi = -1;
            for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
                if (puzzle.words[_wi].found) continue;
                var _start = puzzle.words[_wi].cells[0];
                var _key   = string(_start.r) + "," + string(_start.c);
                if (!variable_struct_exists(hint_cells, _key)) { _hint_wi = _wi; break; }
            }
            if (_hint_wi < 0) {
                toast_text = "NO HINTS AVAILABLE"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
            } else if (ph_spend_coins(global.save, PH_HINT_COST)) {
                var _s = puzzle.words[_hint_wi].cells[0];
                hint_cells[$ string(_s.r) + "," + string(_s.c)] = true;
                cell_flash[_s.r * GRID_N + _s.c] = 12;
                ph_save_write(global.save);
                toast_text = "HINT  •  -" + string(PH_HINT_COST) + " COINS";
                toast_col  = PH_COL_YELLOW; toast_timer = TOAST_DUR;
            } else {
                toast_text = "NOT ENOUGH COINS"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
            }
        }
        exit;
    }
}

// ── Grid swipe selection ──────────────────────────────────────────────────────
// Press: begin a selection if the press lands on a grid cell.
if (device_mouse_check_button_pressed(0, mb_left)) {
    var _cell = ww_cell_at(_mx, _my);
    if (!is_undefined(_cell)) {
        is_dragging = true;
        drag_start  = _cell;
        sel_path    = [_cell];
        sel_valid   = true;
    }
}

// Held: extend the straight-line selection to the cell under the cursor.
if (is_dragging && device_mouse_check_button(0, mb_left)) {
    var _cell = ww_cell_at(_mx, _my);
    if (!is_undefined(_cell)) {
        var _path = ww_build_path(drag_start, _cell);
        if (!is_undefined(_path)) {       // colinear → adopt; else keep last good path
            sel_path  = _path;
            sel_valid = true;
        }
    }
}

// Release: evaluate the selected path.
if (is_dragging && device_mouse_check_button_released(0, mb_left)) {
    is_dragging = false;
    if (array_length(sel_path) >= 2) {
        var _result = ph_ww_classify_path(puzzle, sel_path);
        switch (_result.kind) {
            case "main":
                puzzle.words[_result.index].found = true;
                ph_wordwave_mark_word(global.save, global.selected_date_key, _result.index);
                ph_save_write(global.save);
                ww_flash_path(puzzle.words[_result.index].cells);
                toast_text  = "FOUND  •  " + puzzle.words[_result.index].text;
                toast_col   = word_colors[_result.index];
                toast_timer = TOAST_DUR;
                ww_check_win();
                break;

            case "bonus":
                puzzle.bonus_found[_result.index] = true;
                ph_wordwave_mark_bonus(global.save, global.selected_date_key,
                                       puzzle.bonus_pool[_result.index]);
                ph_grant_coins(global.save, PH_BONUS_WORD_COINS);
                ph_save_write(global.save);
                ww_flash_path(sel_path);
                ww_spawn_coin_drop();
                toast_text  = "BONUS  +" + string(PH_BONUS_WORD_COINS) + " COINS  •  "
                              + puzzle.bonus_pool[_result.index];
                toast_col   = PH_COL_PURPLE;
                toast_timer = TOAST_DUR;
                break;

            case "dup":
                toast_text = "ALREADY FOUND"; toast_col = PH_COL_YELLOW; toast_timer = TOAST_DUR;
                break;

            default: // "bad"
                toast_text = "NOT A WORD"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
                ww_play_shake();
                break;
        }
    }
    sel_path  = [];
    sel_valid = false;
}
