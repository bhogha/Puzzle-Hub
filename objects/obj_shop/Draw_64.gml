// ── Shop — Draw GUI ───────────────────────────────────────────────────────────
// Input handled in Step_0.

// Background
draw_set_color(PH_COL_BG);
draw_rectangle(0,0,PH_W,PH_H,false);

ph_draw_icon(global.spr_icon_back, 65, 165, 0.6, PH_COL_DARK);
ph_draw_text(PH_W/2, 165, "SHOP", global.fnt_disp_md, PH_COL_DARK, fa_center, fa_middle);

// Coming Soon card
ph_draw_chip(80,600, PH_W-80,1200, 40, PH_COL_WHITE, make_color_rgb(190,170,155), 12);

// Shopping bag icon
draw_set_color(PH_COL_TEAL);
draw_circle(PH_W/2, 820, 80, false);
ph_draw_icon(global.spr_icon_shop, PH_W/2, 820, 0.9, c_white);

ph_draw_text(PH_W/2, 980,  "COMING SOON", global.fnt_disp_lg,  PH_COL_PINK, fa_center, fa_middle);
ph_draw_text(PH_W/2, 1070, "Coins, hints & cosmetics", global.fnt_body_sm, PH_COL_GRAY, fa_center, fa_middle);
ph_draw_text(PH_W/2, 1120, "coming in a future update.", global.fnt_body_sm, PH_COL_GRAY, fa_center, fa_middle);

// Nav  (Shop is now the leftmost tab)
ph_draw_nav(0);
