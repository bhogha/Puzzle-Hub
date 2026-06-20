// ── Win screen (shared controller) ────────────────────────────────────────────
// When the puzzle is complete the shared win controller owns input + animation.
// It runs first and exits, so the legacy win_phase==1 blocks below are no longer
// reached (kept temporarily; safe to delete once the new flow is verified).
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

// ── Tile animation ────────────────────────────────────────────────────────────
for (var _i = 0; _i < array_length(tile_scales); _i++) {
    if (tile_flash[_i] > 0) {
        tile_flash[_i]--;
        tile_scales[_i] = lerp(tile_scales[_i], 1.10, 0.25);   // GDD §8: peak 1.1
    } else {
        tile_scales[_i] = lerp(tile_scales[_i], 1.0, 0.22);
    }
}

// Win animation
if (win_phase == 1) {
    win_anim_t = min(win_anim_t + 0.04, 1.0);
}

// ── Confetti ──────────────────────────────────────────────────────────────────
// Active for a fixed window (CONFETTI_DURATION_FRAMES) once the win overlay
// appears. Spawning is gated on that window; in-flight pieces still get ticked
// after the window closes so the fall doesn't pop — they just naturally drift
// off the bottom and the pool drains to zero.
if (win_phase == 1) {
    // Palette pulled from the project's accent set so the celebration matches
    // the rest of the UI rather than introducing new colours.
    var _conf_palette = [PH_COL_PINK, PH_COL_YELLOW, PH_COL_TEAL,
                         PH_COL_PURPLE, PH_COL_WHITE, PH_COL_ORANGE];
    var _conf_n_pal   = array_length(_conf_palette);

    // 1) One-shot radial burst — fired by Create or ag_check_win. The duration
    //    counter resets here so the 3s window is measured from the burst, not
    //    from whenever this object happened to be created.
    if (confetti_burst_pending) {
        confetti_burst_pending = false;
        confetti_run_frames    = 0;
        var _burst_cx = PH_W / 2;
        var _burst_cy = 600;             // roughly the centre of the card
        for (var _bi = 0; _bi < 60; _bi++) {
            var _ang   = random(2*pi);
            var _speed = 14 + random(14);
            array_push(confetti_pieces, {
                x:     _burst_cx + cos(_ang) * 4,
                y:     _burst_cy + sin(_ang) * 4,
                vx:    cos(_ang) * _speed,
                vy:    sin(_ang) * _speed,
                rot:   random(360),
                vrot:  -8 + random(16),
                size:  14 + irandom(10),
                col:   _conf_palette[irandom(_conf_n_pal-1)],
                shape: irandom(2),
            });
        }
    }

    // Bump the run timer. Spawning the falling layer only happens while the
    // window is open; ticking pieces always runs so the tail can dissipate.
    var _confetti_active = (confetti_run_frames < CONFETTI_DURATION_FRAMES);
    confetti_run_frames++;

    // 2) Steady-state fall — keep the pool full while the window is open.
    if (_confetti_active) {
        while (array_length(confetti_pieces) < CONFETTI_TARGET_FALL) {
            array_push(confetti_pieces, {
                x:     random(PH_W),
                y:     -40 - random(400),       // staggered above the screen
                vx:    -2 + random(4),
                vy:    3 + random(4),
                rot:   random(360),
                vrot:  -6 + random(12),
                size:  14 + irandom(10),
                col:   _conf_palette[irandom(_conf_n_pal-1)],
                shape: irandom(2),
            });
        }
    }

    // 3) Integrate motion: light gravity + air drag on the burst pieces.
    for (var _pi = array_length(confetti_pieces) - 1; _pi >= 0; _pi--) {
        var _p = confetti_pieces[_pi];
        _p.vy += 0.35;                       // gravity
        _p.vx *= 0.985;                      // horizontal drag (slows burst spread)
        _p.x  += _p.vx;
        _p.y  += _p.vy;
        _p.rot += _p.vrot;
        if (_p.y > PH_H + 60) {
            array_delete(confetti_pieces, _pi, 1);
        } else {
            confetti_pieces[_pi] = _p;
        }
    }
}

// Toast timer
if (toast_timer > 0) toast_timer--;

// Shake decay (after a clamp+sin offset is computed in Draw, the timer just counts down here)
if (shake_t > 0) {
    shake_t--;
    var _pct = (SHAKE_DUR - shake_t) / SHAKE_DUR;   // 0..1
    shake_offset_x = sin(_pct * pi * 4) * 22 * (1 - _pct);
} else {
    shake_offset_x = 0;
}

// Coin counter pulse decay
if (coin_pulse_t < 1) coin_pulse_t = min(1, coin_pulse_t + 1/14);

