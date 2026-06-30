// ══════════════════════════════════════════════════════════════════════════════
// Daily Spin — free once-per-day prize wheel (retention hook)
// ──────────────────────────────────────────────────────────────────────────────
// A modal overlay shown on the hub. Unlocks on the player's
// PH_SPIN_UNLOCK_SESSION-th app launch, then offers one free spin per calendar
// day. Six equal slices; the prize is picked uniformly at random and the wheel
// animates to land on it. The player may DOUBLE the coins via the placeholder
// rewarded-video flow (mirrors scr_hint / obj_win). Reward is COINS only.
//
// Lives entirely in scripts + obj_hub (Create/Step/Draw) so it needs no new
// object/room — only this script registered as a resource. Struct-based, like
// scr_hint: obj_hub builds `spin = ph_spin_create()` in Create, opens it when
// `ph_spin_eligible(save)`, and calls tick/input/draw each frame.
//
// Phases: "idle" (waiting for the wheel tap) → "spinning" (≈PH_SPIN_SPIN_SECS) →
// "result" (CLAIM | DOUBLE) → (optional) "video" → granted + closed.
// ══════════════════════════════════════════════════════════════════════════════

/// True when the Daily Spin should be presented this session/day:
///   • the player has launched the app at least PH_SPIN_UNLOCK_SESSION times, and
///   • they haven't already claimed today's spin.
function ph_spin_eligible(_save) {
    if (!variable_struct_exists(_save, "session_count")) return false;
    if (_save.session_count < PH_SPIN_UNLOCK_SESSION) return false;

    // ⚠️ TEST MODE: N-minute cooldown from the last claim instead of once-per-day.
    // (Wall-clock datetime, so it persists across launches.) Set the macro to 0 to
    // restore the daily behaviour.
    if (PH_SPIN_TEST_COOLDOWN_MINS > 0) {
        if (!variable_struct_exists(_save, "spin_claimed_dt")) return true;
        var _last = _save.spin_claimed_dt;
        if (!is_real(_last) || _last <= 0) return true;
        return (date_minute_span(_last, date_current_datetime()) >= PH_SPIN_TEST_COOLDOWN_MINS);
    }

    var _claimed = variable_struct_exists(_save, "spin_claimed_date") ? _save.spin_claimed_date : "";
    return (_claimed != ph_today_key());
}

/// Build a fresh Daily Spin controller struct (closed).
function ph_spin_create() {
    var _s = {};
    _s.modal_open   = false;
    _s.open_t       = 0;            // 0..1 entrance ease
    _s.phase        = "idle";       // idle | spinning | result | video
    _s.prizes       = ph_spin_prizes();
    _s.slice_cols   = [PH_COL_PINK, PH_COL_ORANGE, PH_COL_YELLOW,
                       PH_COL_GREEN, PH_COL_BLUE, PH_COL_PURPLE];
    _s.prize_idx    = 0;
    _s.prize_amount = 0;
    _s.doubled      = false;
    _s.rot          = 0;            // wheel rotation (deg, clockwise)
    _s.rot_final    = 0;
    _s.spin_t       = 0;            // 0..1 over the spin
    _s.spin_dur     = max(1, round(PH_SPIN_SPIN_SECS * 60));
    _s.result_delay = 0;            // short beat after landing before the buttons
    _s.video_t      = 0;            // frames the placeholder video has shown
    _s.video_x_delay = 90;         // frames before the skip-X appears
    _s.grant_amount = 0;           // coins granted on the last claim (for the hub coin-flow)
    // Hit rects, filled in draw, read in input.
    _s.wheel_cx = 0; _s.wheel_cy = 0; _s.wheel_r = 0;
    _s.claim_l = 0; _s.claim_r = 0; _s.claim_t = 0; _s.claim_b = 0;
    _s.dbl_l   = 0; _s.dbl_r   = 0; _s.dbl_t   = 0; _s.dbl_b   = 0;
    _s.vx_cx = 0; _s.vx_cy = 0; _s.vx_r = 0;
    return _s;
}

function ph_spin_is_open(_s) {
    return _s.modal_open;
}

