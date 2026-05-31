// Shop input — moved out of Draw_64 so input is read in the conventional Step pass.
if (current_time < global.input_locked_until) exit;
if (!device_mouse_check_button_pressed(0, mb_left)) exit;

var _mx       = device_mouse_x_to_gui(0);
var _my       = device_mouse_y_to_gui(0);
var _nav_top  = PH_H - 190;
var _third    = PH_W / 3;

if (ph_point_in_rect(_mx,_my, 0,100,130,220)) {
    global.input_locked_until = current_time + 200;
    room_goto(rm_hub);
} else if (_my > _nav_top) {
    // Tab order: Shop (current) | Games | Profile
    if      (_mx >= _third && _mx < _third*2) { global.input_locked_until = current_time + 200; room_goto(rm_hub); }
    else if (_mx >= _third*2)                 { global.input_locked_until = current_time + 200; room_goto(rm_profile); }
    // left third = Shop (current room) — no-op
}
