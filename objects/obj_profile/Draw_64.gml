// ── Profile — Draw GUI (Missions screen) ──────────────────────────────────────
// Input handled in Step_0. Layout from prof_metrics(); geometry constants in Create.

var _save  = global.save;
var _level = ph_level_from_xp(_save.xp);
var _coins = _save.coins;
var M      = prof_metrics();

// Palette (local)
var _mint     = make_color_rgb(141,232,213);
var _mint_sh  = make_color_rgb(108,198,180);
var _cream    = make_color_rgb(255,249,244);
var _card_sh  = make_color_rgb(224,213,204);
var _track    = make_color_rgb(223,214,225);
var _divider  = make_color_rgb(214,206,219);
var _rew_col  = make_color_rgb(120,108,122);
var _claim_bg   = make_color_rgb(238,231,224);   // muted card for claimed
var _claim_ink  = make_color_rgb(170,160,172);
var _claim_rew  = make_color_rgb(186,177,190);

// Background
draw_set_color(PH_COL_BG);
draw_rectangle(0, 0, PH_W, PH_H, false);

// ═══ Top bar: level pill · PROFILE · coin pill ═══════════════════════════════
var _cy = M.topbar_cy;
ph_draw_chip(70, _cy-34, 270, _cy+34, 34, PH_COL_WHITE, PH_COL_TILE_DARK, 5);
// Level star — pulses as claimed stars land on it.
var _ls = 110/512;
if (starfly_active) {
    var _pp = starfly_t / STARFLY_DUR;
    if (_pp > 0.55) _ls *= 1 + 0.22 * sin((_pp - 0.55) / 0.45 * pi);
}
draw_sprite_ext(global.spr_star3d, 0, 82, _cy, _ls, _ls, 0, c_white, 1);
ph_draw_text((127 + 270)/2, _cy, string(_level), global.fnt_num_md, PH_COL_DARK, fa_center, fa_middle);
ph_draw_text(PH_W/2, _cy, "PROFILE", global.fnt_disp_md, PH_COL_PINK, fa_center, fa_middle);
var _px2 = PH_W - 24, _px1 = _px2 - 310;
ph_draw_chip(_px1, _cy-34, _px2, _cy+34, 34, PH_COL_WHITE, PH_COL_TILE_DARK, 5);
draw_sprite_ext(global.spr_gold_coin, 0, _px1+12, _cy, 110/512, 110/512, 0, c_white, 1);
var _plus_cx = _px2 - 36;
ph_draw_chip(_plus_cx-24, _cy-24, _plus_cx+24, _cy+24, 24, PH_COL_PINK, PH_COL_PINK_DEEP, 4);
ph_draw_text(_plus_cx, _cy-2, "+", global.fnt_disp_xs, PH_COL_WHITE, fa_center, fa_middle);
ph_draw_text(_plus_cx-32, _cy, ph_format_int_thousands(_coins), global.fnt_num_md, PH_COL_DARK, fa_right, fa_middle);

// ═══ Identity card (mint) — avatar + name (no "playing since" line) ══════════
ph_draw_chip(50, M.id_top, PH_W-50, M.id_top + M.id_h, 48, _mint, _mint_sh, 8);
var _av_cx = 230, _av_cy = M.id_top + M.id_h/2;
draw_set_color(PH_COL_WHITE);
draw_circle(_av_cx, _av_cy, 112, false);
var _bw = sprite_get_width(global.spr_blinky);
draw_sprite_ext(global.spr_blinky, 0, _av_cx, _av_cy, 185/_bw, 185/_bw, 0, c_white, 1);
ph_draw_text(_av_cx+165, _av_cy, "Player", global.fnt_disp_lg, PH_COL_DARK, fa_left, fa_middle);

// ═══ Missions panel (mint) + header ══════════════════════════════════════════
var _pan_top = M.hdr_y - 46;
ph_draw_chip(40, _pan_top, PH_W-40, M.list_bot + 8, 48, _mint, _mint_sh, 8);
ph_draw_text(80, M.hdr_y, "MISSIONS", global.fnt_disp_lg, PH_COL_DARK, fa_left, fa_middle);
var _days = ph_week_days_left(_save);
var _rt   = "Reset in " + string(_days) + ((_days == 1) ? " Day" : " Days");
draw_set_font(global.fnt_body_md);
var _rp_r = PH_W - 80, _rp_l = _rp_r - (string_width(_rt) + 80);
ph_draw_chip(_rp_l, M.hdr_y-38, _rp_r, M.hdr_y+38, 38, PH_COL_WHITE, PH_COL_TILE_DARK, 4);
ph_draw_text((_rp_l+_rp_r)/2, M.hdr_y, _rt, global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);

