// Clean Up: free dynamically allocated resources to prevent memory leaks on game restart.
// (obj_persistent is persistent, so CleanUp_0 fires only on game_restart / game exit —
//  the surface is the only resource that needs explicit freeing; the parsed-puzzles
//  cache is plain struct data and will be reclaimed automatically.)
if (variable_global_exists("ph_dot_surface") && surface_exists(global.ph_dot_surface)) {
    surface_free(global.ph_dot_surface);
}

// Free dynamically loaded sprites
var _sprites = [
    "spr_icon_back", "spr_icon_gear", "spr_icon_shuffle", "spr_icon_hint", "spr_icon_check",
    "spr_icon_lock", "spr_icon_games", "spr_icon_shop", "spr_icon_profile", "spr_icon_star",
    "spr_coin", "spr_hint", "spr_level", "spr_prize_box", "spr_star", "spr_trophy",
    "spr_cal", "spr_chest", "spr_gift", "spr_gold_coin", "spr_heart", "spr_home", "spr_bulb",
    "spr_lock3d", "spr_position", "spr_puzzle", "spr_shop3d", "spr_star3d", "spr_stopwatch",
    "spr_trophy3d", "spr_boxing_glove", "spr_card_yellow", "spr_card_purple", "spr_card_teal",
    "spr_card_orange", "spr_game_anygram", "spr_game_sudoku", "spr_game_wordwave", "spr_game_mixup",
    "spr_tile", "spr_blinky",
    "spr_today_circle", "spr_check_badge", "spr_pb_purple_left", "spr_pb_purple_center",
    "spr_pb_purple_right", "spr_pb_grey_center", "spr_pb_grey_right",
    "spr_cal_day_sel", "spr_cal_day_today",
    "spr_card_silver", "spr_game_arrows", "spr_arrow", "spr_highlight"
];
for (var _i = 0; _i < array_length(_sprites); _i++) {
    var _name = _sprites[_i];
    if (variable_global_exists(_name)) {
        var _spr = global[$ _name];
        if (sprite_exists(_spr)) {
            sprite_delete(_spr);
        }
    }
}

// Free dynamically loaded fonts
var _fonts = [
    "fnt_disp_xxl", "fnt_disp_xl", "fnt_disp_lg", "fnt_disp_md", "fnt_disp_sm", "fnt_disp_xs",
    "fnt_body_lg", "fnt_body_md", "fnt_body_sm", "fnt_body_xs", "fnt_num_md"
];
for (var _i = 0; _i < array_length(_fonts); _i++) {
    var _name = _fonts[_i];
    if (variable_global_exists(_name)) {
        var _fnt = global[$ _name];
        if (font_exists(_fnt)) {
            font_delete(_fnt);
        }
    }
}
