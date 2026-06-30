// ── Date roll-over (hub left open past midnight) ──────────────────────────────
if (ph_today_key() != today_key) hub_refresh_dates();

// ── Tile press/pop feedback timers (advance regardless of input lock) ─────────
if (card_press_idx != -1 && card_press_t < 1) card_press_t = min(1, card_press_t + 1/CARD_PRESS_FR);
if (card_pop_idx != -1) {
    card_pop_t += 1/CARD_POP_FR;
    if (card_pop_t >= 1) { card_pop_idx = -1; card_pop_t = 0; }
}

// ── Coin-flow reward animation ────────────────────────────────────────────────
// Advances independently of the input lock so it still plays during the brief
// post-room-transition lock. Coins ride an eased arc into the pill; once the
// first ones land the "+N" label rises and fades, then the whole thing ends.
if (coinflow_active) {
    coinflow_t++;
    var _all_done = true;
    for (var _ci = 0; _ci < array_length(coinflow_coins); _ci++) {
        var _c = coinflow_coins[_ci];
        if (coinflow_t >= _c.delay && _c.t < 1) {
            _c.t = min(1, _c.t + 1/_c.dur);
            if (_c.t >= 1 && !_c.arrived) {
                _c.arrived  = true;
                coinflow_pop = 1;          // pulse the pill coin on each landing
            }
            coinflow_coins[_ci] = _c;
        }
        if (_c.t < 1) _all_done = false;
    }
    // Start the "+N" label once coins begin streaming in.
    if (coinflow_label_t < 0 && coinflow_t > 16) coinflow_label_t = 0;
    if (coinflow_label_t >= 0 && coinflow_label_t < 1)
        coinflow_label_t = min(1, coinflow_label_t + 0.012);
    if (coinflow_pop > 0) coinflow_pop = max(0, coinflow_pop - 0.08);
    // Done when every coin has landed and the label has finished.
    if (_all_done && coinflow_label_t >= 1) coinflow_active = false;
}

// ── Daily Spin modal ──────────────────────────────────────────────────────────
// Animates regardless of the input lock. While open it captures ALL input
// (must-spin, no close), so the rest of the hub is suspended until claimed.
ph_spin_tick(spin);
if (ph_spin_is_open(spin)) {
    if (current_time >= global.input_locked_until) {
        var _smx = device_mouse_x_to_gui(0);
        var _smy = device_mouse_y_to_gui(0);
        var _sr  = ph_spin_input(spin, _smx, _smy);
        if (_sr == "claimed") hub_start_coinflow(spin.grant_amount);
    }
    exit;
}

// ── Daily-progress FTUE coach ─────────────────────────────────────────────────
// Animates regardless of the input lock. While open it captures ALL input (tap
// anywhere advances / closes, gated to ~1 s into each step), so the rest of the
// hub is suspended. On the final tap it persists the seen-flag and fires the
// notification-permission request (retargeted here from first-solve).
ph_dailytut_tick(dailytut);
if (ph_dailytut_is_open(dailytut)) {
    if (current_time >= global.input_locked_until) {
        var _dr = ph_dailytut_input(dailytut);
        if (_dr == "done") {
            global.save.daily_progress_tut_done = true;
            ph_save_write(global.save);
            // Tutorial finished → ask for notification permission now (iOS-guarded,
            // once-only inside). Replaces the old first-solve prompt.
            ph_notify_request_after_first_solve();
        }
    }
    exit;
}

// ── Input lock ────────────────────────────────────────────────────────────────
if (current_time < global.input_locked_until) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// ── Calendar animation ────────────────────────────────────────────────────────
var _cal_target = cal_open ? 1 : 0;
cal_anim_t = lerp(cal_anim_t, _cal_target, 0.18);

// ── Compute body top (depends on calendar state) ──────────────────────────────
// Strip slot shrinks as the calendar opens (the 7-day strip is faded out
// anyway). Matches the formula in Draw_64 §0 so tap targets line up with what
// is being rendered.
var _cal_h        = lerp(LAYOUT.calbar_h, LAYOUT.calexpand_h, cal_anim_t);
var _eff_strip_h  = LAYOUT.strip_h * lerp(1.0, 0.50, cal_anim_t);
// _post_cal must match Draw_64 §0 exactly so card tap targets line up with what
// is rendered (closed: below the strip slot; open: just below the month grid).
var _grid_rows    = ceil(array_length(month_days) / 7);
var _grid_bottom  = LAYOUT.calbar_y + LAYOUT.calbar_h + LAYOUT.cal_grid_off + _grid_rows * LAYOUT.cal_cell_h;
// Open layout reserves room for the month-nav slider bar below the grid.
var _post_cal_open = _grid_bottom + LAYOUT.cal_monthnav_gap + LAYOUT.cal_monthnav_h + 28;
var _post_cal     = lerp(LAYOUT.calbar_y + _cal_h + _eff_strip_h, _post_cal_open, cal_anim_t);
var _body_top     = _post_cal + LAYOUT.section_h;
var _body_bot     = PH_H - LAYOUT.nav_h;
var _view_h       = _body_bot - _body_top;
var _total_h      = array_length(cards) * (LAYOUT.card_h + LAYOUT.card_gap) - LAYOUT.card_gap;
scroll_max        = max(0, _total_h - _view_h);

