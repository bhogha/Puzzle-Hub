// ── Profile — Draw GUI ────────────────────────────────────────────────────────
// Input handled in Step_0.

// Background
draw_set_color(PH_COL_BG);
draw_rectangle(0,0,PH_W,PH_H,false);

ph_draw_icon(global.spr_icon_back, 65, 165, 0.6, PH_COL_DARK);
ph_draw_text(PH_W/2, 165, "PROFILE", global.fnt_disp_md, PH_COL_DARK, fa_center, fa_middle);

// Stats card
ph_draw_chip(80,580, PH_W-80,1200, 40, PH_COL_WHITE, make_color_rgb(190,170,155), 12);

// Profile icon
draw_set_color(PH_COL_PURPLE);
draw_circle(PH_W/2, 710, 80, false);
ph_draw_icon(global.spr_icon_profile, PH_W/2, 710, 0.9, c_white);

// Stats
var _save  = global.save;
var _level = ph_level_from_xp(_save.xp);
var _xp_in = ph_xp_in_level(_save.xp);
ph_draw_text(PH_W/2, 870,  "Level " + string(_level), global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
ph_draw_text(PH_W/2, 960,  string(_xp_in) + "/" + string(PH_XP_PER_LEVEL) + " XP",
             global.fnt_body_md, PH_COL_GRAY, fa_center, fa_middle);
ph_draw_rounded(140,1000, PH_W-140,1036, 18, make_color_rgb(220,210,205));
ph_draw_rounded(140,1000, 140+floor((PH_W-280)*(_xp_in/PH_XP_PER_LEVEL)),1036, 18, PH_COL_PURPLE);
ph_draw_text(PH_W/2, 1080, string(_save.coins) + " coins", global.fnt_body_md, PH_COL_GOLD, fa_center, fa_middle);
ph_draw_text(PH_W/2, 1140, "COMING SOON", global.fnt_body_xs, PH_COL_GRAY, fa_center, fa_middle);

// Nav  (Profile remains the rightmost tab)
ph_draw_nav(2);

// ── Toast (reset confirmation for the triple-tap easter egg) ─────────────────
if (toast_timer > 0) {
    var _alpha = min(1, toast_timer/15);
    draw_set_alpha(_alpha);
    ph_draw_chip(PH_W/2-360,440-44, PH_W/2+360,440+44, 26,
                 toast_col, make_color_rgb(20,20,20), 5);
    ph_draw_text(PH_W/2, 440, toast_text, global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);
    draw_set_alpha(1);
}
