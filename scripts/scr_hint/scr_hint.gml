// ── Shared hint-acquisition flow (modal + placeholder rewarded video) ─────────
// One implementation reused by every puzzle controller. The only per-puzzle
// part is the reveal itself, supplied as a bound method via ph_hint_create().
//
// Lifecycle from a controller:
//   Create : hint = ph_hint_create(my_apply_method, accent_colour);
//   Step   : ph_hint_tick(hint);                       // once, near other timers
//            var _r = ph_hint_input(hint);             // before normal input
//            if (_r != "none") { ...optional toast...; exit; }
//            ... // when a hint becomes wanted, gate then open:
//            if (can_hint) ph_hint_open(hint); else toast(...);
//   Draw   : (after drawing the coin pill) set hint.coin_x/coin_y, then
//            ph_hint_draw_feedback(hint);
//            ph_hint_draw_modal(hint);                 // end of play-screen draw
//            ph_hint_draw_video(hint);                 // very last (covers all)
//
// The apply method MUST reveal exactly one hint and MUST NOT touch coins — the
// coin spend, "-100" feedback, and save flush for the paid path are handled here.

/// @param _apply  bound method that reveals one hint (no coin handling).
/// @param _accent colour for the modal close-X / video close-X discs.
function ph_hint_create(_apply, _accent) {
    return {
        apply        : _apply,
        accent       : _accent,
        modal_open   : false,
        modal_t      : 0,        // slide-in progress 0..1
        video_open   : false,
        video_timer  : 0,        // frames since the placeholder opened
        coin_minus_t : 1.0,      // "-100" feedback (1.0 == idle)
        VIDEO_X_DELAY: 300,      // ~5s @60fps before the close X appears

        // "-100" / coin-fly target — the caller refreshes this each Draw.
        coin_x : PH_W - 160,
        coin_y : 95,

        // Hit-test bounds, written at SETTLED positions by ph_hint_draw_modal /
        // ph_hint_draw_video so taps match the resting layout even mid-slide.
        panel_top : round(PH_H * 0.46),
        pay_l  : 70, pay_r : PH_W/2 - 15, pay_t : PH_H - 300, pay_b : PH_H - 160,
        free_l : PH_W/2 + 15, free_r : PH_W - 70, free_t : PH_H - 300, free_b : PH_H - 160,
        x_cx   : PH_W - 90, x_cy : round(PH_H * 0.46) + 80, x_r : 46,
        vx_cx  : PH_W - 90, vx_cy : 90, vx_r : 46,
    };
}

/// Open the modal. Call after the controller's own availability checks pass.
function ph_hint_open(_h) {
    _h.modal_open = true;
    _h.modal_t    = 0;
}

/// True while either overlay is showing (handy for gating other UI/input).
function ph_hint_is_open(_h) {
    return _h.modal_open || _h.video_open;
}

/// Advance animation timers. Call exactly once per Step, before the input gate.
function ph_hint_tick(_h) {
    if (_h.modal_open && _h.modal_t < 1) _h.modal_t = min(1, _h.modal_t + 1/12);
    if (_h.coin_minus_t < 1)             _h.coin_minus_t = min(1, _h.coin_minus_t + 1/45);
    if (_h.video_open)                   _h.video_timer++;
}

/// Process a tap while an overlay is open. Returns:
///   "none"     — no overlay open; caller continues normal input.
///   "consumed" — overlay open; tap (if any) handled. Caller should exit.
///   "paid"     — coins spent & hint applied (caller may toast).
///   "freed"    — video finished & hint applied for free (caller may toast).
///   "poor"     — tried to pay but couldn't afford it (caller may toast).
/// Coin spend, "-100" feedback, hint reveal, and save are all done here.
function ph_hint_input(_h) {
    if (_h.video_open) {
        if (device_mouse_check_button_pressed(0, mb_left) && _h.video_timer >= _h.VIDEO_X_DELAY) {
            var _mx = device_mouse_x_to_gui(0);
            var _my = device_mouse_y_to_gui(0);
            if (ph_point_in_circle(_mx, _my, _h.vx_cx, _h.vx_cy, _h.vx_r + 14)) {
                _h.video_open = false;
                _h.apply();                  // free — no coins removed
                return "freed";
            }
        }
        return "consumed";
    }

    if (_h.modal_open) {
        if (device_mouse_check_button_pressed(0, mb_left)) {
            var _mx = device_mouse_x_to_gui(0);
            var _my = device_mouse_y_to_gui(0);
            if (ph_point_in_circle(_mx, _my, _h.x_cx, _h.x_cy, _h.x_r + 14)) {
                _h.modal_open = false;        // close X
            } else if (ph_point_in_rect(_mx, _my, _h.pay_l, _h.pay_t, _h.pay_r, _h.pay_b)) {
                if (ph_spend_coins(global.save, PH_HINT_COST)) {
                    _h.modal_open   = false;
                    _h.coin_minus_t = 0;      // fire the "-100" HUD feedback
                    _h.apply();
                    ph_save_write(global.save);
                    return "paid";
                } else {
                    _h.modal_open = false;
                    return "poor";
                }
            } else if (ph_point_in_rect(_mx, _my, _h.free_l, _h.free_t, _h.free_r, _h.free_b)) {
                _h.modal_open  = false;       // open the placeholder video
                _h.video_open  = true;
                _h.video_timer = 0;
            } else if (_my < _h.panel_top) {
                _h.modal_open = false;        // tap on the dim above the sheet
            }
        }
        return "consumed";
    }

    return "none";
}

