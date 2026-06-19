// ── Screen-transition overlay (iris cover → reveal) ───────────────────────────
// Drawn on top of every room (this object has a very low depth). Cover: an accent
// circle ACCELERATES out from the tap point until it fills the screen. Reveal: the
// cover irises back to a point (edges reveal first), DECELERATING. A quick additive
// white spark at the origin punctuates the tap ("click" pop).
if (!global.trans_active) exit;

var _rmax = ph_trans_radius_max(global.trans_ox, global.trans_oy);
var _r;
if (global.trans_phase == 1) {
    _r = _rmax * ph_ease_in(global.trans_t / global.TRANS_COVER_FR);
} else {
    _r = _rmax * (1 - ph_ease_out(global.trans_t / global.TRANS_REVEAL_FR));
}

draw_set_color(global.trans_col);
draw_circle(global.trans_ox, global.trans_oy, _r, false);

// Click spark — a quick additive white flash at the tap origin as the cover launches.
if (global.trans_phase == 1 && global.trans_t < 6) {
    var _sp = 1 - global.trans_t/6;                 // 1 → 0
    gpu_set_blendmode(bm_add);
    draw_set_color(c_white);
    draw_set_alpha(_sp * 0.65);
    draw_circle(global.trans_ox, global.trans_oy, PH_W*0.05 + (1-_sp)*PH_W*0.14, false);
    draw_set_alpha(1);
    gpu_set_blendmode(bm_normal);
}