// ── Flying tile animation update ──────────────────────────────────────────────
// Per GDD §8: letter tiles 350ms (≈21 frames @60fps → t += ~0.0476),
// coin arc 500ms (≈30 frames → t += ~0.0333).
if (is_array(global.fly_tiles)) {
    for (var _fi = array_length(global.fly_tiles) - 1; _fi >= 0; _fi--) {
        var _ft = global.fly_tiles[_fi];
        _ft.t += (_ft.kind == "coin") ? (1/30) : (1/21);
        if (_ft.t >= 1) {
            // Arrival callback per kind
            if (_ft.kind == "main" && _ft.cell_idx >= 0) {
                // Reveal the cell at this position and flash it.
                var _c = puzzle.cells[_ft.cell_idx];
                _c.filled = true;
                puzzle.cells[_ft.cell_idx] = _c;
                tile_flash[_ft.cell_idx] = 12;          // GDD §8: 12-frame reveal
                if (_ft.is_last) {
                    ag_check_win();
                }
            } else if (_ft.kind == "bonus") {
                // Bonus icon pulse on each letter arrival; on last, drop the coin.
                if (_ft.is_last) ag_spawn_coin_drop();
            } else if (_ft.kind == "coin") {
                // Coin reaches the counter — pulse the label + overshoot bounce.
                coin_pulse_t     = 0;
                coin_overshoot_t = 0;
            }
            array_delete(global.fly_tiles, _fi, 1);
        } else {
            global.fly_tiles[_fi] = _ft;
        }
    }
}

// Coin overshoot bounce decay (post-arrival, GDD §8)
if (coin_overshoot_t < 1) coin_overshoot_t = min(1, coin_overshoot_t + 1/10);

// Advance the shared hint-flow timers (modal slide / "-100" / video).
ph_hint_tick(hint);

// Advance the onboarding finger tip (no-op once solved / already seen).
ph_coach_tick(coach);

// Persist the play timer (≤ once/sec) so leaving or an app kill resumes here.
if (win_phase == 0) ph_timer_step(global.save, timer_key, timer_base_secs, session_start_ms);

// ── Hint overlay input (modal + placeholder video) — eats taps while open. ────
var _hr = ph_hint_input(hint);
if (_hr != "none") {
    if (_hr == "paid") {
        toast_text  = "HINT USED  -" + string(PH_HINT_COST) + " coins";
        toast_col   = PH_COL_YELLOW; toast_timer = TOAST_DUR;
    } else if (_hr == "freed") {
        toast_text  = "HINT REVEALED";
        toast_col   = PH_COL_TEAL;   toast_timer = TOAST_DUR;
    } else if (_hr == "poor") {
        toast_text  = "NOT ENOUGH COINS";
        toast_col   = PH_COL_PINK;   toast_timer = TOAST_DUR;
    }
    exit;
}

// ── Win-screen input (must run BEFORE the bonus-modal block so it takes precedence) ──
if (win_phase == 1) {
    if (device_mouse_check_button_pressed(0, mb_left)) {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        if (win_btn_back_y > 0
            && ph_point_in_rect(_mx,_my, 80, win_btn_back_y, PH_W-80, win_btn_back_y+90)) {
            // A pending level-up shows the reward screen (rm_win) before the hub.
            room_goto(ph_levelup_pending() ? rm_win : rm_hub);
        }
    }
    exit;
}