/// "-100" coin-spend feedback rising/fading near (_h.coin_x, _h.coin_y).
/// Call in Draw right after the coin pill is rendered (and coords refreshed).
function ph_hint_draw_feedback(_h) {
    if (_h.coin_minus_t < 1) {
        var _a    = 1 - _h.coin_minus_t;
        var _rise = 70 - _h.coin_minus_t * 60;
        draw_set_alpha(_a);
        ph_draw_text(_h.coin_x, _h.coin_y + _rise, "-" + string(PH_HINT_COST),
                     global.fnt_disp_sm, PH_COL_PINK, fa_center, fa_middle);
        draw_set_alpha(1);
    }
}

/// Slide-up bottom-sheet modal. Writes settled hit bounds into _h every frame.
function ph_hint_draw_modal(_h) {
    if (!_h.modal_open) return;
    var _ease = ph_ease_out(_h.modal_t);

    // Dim backdrop (fades in with the slide).
    draw_set_alpha(0.55 * _ease);
    draw_set_color(c_black);
    draw_rectangle(0, 0, PH_W, PH_H, false);
    draw_set_alpha(1);

    var _panel_top = round(PH_H * 0.46);
    _h.panel_top = _panel_top;
    var _slide = (1 - _ease) * (PH_H - _panel_top + 80);   // fully below at t=0

    // Sheet (pale yellow, rounded top; bottom runs off-screen).
    ph_draw_rounded(0, _panel_top + _slide, PH_W, PH_H + 80 + _slide, 56, PH_COL_YELLOW_SOFT);

    // Bulb + title.
    draw_sprite_ext(global.spr_bulb, 0, PH_W/2, _panel_top + 200 + _slide, 0.62, 0.62, 0, c_white, 1);
    ph_draw_text(PH_W/2, _panel_top + 440 + _slide, "Want to use a hint?",
                 global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);

    // Close X (top-right of the sheet).
    _h.x_cx = PH_W - 90; _h.x_cy = _panel_top + 80; _h.x_r = 46;
    draw_set_color(_h.accent);
    draw_circle(_h.x_cx, _h.x_cy + _slide, _h.x_r, false);
    ph_draw_text(_h.x_cx, _h.x_cy + _slide, "X", global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);

    // Two pill buttons across the bottom.
    var _cy  = PH_H - 230 - global.safe_bottom_gui;
    var _bh  = 70;     // half-height → 140px capsule
    var _gap = 30;
    _h.pay_l  = 70;               _h.pay_r  = PH_W/2 - _gap/2;
    _h.free_l = PH_W/2 + _gap/2;  _h.free_r = PH_W - 70;
    _h.pay_t  = _cy - _bh;  _h.pay_b  = _cy + _bh;
    _h.free_t = _cy - _bh;  _h.free_b = _cy + _bh;
    var _dcy = _cy + _slide;

    // Pay: "Buy 100" + gold coin.  Free: "FREE" + retro TV.  Green reward buttons,
    // uniform with the blue claim buttons (per the updated design).
    ph_draw_reward_btn(_h.pay_l,  _dcy, _h.pay_r,  _bh, "Buy " + string(PH_HINT_COST), global.spr_gold_coin, false, PH_COL_GREEN, PH_COL_GREEN_DEEP);
    ph_draw_reward_btn(_h.free_l, _dcy, _h.free_r, _bh, "FREE",                        global.spr_tv,        false, PH_COL_GREEN, PH_COL_GREEN_DEEP);
}

/// Full-screen dark placeholder for the rewarded video. Call LAST in Draw so it
/// covers every other layer. The close X appears only after VIDEO_X_DELAY.
function ph_hint_draw_video(_h) {
    if (!_h.video_open) return;
    var _b = ph_video_overlay(_h.video_timer, _h.VIDEO_X_DELAY, _h.accent);
    _h.vx_cx = _b.cx; _h.vx_cy = _b.cy; _h.vx_r = _b.r;
}

// ── Generic placeholder rewarded-video overlay ────────────────────────────────
// Shared dark "VIDEO PLAYING" screen used by both the hint flow and the Level-Up
// reward screen, so the placeholder looks identical everywhere (stand-in until
// the ad SDK ships). Draws a full-screen cover and, once _timer >= _delay, a
// close-X disc in the top-right. Returns the X hit circle as { cx, cy, r, shown }.
function ph_video_overlay(_timer, _delay, _accent) {
    draw_set_color(make_color_rgb(8, 8, 12));
    draw_rectangle(0, 0, PH_W, PH_H, false);
    ph_draw_text(PH_W/2, PH_H/2, "VIDEO PLAYING", global.fnt_disp_md, PH_COL_WHITE, fa_center, fa_middle);
    var _res = { cx: PH_W - 90, cy: 90 + global.safe_top_gui, r: 46, shown: (_timer >= _delay) };
    if (_res.shown) {
        draw_set_color(_accent);
        draw_circle(_res.cx, _res.cy, _res.r, false);
        ph_draw_text(_res.cx, _res.cy, "X", global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);
    }
    return _res;
}