/// Open the modal and pre-roll the (hidden) prize so the landing is honest.
function ph_spin_open(_s) {
    _s.modal_open   = true;
    _s.open_t       = 0;
    _s.phase        = "idle";
    _s.doubled      = false;
    _s.rot          = 0;
    _s.spin_t       = 0;
    _s.result_delay = 0;
    _s.video_t      = 0;
    _s.last_tick_slice = -1;   // tracks pie-corner crossings for the spin haptic
    // Uniform random prize.
    _s.prize_idx    = irandom(array_length(_s.prizes) - 1);
    _s.prize_amount = _s.prizes[_s.prize_idx];
    // Land the chosen slice's centre under the top pointer after a few turns.
    // Slice i centre (clockwise-from-top) = i*60 + 30; pointer is at 0.
    var _seg = 360 / PH_SPIN_SLICES;
    _s.rot_final = 360 * PH_SPIN_FULL_TURNS + (360 - (_s.prize_idx * _seg + _seg/2));
}

/// Per-frame animation (runs regardless of the global input lock).
function ph_spin_tick(_s) {
    if (!_s.modal_open) return;
    if (_s.open_t < 1) _s.open_t = min(1, _s.open_t + 0.08);

    switch (_s.phase) {
        case "spinning":
            _s.spin_t = min(1, _s.spin_t + 1/_s.spin_dur);
            // Ease-out cubic so the wheel decelerates into the prize.
            var _e = 1 - power(1 - _s.spin_t, 3);
            _s.rot = _s.rot_final * _e;
            // Tick each time the pointer passes a pie corner. Because the wheel
            // decelerates, the crossings (and so the ticks) naturally go fast → slow
            // — the requested "triangle hitting each corner" feel. Debounced in
            // scr_haptics so the blur-fast early crossings don't overload the motor.
            var _seg_tick  = 360 / PH_SPIN_SLICES;
            var _cur_slice = floor(_s.rot / _seg_tick);
            if (_cur_slice != _s.last_tick_slice) {
                _s.last_tick_slice = _cur_slice;
                ph_haptic_select();
            }
            if (_s.spin_t >= 1) {
                _s.rot   = _s.rot_final;
                _s.phase = "result";
                _s.result_delay = 18;   // brief pause before buttons fully read
                ph_sfx(snd_star, 0.9);  // wheel lands on the prize
                ph_haptic_success();    // landed on the prize
            }
            break;
        case "result":
            if (_s.result_delay > 0) _s.result_delay--;
            break;
        case "video":
            _s.video_t++;
            break;
    }
}

/// Handle a tap. Returns:
///   "none"     — nothing actionable
///   "spun"     — the wheel was just started
///   "claimed"  — coins granted; modal closing (read _s.grant_amount for the hub)
function ph_spin_input(_s, _mx, _my) {
    if (!_s.modal_open) return "none";
    if (_s.open_t < 0.6) return "none";   // ignore taps until it has settled in

    var _pressed = device_mouse_check_button_released(0, mb_left);
    if (!_pressed) return "none";

    switch (_s.phase) {
        case "idle":
            // Tap anywhere on the wheel to spin.
            if (ph_point_in_circle(_mx, _my, _s.wheel_cx, _s.wheel_cy, _s.wheel_r)) {
                _s.phase  = "spinning";
                _s.spin_t = 0;
                ph_sfx(snd_button, 0.9);   // kick the wheel
                return "spun";
            }
            return "none";

        case "result":
            if (_s.result_delay > 0) return "none";
            if (ph_point_in_rect(_mx, _my, _s.claim_l, _s.claim_t, _s.claim_r, _s.claim_b)) {
                return ph_spin__grant(_s);
            }
            if (ph_point_in_rect(_mx, _my, _s.dbl_l, _s.dbl_t, _s.dbl_r, _s.dbl_b)) {
                _s.phase   = "video";
                _s.video_t = 0;
                return "none";
            }
            return "none";

        case "video":
            // Skip-X (top-right) resolves the rewarded video and doubles the prize.
            if (_s.video_t >= _s.video_x_delay
            &&  ph_point_in_circle(_mx, _my, _s.vx_cx, _s.vx_cy, _s.vx_r)) {
                _s.doubled      = true;
                _s.prize_amount = _s.prize_amount * 2;
                return ph_spin__grant(_s);
            }
            return "none";
    }
    return "none";
}