// ── Bonus-modal input — eats taps while open ──────────────────────────────────
if (bonus_modal_open) {
    if (device_mouse_check_button_pressed(0, mb_left)) {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        // Close on X button (top-right of panel) or tap outside the panel.
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

// Back button + Hint button
if (device_mouse_check_button_pressed(0, mb_left)) {
    // Back arrow hit rect — aligned to the HUD strip centred at y=95 + safe-area inset.
    if (ph_point_in_rect(_mx,_my, 0, 40 + global.safe_top_gui, 130, 150 + global.safe_top_gui)) {
        global.input_locked_until = current_time + 200;
        ph_timer_commit(global.save, timer_key, timer_base_secs, session_start_ms);
        ph_save_write(global.save);
        room_goto(rm_hub);
        exit;
    }
    // BONUS pill (toolbar left) — opens the bonus words modal if any are found.
    if (ph_point_in_rect(_mx, _my, BONUS_PILL_L, BONUS_PILL_T, BONUS_PILL_R, BONUS_PILL_B)) {
        var _have_any_bonus = false;
        for (var _bi = 0; _bi < array_length(puzzle.bonus_found); _bi++) {
            if (puzzle.bonus_found[_bi]) { _have_any_bonus = true; break; }
        }
        if (_have_any_bonus) {
            bonus_modal_open = true;
            exit;
        }
    }
    // Hint button — wide pill in the bottom-right; bounds come from Draw_64.gml.
    // Now opens the hint modal (pay coins OR watch a placeholder rewarded video)
    // instead of spending coins immediately. Guard the no-op cases up front so
    // the modal only opens when a hint can actually be granted.
    if (ph_point_in_rect(_mx,_my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
        if (ph_anygram_all_solved(puzzle)) {
            toast_text  = "PUZZLE COMPLETE";
            toast_col   = PH_COL_GRAY;
            toast_timer = TOAST_DUR;
        } else if (!ag_can_use_hint()) {
            toast_text  = "NO HINTS AVAILABLE";
            toast_col   = PH_COL_GRAY;
            toast_timer = TOAST_DUR;
        } else {
            hint.subtitle = ag_hint_subtitle();   // name the exact letter (1st/2nd/3rd…)
            ph_hint_open(hint);
            exit;
        }
    }
}

// ── Wheel drag ────────────────────────────────────────────────────────────────
// Press
if (device_mouse_check_button_pressed(0, mb_left)) {
    // Check shuffle button click first (centered at WHEEL_CX, WHEEL_CY)
    if (ph_point_in_circle(_mx, _my, WHEEL_CX, WHEEL_CY, 60)) {
        var _len = array_length(puzzle.letters);
        for (var _i = _len - 1; _i > 0; _i--) {
            var _j = irandom(_i);
            var _temp = puzzle.letters[_i];
            puzzle.letters[_i] = puzzle.letters[_j];
            puzzle.letters[_j] = _temp;
        }
        exit;
    }

    var _hit = ag_hit_letter(_mx, _my);
    if (_hit >= 0) {
        is_dragging_wheel = true;
        trail = [_hit];
        drag_letter_idx = _hit;
        ag_rebuild_trail_word();
    }
}

// Held
if (is_dragging_wheel && device_mouse_check_button(0, mb_left)) {
    var _hit = ag_hit_letter(_mx, _my);
    if (_hit >= 0 && _hit != drag_letter_idx) {
        // Allow backtrack: if second-to-last == hit, pop last
        if (array_length(trail) >= 2 && trail[array_length(trail)-2] == _hit) {
            array_pop(trail);
            ag_rebuild_trail_word();
        } else if (!ag_trail_contains(_hit)) {
            array_push(trail, _hit);
            ag_rebuild_trail_word();
        }
        drag_letter_idx = trail[array_length(trail)-1];
    }
}

// Release — evaluate word
if (is_dragging_wheel && device_mouse_check_button_released(0, mb_left)) {
    is_dragging_wheel = false;
    if (array_length(trail) >= 2) {
        var _word    = trail_word;
        var _result  = ph_classify_word(puzzle, _word);

        switch (_result.kind) {
            case "main":
                puzzle.words[_result.index].found = true;
                ph_anygram_mark_word(global.save, global.selected_date_key, _result.index);
                ph_save_write(global.save);
                // First hidden word found → retire the onboarding finger tip.
                if (ph_coach_active(coach)) { ph_coach_stop(coach); ph_tip_mark_seen("ANYGRAM"); }
                ag_flash_word_by_index(_result.index);
                // Cells will be revealed by the fly-tile arrival callbacks; mark
                // the toast immediately so the player gets instant feedback.
                ag_spawn_fly_main(_result.index);
                toast_text  = "FOUND - " + string_upper(puzzle.words[_result.index].text);
                toast_col   = PH_COL_TEAL;
                toast_timer = TOAST_DUR;
                break;

            case "bonus":
                puzzle.bonus_found[_result.index] = true;
                ph_anygram_mark_bonus(global.save, global.selected_date_key, puzzle.bonus[_result.index]);
                // Bonus words pay coins only — no XP (single 100 XP awarded on full puzzle completion).
                ph_grant_coins(global.save, PH_BONUS_WORD_COINS); ph_week_record_bonus_word(global.save, _word);
                ph_save_write(global.save);
                ag_spawn_fly_bonus(string_upper(_word));
                toast_text  = "BONUS +" + string(PH_BONUS_WORD_COINS) + " COINS - " + string_upper(_word);
                toast_col   = PH_COL_PURPLE;
                toast_timer = TOAST_DUR;
                break;

            case "dup":
                toast_text  = "ALREADY FOUND";
                toast_col   = PH_COL_YELLOW;
                toast_timer = TOAST_DUR;
                break;

            case "neutral":
                toast_text  = "NOT A KEY WORD";
                toast_col   = PH_COL_GRAY;
                toast_timer = TOAST_DUR;
                break;

            default: // "bad"
                toast_text  = "NOT A VALID WORD";
                toast_col   = PH_COL_PINK;
                toast_timer = TOAST_DUR;
                ag_play_shake();
                break;
        }
    }
    trail = [];
    trail_word = "";
}