// ═══ Finished week → minimal COLLECT placeholder (Phase 4 replaces this) ══════
if (_save.week.status == "finished") {
    var _mid = (M.list_top + M.list_bot)/2;
    ph_draw_text(PH_W/2, _mid-130, "WEEK COMPLETE!", global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
    ph_draw_text(PH_W/2, _mid-50,  "Collect your rewards", global.fnt_body_md, PH_COL_INK_SOFT, fa_center, fa_middle);
    ph_draw_reward_btn(PH_W/2-220, _mid+70, PH_W/2+220, 60, "COLLECT", noone, false);
} else {
    // ═══ Scrollable mission list (sorted: claimable → in-progress → claimed) ══
    var _ms    = _save.week.missions;
    var _order = prof_sorted_indices();
    ph_scissor_gui(40, M.list_top, PH_W-80, M.list_bot - M.list_top);
    for (var _p = 0; _p < array_length(_order); _p++) {
        var _t = prof_card_top(_p, M.list_top);
        if (_t > M.list_bot || _t + CARD_H < M.list_top) continue;   // cull off-screen
        var _m    = _ms[_order[_p]];
        var _val  = ph_mission_value(_save, _m);
        var _comp = (_val >= _m.target);
        var _title = ph_mission_title(_m);
        var _icy  = _t + CARD_H/2;

        // Card body + icon tile + divider
        var _bg = (_m.claimed) ? _claim_bg : _cream;
        ph_draw_chip(CARD_L, _t, CARD_R, _t+CARD_H, 36, _bg, _card_sh, 6);
        ph_draw_rounded(CARD_L+30, _icy-82, CARD_L+30+164, _icy+82, 28, PH_COL_WHITE);
        draw_sprite_ext(prof_icon(_m.icon), 0, CARD_L+30+82, _icy, 140/512, 140/512, 0, c_white, 1);
        draw_set_color(_divider);
        draw_line_width(DIVIDER_X, _t+34, DIVIDER_X, _t+CARD_H-34, 3);

        if (_m.claimed) {
            // Claimed — faded title, reward ★ REMAINS, small check in the corner.
            draw_set_font(global.fnt_body_sm); draw_set_halign(fa_left); draw_set_valign(fa_middle);
            draw_set_color(_claim_ink);
            draw_text_ext(MAIN_X1, _icy, _title, 34, MAIN_X2 - MAIN_X1);
            draw_sprite_ext(global.spr_star3d, 0, REW_CX+44, _icy, 92/512, 92/512, 0, c_white, 1);
            ph_draw_text(REW_CX+6, _icy, string(_m.reward), global.fnt_num_reg, _claim_rew, fa_right, fa_middle);
            draw_sprite_ext(global.spr_check_badge, 0, CARD_R-48, _t+46, 64/512, 64/512, 0, c_white, 1);
        } else if (_comp) {
            // Claimable — CLAIM button (top) + title (below) + reward ★.
            var _cr = prof_claim_rect(_t);
            ph_draw_reward_btn(_cr.l, _cr.cy, _cr.r, _cr.bh, "CLAIM", noone, false);
            draw_set_font(global.fnt_body_sm); draw_set_halign(fa_left); draw_set_valign(fa_top);
            draw_set_color(PH_COL_DARK);
            draw_text_ext(MAIN_X1, _t+150, _title, 34, MAIN_X2 - MAIN_X1);
            draw_sprite_ext(global.spr_star3d, 0, REW_CX+44, _icy, 92/512, 92/512, 0, c_white, 1);
            ph_draw_text(REW_CX+6, _icy, string(_m.reward), global.fnt_num_reg, _rew_col, fa_right, fa_middle);
        } else {
            // In progress — title (top), progress bar, count to the RIGHT of the bar.
            draw_set_font(global.fnt_body_sm); draw_set_halign(fa_left); draw_set_valign(fa_top);
            draw_set_color(PH_COL_DARK);
            draw_text_ext(MAIN_X1, _t+52, _title, 34, MAIN_X2 - MAIN_X1);
            var _bcy = _t + CARD_H - 60, _bh = 36;
            var _bx2 = MAIN_X2 - 130;                       // leave room for the count
            ph_draw_rounded(MAIN_X1, _bcy-_bh/2, _bx2, _bcy+_bh/2, _bh/2, _track);
            var _fillw = (_bx2-MAIN_X1) * clamp(_val/_m.target, 0, 1);
            if (_fillw > _bh) ph_draw_rounded(MAIN_X1, _bcy-_bh/2, MAIN_X1+_fillw, _bcy+_bh/2, _bh/2, PH_COL_PURPLE);
            ph_draw_text(MAIN_X2, _bcy, string(_val) + " / " + string(_m.target),
                         global.fnt_body_sm, _rew_col, fa_right, fa_middle);
            draw_sprite_ext(global.spr_star3d, 0, REW_CX+44, _icy, 92/512, 92/512, 0, c_white, 1);
            ph_draw_text(REW_CX+6, _icy, string(_m.reward), global.fnt_num_reg, _rew_col, fa_right, fa_middle);
        }
    }
    ph_scissor_reset();
}

// ═══ Nav (Profile = rightmost tab; badge handled inside ph_draw_nav) ═════════
ph_draw_nav(2);

// ═══ Claim star-fly: stars rise from the tile reward ★ to the level ★ ════════
if (starfly_active) {
    var _tx = 82, _ty = M.topbar_cy;
    var _p2 = starfly_t / STARFLY_DUR;
    for (var _s = 0; _s < STARFLY_N; _s++) {
        var _d  = _s * 0.07;
        var _lp = clamp((_p2 - _d) / 0.65, 0, 1);
        if (_lp <= 0 || _lp >= 1) continue;
        var _e  = ph_ease_out(_lp);
        var _x  = lerp(starfly_src_x, _tx, _e);
        var _y  = lerp(starfly_src_y, _ty, _e) - sin(_lp*pi) * 90;   // arc
        var _sc = lerp(72, 34, _lp) / 512;
        draw_sprite_ext(global.spr_star3d, 0, _x, _y, _sc, _sc, 0, c_white, 1);
    }
}

// ═══ Toast (reset feedback) ══════════════════════════════════════════════════
if (toast_timer > 0) {
    var _alpha = min(1, toast_timer/15);
    draw_set_alpha(_alpha);
    ph_draw_chip(PH_W/2-360, M.topbar_cy+200-44, PH_W/2+360, M.topbar_cy+200+44, 26,
                 toast_col, make_color_rgb(20,20,20), 5);
    ph_draw_text(PH_W/2, M.topbar_cy+200, toast_text, global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);
    draw_set_alpha(1);
}