// ── First-run soft onboarding (auto-scroll + finger; non-blocking) ────────────
// The auto-scroll sweep itself (last game → first game) is driven at the very END
// of Step so it overrides manual scroll while it plays. Here we only count the
// settle delay and aim the soft finger at the top tile's PLAY pill once the sweep
// has finished. Nothing captures input — the player can scroll/tap/explore freely
// (the finger tracks the top tile and hides if it scrolls off-screen).
if (intro_active && intro_t >= 1) {
    intro_settle_t++;
    if (intro_settle_t >= INTRO_FINGER_DELAY_FR) {
        var _card0_y1 = _body_top - scroll_y;          // top tile (i = 0)
        var _card0_y2 = _card0_y1 + LAYOUT.card_h;
        // Only point while the top tile is actually visible in the list band.
        if (_card0_y2 > _body_top + 30 && _card0_y1 < _body_bot - 30) {
            var _csx        = (PH_W - 2*LAYOUT.card_pad_x) / 1430;
            var _pill_right = LAYOUT.card_pad_x + 1380 * _csx;
            var _pill_cx    = _pill_right - (350 * _csx) * 0.5;
            ph_finger_point_at(finger, _pill_cx, (_card0_y1 + _card0_y2) * 0.5 + 6, 0);
        } else {
            ph_finger_hide(finger);
        }
    }
}
ph_finger_tick(finger);

// ── Press start ───────────────────────────────────────────────────────────────
if (device_mouse_check_button_pressed(0, mb_left)) {
    drag_start_x = _mx;
    drag_start_y = _my;
    drag_dist    = 0;
    is_dragging  = false;
    mx_prev = _mx;
    my_prev = _my;
    scroll_vel = 0;

    // Tile press feedback — which (unlocked, playable) card is under the finger.
    card_press_idx = -1; card_press_t = 0;
    if ((!intro_active || intro_t >= 1) && ph_point_in_rect(_mx,_my, 0,_body_top, PH_W,_body_bot)) {
        for (var _pi = 0; _pi < array_length(cards); _pi++) {
            var _pcy1 = _body_top + _pi*(LAYOUT.card_h + LAYOUT.card_gap) - scroll_y;
            if (_my >= _pcy1 && _my < _pcy1 + LAYOUT.card_h
                && !cards[_pi].locked && cards[_pi].room != "") { card_press_idx = _pi; break; }
        }
    }
}

// ── Held: drag to scroll ──────────────────────────────────────────────────────
if (device_mouse_check_button(0, mb_left)) {
    var _dy = _my - my_prev;
    drag_dist += abs(_mx - mx_prev) + abs(_my - my_prev);
    if (drag_dist > 20) is_dragging = true;
    if (is_dragging) {
        scroll_y -= _dy;
        scroll_vel = _dy;   // fling continues drag direction (scroll_y -= scroll_vel)
        card_press_idx = -1; // a scroll cancels the press feedback
    }
    mx_prev = _mx;
    my_prev = _my;
}

