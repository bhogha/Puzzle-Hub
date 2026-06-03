// ── Level-Up reward screen — Draw GUI ─────────────────────────────────────────
if (!valid) exit;

// Purple celebratory backdrop (matches the level/star/XP accent).
draw_set_color(PH_COL_PURPLE);
draw_rectangle(0, 0, PH_W, PH_H, false);

// White card slides up from the bottom.
var _card_top = 360;
var _card_h   = 1040;
var _card_y   = lerp(PH_H, _card_top, ph_ease_back(min(anim_t * 1.2, 1)));
var _slide    = _card_y - _card_top;        // 0 once settled
ph_draw_chip(60, _card_y, PH_W - 60, _card_y + _card_h, 40, PH_COL_WHITE, make_color_rgb(80, 40, 160), 12);

var _cx = PH_W / 2;
var _y  = _card_top + 110 + _slide;

// Star icon.
draw_sprite_ext(global.spr_star3d, 0, _cx, _y, 0.55, 0.55, 0, c_white, 1);
_y += 200;

// "LEVEL UP!"
ph_draw_text(_cx, _y, "LEVEL UP!", global.fnt_disp_xl, PH_COL_PINK, fa_center, fa_middle);
_y += 110;

// Level badge.
ph_draw_chip(_cx - 190, _y - 46, _cx + 190, _y + 46, 46, PH_COL_PURPLE, make_color_rgb(80, 30, 180), 6);
ph_draw_text(_cx, _y, "LEVEL " + string(level), global.fnt_disp_sm, PH_COL_WHITE, fa_center, fa_middle);
_y += 130;

// Reward prompt.
ph_draw_text(_cx, _y, "Claim your reward!", global.fnt_body_md, PH_COL_INK_SOFT, fa_center, fa_middle);

// ── Reward buttons ────────────────────────────────────────────────────────────
// Settled bounds are written to PAY_*/DBL_* (read by Step); the slide offset is
// applied to drawing only so taps match the resting layout even mid-animation.
var _btn_cy = _card_top + _card_h - 160;
var _bh     = 70;
var _gap    = 30;
PAY_L = 70;              PAY_R = PH_W/2 - _gap/2;
DBL_L = PH_W/2 + _gap/2; DBL_R = PH_W - 70;
PAY_T = _btn_cy - _bh;   PAY_B = _btn_cy + _bh;
DBL_T = _btn_cy - _bh;   DBL_B = _btn_cy + _bh;
var _dcy = _btn_cy + _slide;

// Take base coins: "100" + gold coin.
ph_draw_chip(PAY_L, _dcy - _bh, PAY_R, _dcy + _bh, _bh, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
ph_draw_text(PAY_L + 110, _dcy, string(base_reward), global.fnt_disp_md, PH_COL_DARK, fa_center, fa_middle);
draw_sprite_ext(global.spr_gold_coin, 0, PAY_R - 70, _dcy, 150/512, 150/512, 0, c_white, 1);

// Double via video: "DOUBLE" + retro TV.
ph_draw_chip(DBL_L, _dcy - _bh, DBL_R, _dcy + _bh, _bh, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
ph_draw_text(DBL_L + 130, _dcy, "DOUBLE", global.fnt_disp_sm, PH_COL_DARK, fa_center, fa_middle);
draw_sprite_ext(global.spr_tv, 0, DBL_R - 72, _dcy, 150/512, 150/512, 0, c_white, 1);

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
