// ── Level-Up reward screen — Step ─────────────────────────────────────────────
if (!valid) exit;

// Card slide-in
if (anim_t < 1) anim_t = min(1, anim_t + 0.04);

// Placeholder-video timer (DOUBLE path)
if (vid_open) video_timer++;

// One-shot confetti burst: gravity + drag, cull below the screen (no respawn).
for (var _pi = array_length(confetti_pieces) - 1; _pi >= 0; _pi--) {
    var _p = confetti_pieces[_pi];
    _p.vy  += 0.35;
    _p.vx  *= 0.985;
    _p.x   += _p.vx;
    _p.y   += _p.vy;
    _p.rot += _p.vrot;
    if (_p.y > PH_H + 60) array_delete(confetti_pieces, _pi, 1);
    else confetti_pieces[_pi] = _p;
}

// ── Input ─────────────────────────────────────────────────────────────────────
if (!device_mouse_check_button_pressed(0, mb_left)) exit;
var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Placeholder video open — the close X (after 5s) grants the DOUBLED reward.
if (vid_open) {
    if (video_timer >= VIDEO_X_DELAY
        && ph_point_in_circle(_mx, _my, PH_W - 90, 90 + global.safe_top_gui, 46 + 14)) {
        lu_claim(base_reward * 2);
    }
    exit;
}

// Reward buttons.
if (ph_point_in_rect(_mx, _my, PAY_L, PAY_T, PAY_R, PAY_B)) {
    lu_claim(base_reward);                 // take the base coins
    exit;
}
if (ph_point_in_rect(_mx, _my, DBL_L, DBL_T, DBL_R, DBL_B)) {
    vid_open    = true;                     // DOUBLE → watch the placeholder video
    video_timer = 0;
    exit;
}
