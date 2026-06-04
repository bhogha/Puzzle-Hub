// ── obj_wordle — Draw GUI ─────────────────────────────────────────────────────
// Phase 0 scaffold: background + HUD only, so the room renders and is navigable.
// The 6×6 grid, custom keyboard, hint, win/loss flow are built in Phases 2–5.

// Background
draw_set_color(PH_COL_BG);
draw_rectangle(0, 0, PH_W, PH_H, false);
ph_draw_dot_bg(PH_COL_BG);

// HUD: back arrow (left) + green WORDLE title (centred)
ph_draw_icon(global.spr_icon_back, 65, 165, 0.6, PH_COL_DARK);
ph_draw_text(PH_W/2, 165, "WORDLE", global.fnt_disp_md, PH_COL_GREEN, fa_center, fa_middle);

// Phase 0 placeholder note
ph_draw_text(PH_W/2, PH_H/2 - 40, "WORDLE", global.fnt_disp_lg, PH_COL_GREEN, fa_center, fa_middle);
ph_draw_text(PH_W/2, PH_H/2 + 60, "Coming together — Phase 0 scaffold", global.fnt_body_sm, PH_COL_GRAY, fa_center, fa_middle);
