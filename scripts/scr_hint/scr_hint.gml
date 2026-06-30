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

/// @param _apply    bound method that reveals one hint (no coin handling).
/// @param _accent   colour for the modal close-X / video close-X discs.
/// @param _subtitle one/two-line description of what this puzzle's hint reveals,
///                  shown under the "Want to use a hint?" title (use "\n" to wrap).
function ph_hint_create(_apply, _accent, _subtitle = "", _key = "") {
    return {
        apply        : _apply,
        accent       : _accent,
        subtitle     : _subtitle,
        key          : _key,     // "<puzzle>_<date>" (== claim_key) for no-hint mission tracking

        modal_open   : false,
        modal_t      : 0,        // slide-in progress 0..1
        video_open   : false,
        video_timer  : 0,        // frames since the placeholder opened
        coin_minus_t : 1.0,      // "-100" feedback (1.0 == idle)
        VIDEO_X_DELAY: 300,      // ~5s @60fps before the close X appears

        // ── Reveal animation (the "circle smalling down to the hinted area") ─────
        // After BUY/FREE, instead of returning "paid"/"freed" immediately we play a
        // reveal onto the hinted cell, hold input, and emit the result ONLY when it
        // finishes — so the win-check (run by the controller on paid/freed) lands
        // AFTER the reveal. The apply method returns the target so we know where to
        // aim; a puzzle can opt out of the default iris (reveal_iris=false) and draw
        // its own reveal (e.g. Color Link's snake) off ph_hint_reveal_p().
        result_pending : "",      // "" idle, else "paid"/"freed" awaiting reveal end
        reveal_active  : false,
        reveal_t       : 0,       // frames elapsed in the current reveal
        reveal_frames  : 30,      // this call's duration (apply may override)
        reveal_iris    : true,    // draw the default iris? (false = puzzle-custom)
        reveal_x       : PH_W/2,  // iris target centre (GUI space)
        reveal_y       : PH_H/2,
        reveal_r       : 95,      // iris landing radius (≈ a cell; apply may override)
        REVEAL_FR_DEF  : 30,      // default reveal duration (frames)
        REVEAL_R0      : 560,     // iris start radius (large, sweeps inward)
        REVEAL_WIND    : 0.14,    // wind-up fraction: brief expand before contracting

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

/// True while any hint overlay/animation is showing (gating other UI/input).
function ph_hint_is_open(_h) {
    return _h.modal_open || _h.video_open || _h.reveal_active || _h.result_pending != "";
}

/// True while the post-buy reveal animation is playing (controllers can drive a
/// custom reveal off this + ph_hint_reveal_p).
function ph_hint_revealing(_h) {
    return _h.reveal_active;
}

/// Reveal progress 0..1 (for puzzle-custom reveals, e.g. Color Link's snake).
function ph_hint_reveal_p(_h) {
    if (_h.reveal_frames <= 0) return 1;
    return clamp(_h.reveal_t / _h.reveal_frames, 0, 1);
}

/// Advance animation timers. Call exactly once per Step, before the input gate.
function ph_hint_tick(_h) {
    if (_h.modal_open && _h.modal_t < 1) _h.modal_t = min(1, _h.modal_t + 1/12);
    if (_h.coin_minus_t < 1)             _h.coin_minus_t = min(1, _h.coin_minus_t + 1/45);
    if (_h.video_open)                   _h.video_timer++;
    if (_h.reveal_active) {
        _h.reveal_t++;
        if (_h.reveal_t >= _h.reveal_frames) _h.reveal_active = false;
    }
}

/// Kick off the reveal after a successful BUY/FREE. Calls apply() (which reveals
/// the hint + returns its target) and arms the reveal animation. The deferred
/// result (_kind) is emitted by ph_hint_input once the reveal finishes.
function ph_hint__begin_reveal(_h, _kind) {
    ph_sfx(snd_hint, 0.85);   // magical shimmer as the hint reveals
    ph_haptic_success();      // satisfying confirm as the hint lands (shared by every puzzle)
    _h.result_pending = _kind;
    _h.reveal_t       = 0;
    _h.reveal_frames  = _h.REVEAL_FR_DEF;
    _h.reveal_iris    = true;
    var _tgt = _h.apply();             // reveals the hint; returns target {x,y,r,frames,iris}
    if (is_struct(_tgt)) {
        if (variable_struct_exists(_tgt, "x"))      _h.reveal_x      = _tgt.x;
        if (variable_struct_exists(_tgt, "y"))      _h.reveal_y      = _tgt.y;
        if (variable_struct_exists(_tgt, "r"))      _h.reveal_r      = _tgt.r;
        if (variable_struct_exists(_tgt, "frames")) _h.reveal_frames = _tgt.frames;
        if (variable_struct_exists(_tgt, "iris"))   _h.reveal_iris   = _tgt.iris;
        _h.reveal_active = (_h.reveal_frames > 0);
    } else {
        _h.reveal_active = false;      // legacy apply (no target) → emit result next step
    }
}

/// Process a tap while an overlay is open. Returns:
///   "none"     — no overlay open; caller continues normal input.
///   "consumed" — overlay open; tap (if any) handled. Caller should exit.
///   "paid"     — coins spent & hint applied (caller may toast).
///   "freed"    — video finished & hint applied for free (caller may toast).
///   "poor"     — tried to pay but couldn't afford it (caller may toast).
/// Coin spend, "-100" feedback, hint reveal, and save are all done here.
function ph_hint_input(_h) {
    // Reveal in progress: eat input, then emit the deferred result ONCE it ends so
    // the controller's win-check (run on paid/freed) lands AFTER the reveal.
    if (_h.result_pending != "") {
        if (_h.reveal_active) return "consumed";
        var _k = _h.result_pending;
        _h.result_pending = "";
        return _k;                       // "paid" or "freed"
    }

    if (_h.video_open) {
        if (device_mouse_check_button_pressed(0, mb_left) && _h.video_timer >= _h.VIDEO_X_DELAY) {
            var _mx = device_mouse_x_to_gui(0);
            var _my = device_mouse_y_to_gui(0);
            if (ph_point_in_circle(_mx, _my, _h.vx_cx, _h.vx_cy, _h.vx_r + 14)) {
                _h.video_open = false;       // free — no coins removed
                ph_week_mark_hint_used(global.save, _h.key);
                ph_hint__begin_reveal(_h, "freed");
                return "consumed";
            }
        }
        return "consumed";
    }

    if (_h.modal_open) {
        if (device_mouse_check_button_pressed(0, mb_left)) {
            var _mx = device_mouse_x_to_gui(0);
            var _my = device_mouse_y_to_gui(0);
            var _afford = (global.save.coins >= PH_HINT_COST);
            if (ph_point_in_circle(_mx, _my, _h.x_cx, _h.x_cy, _h.x_r + 14)) {
                _h.modal_open = false;        // close X
            } else if (_afford && ph_point_in_rect(_mx, _my, _h.pay_l, _h.pay_t, _h.pay_r, _h.pay_b)) {
                // BUY — only reachable when affordable (else the button is disabled).
                ph_spend_coins(global.save, PH_HINT_COST);
                _h.modal_open   = false;
                _h.coin_minus_t = 0;          // fire the "-100" HUD feedback
                ph_week_mark_hint_used(global.save, _h.key);
                ph_save_write(global.save);
                ph_hint__begin_reveal(_h, "paid");
                return "consumed";
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

    // ── Bottom-anchored content stack ─────────────────────────────────────────
    // The GUI canvas height (PH_H) is dynamic, so the modal anchors its whole
    // stack to the button row near the bottom and builds upward; the sheet top is
    // then placed just under the bulb. This keeps bulb · title · subtitle · cost ·
    // buttons all visible even on short (e.g. iPad) canvases.
    var _cy  = PH_H - 180 - global.safe_bottom_gui;   // button row centre
    var _bh  = 70;     // half-height → 140px capsule
    var _gap = 30;

    var _panel_top = _cy - 560;        // sheet top (bulb overflows above it)
    _h.panel_top = _panel_top;
    var _slide = (1 - _ease) * (PH_H - _panel_top + 80);   // fully below at t=0

    // Sheet (pale yellow, rounded top; bottom runs off-screen).
    ph_draw_rounded(0, _panel_top + _slide, PH_W, PH_H + 80 + _slide, 56, PH_COL_YELLOW_SOFT);

    // Bulb (emerges above the sheet top) + title + per-puzzle subtitle.
    draw_sprite_ext(global.spr_bulb, 0, PH_W/2, _cy - 640 + _slide, 0.62, 0.62, 0, c_white, 1);
    ph_draw_text(PH_W/2, _cy - 450 + _slide, "Want to use a hint?",
                 global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
    if (_h.subtitle != "") {
        ph_draw_text(PH_W/2, _cy - 315 + _slide, _h.subtitle,
                     global.fnt_body_md, PH_COL_INK_SOFT, fa_center, fa_middle);
    }

    // Close X (top-right of the sheet).
    _h.x_cx = PH_W - 90; _h.x_cy = _panel_top + 80; _h.x_r = 46;
    draw_set_color(_h.accent);
    draw_circle(_h.x_cx, _h.x_cy + _slide, _h.x_r, false);
    ph_draw_text(_h.x_cx, _h.x_cy + _slide, "X", global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);

    // Cost amount: "<cost>  🪙" (large Nunito number + gold coin) above the buttons,
    // per the updated design — the price moves off the BUY button onto its own row.
    var _amt   = string(PH_HINT_COST);
    draw_set_font(global.fnt_num_xl);
    var _anw   = string_width(_amt);
    var _acoin = 110, _agap = 22;
    var _ax0   = PH_W/2 - (_anw + _agap + _acoin)/2;
    var _amt_cy = _cy - 165 + _slide;
    ph_draw_text(_ax0 + _anw/2, _amt_cy, _amt, global.fnt_num_xl, PH_COL_DARK, fa_center, fa_middle);
    draw_sprite_ext(global.spr_gold_coin, 0, _ax0 + _anw + _agap + _acoin/2, _amt_cy, _acoin/256, _acoin/256, 0, c_white, 1);

    // Two pill buttons across the bottom.
    _h.pay_l  = 70;               _h.pay_r  = PH_W/2 - _gap/2;
    _h.free_l = PH_W/2 + _gap/2;  _h.free_r = PH_W - 70;
    _h.pay_t  = _cy - _bh;  _h.pay_b  = _cy + _bh;
    _h.free_t = _cy - _bh;  _h.free_b = _cy + _bh;
    var _dcy = _cy + _slide;

    // BUY (bare word label) | FREE + retro TV.  Green reward buttons, uniform with
    // the blue claim buttons (per the updated design). BUY is DISABLED (greyed,
    // non-tappable — see ph_hint_input) when the player can't afford the hint; FREE
    // (rewarded video) always stays available.
    var _afford = (global.save.coins >= PH_HINT_COST);
    if (_afford) {
        ph_draw_reward_btn(_h.pay_l, _dcy, _h.pay_r, _bh, "BUY", noone, false, PH_COL_GREEN, PH_COL_GREEN_DEEP);
    } else {
        var _dis = make_color_rgb(176, 170, 162);   // muted grey (no sprite mapping → primitive chip)
        ph_draw_reward_btn(_h.pay_l, _dcy, _h.pay_r, _bh, "BUY", noone, false, _dis, make_color_rgb(150, 144, 137));
    }
    ph_draw_reward_btn(_h.free_l, _dcy, _h.free_r, _bh, "FREE", global.spr_tv, false, PH_COL_GREEN, PH_COL_GREEN_DEEP);

    // ── Coin balance — kept readable ON TOP of the dim so the player can see how
    // much they have (and whether BUY is affordable) without closing the modal.
    var _bal_r = PH_W - 50;
    var _bal_l = _bal_r - 220;
    var _bal_y = 95 + global.safe_top_gui;
    ph_draw_chip(_bal_l, _bal_y - 33, _bal_r, _bal_y + 33, 33, PH_COL_WHITE, make_color_rgb(150, 134, 120), 6);
    draw_sprite_ext(global.spr_gold_coin, 0, _bal_l + 23, _bal_y, 112/512, 112/512, 0, c_white, 1);
    ph_draw_text(_bal_l + 74, _bal_y, string(global.save.coins), global.fnt_pill_num, PH_COL_DARK, fa_left, fa_middle);
}

/// ── Post-buy hint reveal (the "circle smalling down to the hinted area") ───────
/// Draws the default iris: a translucent accent spotlight that briefly winds up,
/// then CONTRACTS onto the hinted cell (ease-in-out), fading its fill as it lands
/// so the revealed element shows through, punctuated by an additive landing flash.
/// Puzzles that set reveal_iris=false draw their own reveal instead (off
/// ph_hint_reveal_p) — this is a no-op for them. Call near the end of Draw, after
/// the board/HUD and before the modal/video helpers.
function ph_hint_draw_reveal(_h) {
    if (!_h.reveal_active || !_h.reveal_iris) return;
    var _p  = ph_hint_reveal_p(_h);
    var _cx = _h.reveal_x, _cy = _h.reveal_y;
    var _r0 = _h.REVEAL_R0, _rt = _h.reveal_r, _w = _h.REVEAL_WIND;

    var _r, _fillA;
    if (_p < _w) {                                   // 1) anticipation — expand a touch
        var _u = _p / _w;
        _r     = _r0 * (1 + 0.05 * ph_ease_out(_u));
        _fillA = 0.30;
    } else {                                         // 2) action — contract onto target
        var _u = (_p - _w) / (1 - _w);
        _r     = lerp(_r0, _rt, ph_ease_in_out(_u));
        _fillA = lerp(0.30, 0.0, ph_ease_in(_u));    // fade fill as it lands → reveals element
    }

    // Soft accent spotlight fill.
    draw_set_color(_h.accent);
    draw_set_alpha(_fillA);
    draw_circle(_cx, _cy, _r, false);
    draw_set_alpha(1);

    // Crisp accent ring (a few stacked outlines for weight).
    draw_set_color(_h.accent);
    for (var _k = 0; _k < 7; _k++) draw_circle(_cx, _cy, max(1, _r - _k), true);

    // 3) reaction — additive landing flash as the ring reaches the cell.
    if (_p > 0.80) {
        var _f = (_p - 0.80) / 0.20;                 // 0..1
        gpu_set_blendmode(bm_add);
        draw_set_color(c_white);
        draw_set_alpha((1 - _f) * 0.85);
        draw_circle(_cx, _cy, _rt * (0.55 + 1.0 * _f), false);
        draw_set_alpha(1);
        gpu_set_blendmode(bm_normal);
    }
}

/// ── HINT pill (with idle bounce) ──────────────────────────────────────────────
/// Draws the standard HINT pill — white chip · bulb · "HINT" — and, after
/// PH_HINT_IDLE_SECS of no taps anywhere, makes the whole pill BOUNCE (a couple of
/// quick decaying hops, then a rest) to remind the player help is available. Reads
/// the global idle anchor maintained in obj_persistent. The hit bounds (_t/_b) are
/// the resting position and don't move, so taps stay accurate. Replaces the old
/// per-puzzle chip+bulb+text draw lines + the pulsing-ring nudge.
function ph_hint_pill_draw(_l, _t, _r, _b, _shadow) {
    var _cy = (_t + _b) / 2;

    // Idle bounce offset (0 while the player is active).
    var _dy = 0;
    if (variable_global_exists("ph_idle_anchor")) {
        var _idle = (current_time - global.ph_idle_anchor) / 1000;
        if (_idle >= PH_HINT_IDLE_SECS) {
            var _period = 1400;     // one bounce cadence
            var _amp    = 18;       // hop height (px)
            var _phase  = ((current_time - global.ph_idle_anchor) mod _period) / _period;
            if (_phase < 0.45) {                 // bounce window, then rest
                var _u = _phase / 0.45;          // 0..1
                _dy = -_amp * abs(sin(_u * pi * 2)) * (1 - _u);   // two decaying hops up
            }
        }
    }

    ph_draw_chip(_l, _t + _dy, _r, _b + _dy, 33, PH_COL_WHITE, _shadow, 6);
    draw_sprite_ext(global.spr_bulb, 0, _l + 12, _cy + _dy, 101/512, 101/512, 0, c_white, 1);
    ph_draw_text(_l + 51, _cy + _dy, "HINT", global.fnt_pill_num, PH_COL_DARK, fa_left, fa_middle);
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
