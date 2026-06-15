// ── Level-Up reward screen — Draw GUI ─────────────────────────────────────────
if (!valid) exit;

// ── Backdrop — lighter violet per the design (deep-purple text reads on it). ──
// No white card any more: the elements sit directly on the backdrop.
var _bg     = make_color_rgb(173, 81, 246);   // #ad51f6
var _purple = make_color_rgb( 98, 39, 197);   // #6227c5
draw_set_color(_bg);
draw_rectangle(0, 0, PH_W, PH_H, false);

var _cx = PH_W / 2;
var _st = ph_safe_top();
var _sb = ph_safe_bottom();
// Gentle slide-up settle (replaces the old card slide).
var _slide = (1 - ph_ease_out(min(anim_t * 1.3, 1))) * 120;

// ── Top stack: Congratulations → level number → LEVEL UP! ─────────────────────
ph_draw_text(_cx, _st + 220 + _slide, "Congratulations", global.fnt_disp_xl,  _purple,      fa_center, fa_middle);
ph_draw_text(_cx, _st + 430 + _slide, string(level),     global.fnt_disp_xxl, PH_COL_WHITE, fa_center, fa_middle);
ph_draw_text(_cx, _st + 650 + _slide, "LEVEL UP!",       global.fnt_disp_xxl, _purple,      fa_center, fa_middle);

// Star (plain 3D purple star — no number overlay).
draw_sprite_ext(global.spr_star3d, 0, _cx, _st + 930 + _slide, 0.66, 0.66, 0, c_white, 1);

// ── Reward prompt + buttons (bottom-anchored) ─────────────────────────────────
// Settled bounds are written to PAY_*/DBL_* (read by Step); the slide offset is
// applied to drawing only so taps match the resting layout even mid-animation.
var _bh     = 70;
var _btn_cy = PH_H - _sb - 130;
PAY_L = 70;            PAY_R = PH_W/2 - 15;
DBL_L = PH_W/2 + 15;   DBL_R = PH_W - 70;
PAY_T = _btn_cy - _bh; PAY_B = _btn_cy + _bh;
DBL_T = _btn_cy - _bh; DBL_B = _btn_cy + _bh;
var _dcy = _btn_cy + _slide;

// "Claim your reward!" + reward amount ("100  🪙") above the CLAIM/DOUBLE buttons.
ph_draw_text(_cx, _btn_cy - 320 + _slide, "Claim your reward!", global.fnt_body_semi, c_black, fa_center, fa_middle);
var _amt_str = string(base_reward);
draw_set_font(global.fnt_num_xl);
var _anw  = string_width(_amt_str);
var _acoin = 130, _agap = 24;
var _agrp = _anw + _agap + _acoin;
var _ax0  = _cx - _agrp/2;
ph_draw_text(_ax0 + _anw/2, _btn_cy - 190 + _slide, _amt_str, global.fnt_num_xl, c_black, fa_center, fa_middle);
draw_sprite_ext(global.spr_gold_coin, 0, _ax0 + _anw + _agap + _acoin/2, _btn_cy - 190 + _slide, _acoin/256, _acoin/256, 0, c_white, 1);
// CLAIM | DOUBLE (rewarded video → doubles the coins) — word labels per the design.
ph_draw_reward_btn(PAY_L, _dcy, PAY_R, _bh, "CLAIM",  noone, false);
ph_draw_reward_btn(DBL_L, _dcy, DBL_R, _bh, "DOUBLE", noone, true);

// ── Confetti (drawn on top of the card) ───────────────────────────────────────
for (var _pi = 0; _pi < array_length(confetti_pieces); _pi++) {
    var _p = confetti_pieces[_pi];
    draw_set_color(_p.col);
    if (_p.shape == 2) {
        draw_circle(_p.x, _p.y, _p.size * 0.45, false);
    } else if (_p.shape == 0) {
        var _cs = dcos(_p.rot); var _sn = dsin(_p.rot);
        var _hw = _p.size * 0.5; var _hh = _p.size * 0.28;
        var _x1 = _p.x + (-_hw)*_cs - (-_hh)*_sn; var _y1 = _p.y + (-_hw)*_sn + (-_hh)*_cs;
        var _x2 = _p.x + ( _hw)*_cs - (-_hh)*_sn; var _y2 = _p.y + ( _hw)*_sn + (-_hh)*_cs;
        var _x3 = _p.x + ( _hw)*_cs - ( _hh)*_sn; var _y3 = _p.y + ( _hw)*_sn + ( _hh)*_cs;
        var _x4 = _p.x + (-_hw)*_cs - ( _hh)*_sn; var _y4 = _p.y + (-_hw)*_sn + ( _hh)*_cs;
        draw_triangle(_x1,_y1, _x2,_y2, _x3,_y3, false);
        draw_triangle(_x1,_y1, _x3,_y3, _x4,_y4, false);
    } else {
        var _r = _p.size * 0.5;
        draw_triangle(
            _p.x + cos(degtorad(_p.rot))*_r,     _p.y + sin(degtorad(_p.rot))*_r,
            _p.x + cos(degtorad(_p.rot+120))*_r, _p.y + sin(degtorad(_p.rot+120))*_r,
            _p.x + cos(degtorad(_p.rot+240))*_r, _p.y + sin(degtorad(_p.rot+240))*_r, false);
    }
}

// ── Placeholder rewarded video (DOUBLE path) — drawn last so it covers all. ────
if (vid_open) {
    ph_video_overlay(video_timer, VIDEO_X_DELAY, PH_COL_PURPLE);
}
