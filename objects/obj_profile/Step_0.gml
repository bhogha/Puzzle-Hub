// Profile input — moved out of Draw_64 so input is read in the conventional Step pass.

// Per-frame timers (must tick regardless of input lock).
if (toast_timer       > 0) toast_timer--;
if (pending_hub_timer > 0) {
    pending_hub_timer--;
    if (pending_hub_timer == 0) {
        global.input_locked_until = current_time + 300;
        room_goto(rm_hub);
        exit;
    }
}

if (current_time < global.input_locked_until) exit;
if (pending_hub_timer >= 0)                   exit;   // freeze input during reset toast
if (!device_mouse_check_button_pressed(0, mb_left)) exit;

var _mx       = device_mouse_x_to_gui(0);
var _my       = device_mouse_y_to_gui(0);
var _nav_top  = PH_H - 190;
var _third    = PH_W / 3;

// ── Easter egg: triple-tap "Level" to wipe progress ──────────────────────────
// Level text is drawn centred at (PH_W/2, 870) with fnt_disp_lg (60pt).
// Tap region is intentionally generous so the user doesn't need pixel-precise
// hits — but kept clear of the XP bar (y=1000+) and profile icon (y=710).
var _lvl_x1 = PH_W/2 - 250, _lvl_y1 = 820;
var _lvl_x2 = PH_W/2 + 250, _lvl_y2 = 920;
if (ph_point_in_rect(_mx,_my, _lvl_x1,_lvl_y1, _lvl_x2,_lvl_y2)) {
    // Reset the counter if too much time elapsed since the last tap.
    if (current_time - level_tap_last > LEVEL_TAP_WINDOW_MS) {
        level_tap_count = 0;
    }
    level_tap_count++;
    level_tap_last = current_time;

    if (level_tap_count >= LEVEL_TAP_REQUIRED) {
        global.save       = ph_save_reset();
        level_tap_count   = 0;
        toast_text        = "PROGRESSION DELETED";
        toast_col         = PH_COL_PINK_DEEP;
        toast_timer       = TOAST_DUR;
        pending_hub_timer = TOAST_DUR;   // navigate to hub when toast ends
    }
    exit;
}

if (ph_point_in_rect(_mx,_my, 0,100,130,220)) {
    global.input_locked_until = current_time + 200;
    room_goto(rm_hub);
} else if (_my > _nav_top) {
    // Tab order: Shop | Games | Profile (current)
    if      (_mx < _third)                    { global.input_locked_until = current_time + 200; room_goto(rm_shop); }
    else if (_mx >= _third && _mx < _third*2) { global.input_locked_until = current_time + 200; room_goto(rm_hub); }
    // right third = Profile (current room) — no-op
}