/// Grant the (possibly doubled) prize, mark today claimed, persist, close.
function ph_spin__grant(_s) {
    ph_grant_coins(global.save, _s.prize_amount);
    global.save.spin_claimed_date = ph_today_key();
    global.save.spin_claimed_dt   = date_current_datetime();   // for PH_SPIN_TEST_COOLDOWN_MINS
    ph_save_write(global.save);
    // The cooldown just reset — schedule the "spin ready" reminder for when the
    // next free spin becomes available (one-shot in test mode, daily in prod).
    ph_notify_sync_spin();
    _s.grant_amount = _s.prize_amount;
    _s.modal_open   = false;
    return "claimed";
}

// ──────────────────────────────────────────────────────────────────────────────
// Draw
// ──────────────────────────────────────────────────────────────────────────────

function ph_spin_draw(_s) {
    if (!_s.modal_open) return;
    var _ease = ph_ease_out(_s.open_t);
    var _cx   = PH_W / 2;
    var _sb   = global.safe_bottom_gui;

    // ── Cream bottom-sheet (reuses the hint-modal "yellow box" look) ───────────
    // It covers the lower half of the screen; the hub stays visible above, exactly
    // like the Penpot "Daily Spin Modal" design. The whole sheet (wheel + text)
    // slides up on open, so the readable content never sits over the dimmed hub.
    var _panel_top = round(PH_H * 0.45);
    var _slide     = (1 - _ease) * (PH_H - _panel_top + 120);

    // Gentle dim so the bright hub recedes a touch (kept light, per the design).
    draw_set_alpha(0.20 * _ease);
    draw_set_color(c_black);
    draw_rectangle(0, 0, PH_W, PH_H, false);
    draw_set_alpha(1);

    // Sheet — pale yellow, rounded top, bottom runs off-screen.
    ph_draw_rounded(0, _panel_top + _slide, PH_W, PH_H + 80 + _slide, 56, PH_COL_YELLOW_SOFT);

    // ── Wheel (top of the sheet, slightly overlapping above it) ─────────────────
    // Sized to the room between the sheet top and the bottom text/button block so
    // it fits on short canvases too.
    var _content_top = PH_H - 430 - _sb;            // reserve for claim text + buttons
    var _wheel_top   = _panel_top - 24;
    var _R = clamp((_content_top - _wheel_top) / 2, 180, 372);
    _R = min(_R, PH_W/2 - 78);
    var _wheel_cy = _wheel_top + _R + _slide;
    _s.wheel_cx = _cx; _s.wheel_cy = _wheel_cy; _s.wheel_r = _R;

    ph_spin__draw_wheel(_s, _cx, _wheel_cy, _R);

    // ── Pointer (red, top, pointing down into the wheel — design #f43327) ───────
    var _ptip_y = _wheel_cy - _R + 30;
    var _pw     = 40;
    var _pbase  = _wheel_cy - _R - 30;
    draw_set_color(make_color_rgb(190, 30, 22));
    draw_triangle(_cx - _pw - 3, _pbase - 2, _cx + _pw + 3, _pbase - 2, _cx, _ptip_y + 3, false);
    draw_set_color(make_color_rgb(244, 51, 39));
    draw_triangle(_cx - _pw, _pbase, _cx + _pw, _pbase, _cx, _ptip_y, false);

    // ── Centre hub ──────────────────────────────────────────────────────────────
    var _hub_r = _R * 0.30;
    draw_set_color(PH_COL_DARK);  draw_circle(_cx, _wheel_cy, _hub_r + 8, false);
    draw_set_color(PH_COL_WHITE); draw_circle(_cx, _wheel_cy, _hub_r, false);
    if (_s.phase == "idle") {
        ph_draw_text(_cx, _wheel_cy, "SPIN", global.fnt_disp_md, PH_COL_DARK, fa_center, fa_middle);
    } else {
        var _hs = (_hub_r * 1.3) / 256;
        draw_sprite_ext(global.spr_gold_coin, 0, _cx, _wheel_cy, _hs, _hs, 0, c_white, 1);
    }

    // ── Bottom content: idle title/subtitle  vs  result  vs  video ─────────────
    if (_s.phase == "idle" || _s.phase == "spinning") {
        var _ttl = (_s.phase == "idle") ? "Spin and Win!" : "Good luck!";
        ph_draw_text(_cx, PH_H - 300 - _sb + _slide, _ttl,
                     global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
        if (_s.phase == "idle")
            ph_draw_text(_cx, PH_H - 205 - _sb + _slide,
                         "Tap the wheel to earn your daily reward.",
                         global.fnt_body_md, PH_COL_INK_SOFT, fa_center, fa_middle);
    } else if (_s.phase == "result") {
        ph_spin__draw_result(_s, _cx, _slide);
    } else if (_s.phase == "video") {
        var _res = ph_video_overlay(_s.video_t, _s.video_x_delay, PH_COL_BLUE);
        _s.vx_cx = _res.cx; _s.vx_cy = _res.cy; _s.vx_r = _res.r;
    }
}

/// Six-wedge wheel with white separators, an outer rim + pegs, and prize labels.
function ph_spin__draw_wheel(_s, _cx, _cy, _R) {
    var _n   = PH_SPIN_SLICES;
    var _seg = 360 / _n;

    // Drop shadow.
    draw_set_alpha(0.25); draw_set_color(c_black);
    draw_circle(_cx, _cy + 10, _R + 6, false); draw_set_alpha(1);

    // Wedges.
    for (var _i = 0; _i < _n; _i++) {
        // GM directions: screen-up = 90; clockwise = decreasing direction.
        var _d0 = 90 - (_i * _seg + _s.rot);
        var _d1 = 90 - ((_i + 1) * _seg + _s.rot);
        ph_spin__wedge(_cx, _cy, _R, _d0, _d1, _s.slice_cols[_i]);
    }

    // White separators between slices.
    draw_set_color(PH_COL_WHITE);
    for (var _i = 0; _i <= _n; _i++) {
        var _d = 90 - (_i * _seg + _s.rot);
        var _x2 = _cx + lengthdir_x(_R, _d);
        var _y2 = _cy + lengthdir_y(_R, _d);
        draw_line_width(_cx, _cy, _x2, _y2, 6);
    }

    // Prize labels — angled radially per slice (Penpot "Daily Spin Modal"):
    //   • the COIN sits on the OUTER side, near the rim;
    //   • the NUMBER sits inward of it, RIGHT-ALIGNED to the coin — i.e. every
    //     number's outer edge stops at the same fixed gap below the coin, so
    //     longer prizes (150) grow inward rather than drifting under the coin.
    // The label rotation follows its slice's radius, folded into [-90,90] so all
    // numbers stay readable (top & bottom read vertical, the sides fan out).
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_font(global.fnt_num_md);

    var _coin_px   = 84;                 // drawn coin diameter
    var _coin_R    = _R * 0.80;          // coin centre radius (outer, near rim)
    var _num_edge_R = _coin_R - _coin_px*0.5 - 14;  // radius of each number's OUTER edge

    for (var _i = 0; _i < _n; _i++) {
        var _dc = 90 - (_i * _seg + _seg/2 + _s.rot);   // GM dir to the slice centre

        // Coin — outer, on the slice bisector.
        var _kx = _cx + lengthdir_x(_coin_R, _dc);
        var _ky = _cy + lengthdir_y(_coin_R, _dc);
        draw_sprite_ext(global.spr_gold_coin, 0, _kx, _ky, _coin_px/256, _coin_px/256, 0, c_white, 1);

        // Number — inward, anchored so its outer edge meets _num_edge_R (the text
        // reads along the radius, so half its width offsets the centre inward).
        // Fold the label upright/readable, but offset the fold SEAM by half a slice
        // so it sits BETWEEN slices, never on a slice centre. The winning slice
        // always rests with its centre at the top (_dc = 90); keeping the seam off
        // the centres stops the top number from flipping 180° as the wheel settles.
        var _bias = _seg * 0.5;
        var _ang = _dc;
        while (_ang >   90 + _bias) _ang -= 180;
        while (_ang <= -90 + _bias) _ang += 180;
        var _str = string(_s.prizes[_i]);
        var _num_R = _num_edge_R - string_width(_str) * 0.5;
        var _lx = _cx + lengthdir_x(_num_R, _dc);
        var _ly = _cy + lengthdir_y(_num_R, _dc);

        draw_set_color(make_color_rgb(0, 0, 0));
        draw_text_transformed(_lx + 3, _ly + 3, _str, 1, 1, _ang);   // drop shadow
        draw_set_color(PH_COL_WHITE);
        draw_text_transformed(_lx, _ly, _str, 1, 1, _ang);
    }

    // Outer rim ring + peg dots.
    draw_set_color(PH_COL_YELLOW_DEEP);
    draw_circle_outline_thick(_cx, _cy, _R + 4, 14);
    draw_set_color(PH_COL_WHITE);
    for (var _i = 0; _i < _n; _i++) {
        var _d = 90 - (_i * _seg + _s.rot);
        draw_circle(_cx + lengthdir_x(_R + 4, _d), _cy + lengthdir_y(_R + 4, _d), 8, false);
    }
}

/// Filled circular sector via a triangle fan (untextured solid colour).
function ph_spin__wedge(_cx, _cy, _R, _d0, _d1, _col) {
    var _segs = 16;
    draw_primitive_begin(pr_trianglefan);
    draw_vertex_color(_cx, _cy, _col, 1);
    for (var _k = 0; _k <= _segs; _k++) {
        var _d = lerp(_d0, _d1, _k/_segs);
        draw_vertex_color(_cx + lengthdir_x(_R, _d), _cy + lengthdir_y(_R, _d), _col, 1);
    }
    draw_primitive_end();
}

/// Thick ring outline (GM's draw_circle has no width, so stroke it as a band).
function draw_circle_outline_thick(_cx, _cy, _R, _w) {
    var _segs = 64;
    var _ri = _R - _w/2, _ro = _R + _w/2;
    draw_primitive_begin(pr_trianglestrip);
    for (var _k = 0; _k <= _segs; _k++) {
        var _d = (_k/_segs) * 360;
        draw_vertex(_cx + lengthdir_x(_ri, _d), _cy + lengthdir_y(_ri, _d));
        draw_vertex(_cx + lengthdir_x(_ro, _d), _cy + lengthdir_y(_ro, _d));
    }
    draw_primitive_end();
}

/// "Claim your reward!" + amount + CLAIM | DOUBLE, laid out in the cream sheet
/// (dark text on yellow, image-backed buttons — mirrors the win screen). _slide is
/// the open animation offset so the block rides up with the sheet.
function ph_spin__draw_result(_s, _cx, _slide) {
    var _sb = global.safe_bottom_gui;
    var _claim_y = PH_H - 430 - _sb + _slide;
    var _amt_y   = PH_H - 312 - _sb + _slide;
    var _btn_cy  = PH_H - 175 - _sb + _slide;
    var _bh = 70, _gap = 30;

    ph_draw_text(_cx, _claim_y, "Claim your reward!", global.fnt_disp_md,
                 PH_COL_DARK, fa_center, fa_middle);

    // Reward amount: "<amount>  🪙" — dark (not yellow), comfortably spaced.
    var _amt = string(_s.prize_amount);
    draw_set_font(global.fnt_num_xl);
    var _anw   = string_width(_amt);
    var _acoin = 100, _agap = 20;
    var _ax0   = _cx - (_anw + _agap + _acoin)/2;
    ph_draw_text(_ax0 + _anw/2, _amt_y, _amt, global.fnt_num_xl, PH_COL_DARK, fa_center, fa_middle);
    draw_sprite_ext(global.spr_gold_coin, 0, _ax0 + _anw + _agap + _acoin/2, _amt_y,
                    _acoin/256, _acoin/256, 0, c_white, 1);

    // Buttons (image-backed via ph_draw_reward_btn → blue button art).
    _s.claim_l = 70;             _s.claim_r = _cx - _gap/2;
    _s.dbl_l   = _cx + _gap/2;   _s.dbl_r   = PH_W - 70;
    _s.claim_t = _btn_cy - _bh;  _s.claim_b = _btn_cy + _bh;
    _s.dbl_t   = _btn_cy - _bh;  _s.dbl_b   = _btn_cy + _bh;

    ph_draw_reward_btn(_s.claim_l, _btn_cy, _s.claim_r, _bh, "CLAIM",  noone,         false);
    ph_draw_reward_btn(_s.dbl_l,   _btn_cy, _s.dbl_r,   _bh, "DOUBLE", global.spr_tv, true);
}