// ── Release: fling + tap ──────────────────────────────────────────────────────
if (device_mouse_check_button_released(0, mb_left)) {
    // The press ends here → spring-pop the held card back (whether or not the tap
    // lands on it; releasing off-card still springs it back).
    if (card_press_idx != -1) { card_pop_idx = card_press_idx; card_pop_t = 0; card_press_idx = -1; }
    if (!is_dragging) {
        // ── TAP ──────────────────────────────────────────────────────────────
        var _tap_x = drag_start_x;
        var _tap_y = drag_start_y;
        var _third = PH_W / 3;
        var _nav_top = PH_H - LAYOUT.nav_h;

        // Bottom nav takes priority — covered tab regions never fall through to cards.
        // Tab order: Shop | Games (current) | Profile
        if (_tap_y > _nav_top) {
            if (_tap_x < _third) {
                global.input_locked_until = current_time + 200;
                room_goto(rm_shop);
            } else if (_tap_x >= _third*2) {
                global.input_locked_until = current_time + 200;
                room_goto(rm_profile);
            }
            // middle third = Games (current room) — no-op
            exit;
        }

        // Calendar toggle — full teal bar
        if (ph_point_in_rect(_tap_x,_tap_y,
                             0, LAYOUT.calbar_y,
                             PH_W, LAYOUT.calbar_y + LAYOUT.calbar_h)) {
            cal_open = !cal_open;
            hub_view_to_selected();   // re-anchor the viewed month to the selected day
            exit;
        }

        // Month grid + month-nav tap (when expanded) — checked BEFORE strip so taps
        // inside the calendar window don't fall through to the strip below.
        if (cal_open) {
            // Month-nav slider bar (below the grid): left half = prev month, right
            // half = next month. Stays open so the player can keep browsing.
            var _mn_top = _grid_bottom + LAYOUT.cal_monthnav_gap;
            var _mn_bot = _mn_top + LAYOUT.cal_monthnav_h;
            if (ph_point_in_rect(_tap_x,_tap_y, 0,_mn_top, PH_W,_mn_bot)) {
                if (_tap_x < PH_W/2) hub_month_step(-1);
                else                 hub_month_step(1);   // self-caps at the current month
                exit;
            }

            var _grid_top  = LAYOUT.calbar_y + LAYOUT.calbar_h + LAYOUT.cal_grid_off;
            var _cell_w    = PH_W / 7;
            var _cell_h    = LAYOUT.cal_cell_h;
            var _matched   = false;   // tracks a *real* cell hit only
            var _stop      = false;   // tracks whether to break out of both loops
            for (var _ri = 0; _ri < month_grid_rows && !_stop; _ri++) {
                for (var _ci = 0; _ci < 7; _ci++) {
                    var _mi = _ri*7 + _ci;
                    // Walked past the end of the month grid → stop iterating but
                    // DO NOT mark _matched (the tap may belong to strip/card below).
                    if (_mi >= array_length(month_days)) { _stop = true; break; }
                    if (month_days[_mi] == undefined) continue;
                    var _cx1 = _ci * _cell_w;
                    var _cy1 = _grid_top + _ri * _cell_h;
                    if (ph_point_in_rect(_tap_x,_tap_y, _cx1,_cy1, _cx1+_cell_w,_cy1+_cell_h)) {
                        // Future days are not playable yet — consume the tap so it
                        // doesn't fall through, but don't change the selection.
                        if (ph_date_compare_keys(month_days[_mi].key, today_key) <= 0) {
                            global.selected_date_key = month_days[_mi].key;
                            hub_center_strip_on(month_days[_mi].dt);   // re-centre strip on selected day
                            cal_open = false;
                        }
                        _matched = true;
                        _stop    = true;
                        break;
                    }
                }
            }
            if (_matched) exit;
        }

        // Strip day tap — only active when calendar is closed. When the calendar
        // is open the strip is faded out (see Draw_64.gml §4), so taps in this
        // region should fall through.
        if (!cal_open) {
            var _strip_top = LAYOUT.calbar_y + _cal_h;
            var _sw        = PH_W / 7;
            if (ph_point_in_rect(_tap_x,_tap_y, 0,_strip_top, PH_W,_strip_top+_eff_strip_h)) {
                var _col = floor(_tap_x / _sw);
                _col = clamp(_col, 0, 6);
                // Future days are not playable yet — ignore taps on them.
                if (ph_date_compare_keys(strip_days[_col].key, today_key) <= 0) {
                    global.selected_date_key = strip_days[_col].key;
                    hub_center_strip_on(strip_days[_col].dt);   // re-centre strip on tapped day
                }
            }
        }

        // Card tap — disabled only while the first-run tiles are still sliding in
        // (the cards are moving; resume normal taps the instant they settle).
        if ((!intro_active || intro_t >= 1)
            && ph_point_in_rect(_tap_x,_tap_y, 0,_body_top, PH_W,_body_bot)) {
            for (var _i = 0; _i < array_length(cards); _i++) {
                var _card = cards[_i];
                var _cy1  = _body_top + _i*(LAYOUT.card_h + LAYOUT.card_gap) - scroll_y;
                var _cy2  = _cy1 + LAYOUT.card_h;
                var _cx1  = LAYOUT.card_pad_x;
                var _cx2  = PH_W - LAYOUT.card_pad_x;
                if (ph_point_in_rect(_tap_x,_tap_y, _cx1,_cy1,_cx2,_cy2)) {
                    // Defensive: ignore the tap unless the card is unlocked AND
                    // has a real room to navigate to. Prevents room_goto(-1) if
                    // a card definition gets the locked/room fields out of sync.
                    if (!_card.locked && _card.room != "") {
                        var _rm_idx = asset_get_index(_card.room);
                        if (_rm_idx >= 0) {
                            global.input_locked_until = current_time + 200;
                            // First puzzle opened → first-run onboarding is complete;
                            // the soft finger hint never shows again (until a reset).
                            if (intro_active && !global.save.tutorial_done) {
                                global.save.tutorial_done = true;
                                ph_save_write(global.save);
                                intro_active = false;
                                ph_finger_hide(finger);
                            }
                            // Flag review mode explicitly so each puzzle's Create_0 can rely on it
                            if (_card.room == "rm_anygram") {
                                global.anygram_review_mode =
                                    ph_anygram_is_done(global.save, global.selected_date_key);
                            } else {
                                global.anygram_review_mode = false;
                            }
                            if (_card.room == "rm_sudoku") {
                                global.sudoku_review_mode =
                                    ph_sudoku_is_done(global.save, global.selected_date_key);
                            } else {
                                global.sudoku_review_mode = false;
                            }
                            if (_card.room == "rm_wordwave") {
                                global.wordwave_review_mode =
                                    ph_wordwave_is_done(global.save, global.selected_date_key);
                            } else {
                                global.wordwave_review_mode = false;
                            }
                            if (_card.room == "rm_shikaku") {
                                global.shikaku_review_mode =
                                    ph_shikaku_is_done(global.save, global.selected_date_key);
                            } else {
                                global.shikaku_review_mode = false;
                            }
                            if (_card.room == "rm_wordle") {
                                global.wordle_review_mode =
                                    ph_wordle_is_done(global.save, global.selected_date_key);
                            } else {
                                global.wordle_review_mode = false;
                            }
                            if (_card.room == "rm_huesort") {
                                global.huesort_review_mode =
                                    ph_huesort_is_done(global.save, global.selected_date_key);
                            } else {
                                global.huesort_review_mode = false;
                            }
                            if (_card.room == "rm_colorlink") {
                                global.colorlink_review_mode =
                                    ph_colorlink_is_done(global.save, global.selected_date_key);
                            } else {
                                global.colorlink_review_mode = false;
                            }
                            if (_card.room == "rm_wordbend") {
                                global.wordbend_review_mode =
                                    ph_wordbend_is_done(global.save, global.selected_date_key);
                            } else {
                                global.wordbend_review_mode = false;
                            }
                            if (_card.room == "rm_arrows") {
                                global.arrows_review_mode =
                                    ph_arrows_is_done(global.save, global.selected_date_key);
                            } else {
                                global.arrows_review_mode = false;
                            }
                            if (_card.room == "rm_ladder") {
                                global.ladder_review_mode =
                                    ph_ladder_is_done(global.save, global.selected_date_key);
                            } else {
                                global.ladder_review_mode = false;
                            }
                            if (_card.room == "rm_colordoku") {
                                global.colordoku_review_mode =
                                    ph_colordoku_is_done(global.save, global.selected_date_key);
                            } else {
                                global.colordoku_review_mode = false;
                            }
                            // Launch the iris transition from the tap point in the
                            // card's accent colour. obj_persistent covers the screen,
                            // swaps to _rm_idx under full cover, then reveals the game
                            // (so we do NOT room_goto directly here). Input stays
                            // locked for the whole transition.
                            global.input_locked_until = current_time + 800;
                            ph_trans_begin(_tap_x, _tap_y, _card.text_col, _rm_idx);
                        }
                    }
                    break;
                }
            }
        }
    }
}

// ── Scroll physics ────────────────────────────────────────────────────────────
if (!device_mouse_check_button(0, mb_left)) {
    scroll_vel *= 0.88;
    scroll_y   -= scroll_vel;
}
scroll_y = clamp(scroll_y, 0, scroll_max);

// ── First-run intro auto-scroll (overrides manual scroll while it plays) ──────
// Sweeps the list from the last game (scroll_max, bottom) up to the first game
// (0, top) with an ease-out, so it reads as the player flicking up through the
// whole list. Runs LAST so it wins over the drag/fling above. See Create_0.
if (intro_active && intro_t < 1) {
    scroll_y   = scroll_max * (1 - ph_ease_out(intro_t));
    scroll_vel = 0;
    intro_t    = min(1, intro_t + 1/INTRO_SLIDE_FR);
    if (intro_t >= 1) { intro_settle_t = 0; scroll_y = 0; }
}
