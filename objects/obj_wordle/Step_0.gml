// ── obj_wordle — Step ─────────────────────────────────────────────────────────
// Phase 0 scaffold: only the back button is wired so the screen is navigable.
if (current_time < global.input_locked_until) exit;
if (!device_mouse_check_button_pressed(0, mb_left)) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Back arrow (top-left) -> hub
if (ph_point_in_rect(_mx, _my, 0, 100, 160, 240)) {
    global.input_locked_until = current_time + 200;
    room_goto(rm_hub);
}
