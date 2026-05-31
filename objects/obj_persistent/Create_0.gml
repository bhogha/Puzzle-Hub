// Persistent manager — lives for the entire session

// ── Dynamic canvas height (must be set before any PH_H reference) ─────────────
// PH_W is fixed at 1080. PH_H (= global.PH_H_dyn) is the canvas height.
//
// On mobile we derive it from the real screen ratio so the app surface fills
// the device edge-to-edge without letterboxing (needs "Allow Unsafe Areas" on
// iOS). On DESKTOP, display_get_*() returns the whole monitor — which is
// landscape — so the old ratio math produced a tiny height (e.g. 675) and the
// 1080×height surface got stretched into the tall window, squashing everything
// into a centre strip. Desktop therefore uses the designed portrait height
// (1920, matching the room); "Keep aspect ratio" then letterboxes cleanly.
if (os_type == os_ios || os_type == os_android) {
    global.PH_H_dyn = round(display_get_height() / max(display_get_width(), 1) * PH_W);
} else {
    global.PH_H_dyn = 1920;
}

// ── iOS safe area insets (notch / Dynamic Island / home indicator) ─────────────
// Stored in GUI units so every screen can offset its top/bottom elements.
global.safe_top_gui    = 0;
global.safe_bottom_gui = 0;
if (os_type == os_ios) {
    var _info = os_get_info();
    var _raw_top    = ds_map_find_value(_info, "ios_safe_area_top");
    var _raw_bottom = ds_map_find_value(_info, "ios_safe_area_bottom");
    if (!is_undefined(_raw_top))    global.safe_top_gui    = round(_raw_top    * global.PH_H_dyn / display_get_height());
    if (!is_undefined(_raw_bottom)) global.safe_bottom_gui = round(_raw_bottom * global.PH_H_dyn / display_get_height());
    ds_map_destroy(_info);
}

ph_load_fonts();
global.save              = ph_save_load();
global.selected_date_key = ph_today_key();
global.input_locked_until = 0;

application_surface_draw_enable(true);
surface_resize(application_surface, PH_W, global.PH_H_dyn);
display_set_gui_size(PH_W, global.PH_H_dyn);
// 4× MSAA smooths every primitive edge (rounded-chip corners, swipe lines,
// halos). 64-segment circles keep larger arcs from looking faceted even
// when MSAA isn't available (rare, but possible on some older GPUs).
display_reset(4, true);
draw_set_circle_precision(64);
// Bilinear texture sampling — fonts (font_add produces anti-aliased glyph
// atlases that look crisp/jaggy without this) and the heavily-downscaled
// icon sprites (50/512, 64/512…) both come out noticeably softer.
gpu_set_texfilter(true);

// Load icon sprites from datafiles (white strokes — tint at draw time, 256×256, origin centred)
var _d = working_directory + "icons/";
global.spr_icon_back    = sprite_add(_d + "spr_icon_back.png",    1, false, true, 128, 128);
global.spr_icon_gear    = sprite_add(_d + "spr_icon_gear.png",    1, false, true, 128, 128);
global.spr_icon_shuffle = sprite_add(_d + "spr_icon_shuffle.png", 1, false, true, 128, 128);
global.spr_icon_hint    = sprite_add(_d + "spr_icon_hint.png",    1, false, true, 128, 128);
global.spr_icon_check   = sprite_add(_d + "spr_icon_check.png",   1, false, true, 128, 128);
global.spr_icon_lock    = sprite_add(_d + "spr_icon_lock.png",    1, false, true, 128, 128);
global.spr_icon_games   = sprite_add(_d + "spr_icon_games.png",   1, false, true, 128, 128);
global.spr_icon_shop    = sprite_add(_d + "spr_icon_shop.png",    1, false, true, 128, 128);
global.spr_icon_profile = sprite_add(_d + "spr_icon_profile.png", 1, false, true, 128, 128);
global.spr_icon_star    = sprite_add(_d + "spr_icon_star.png",    1, false, true, 128, 128);

// Full-colour UI icons (512×512, origin centred at 256×256)
global.spr_coin      = sprite_add(_d + "coin.png",      1, false, false, 256, 256);
global.spr_hint      = sprite_add(_d + "hint.png",      1, false, false, 256, 256);
global.spr_level     = sprite_add(_d + "level.png",     1, false, false, 256, 256);
global.spr_prize_box = sprite_add(_d + "prize_box.png", 1, false, false, 256, 256);
global.spr_star      = sprite_add(_d + "star.png",      1, false, false, 256, 256);
global.spr_trophy    = sprite_add(_d + "trophy.png",    1, false, false, 256, 281); // 512×563 → centre

// ── 3D Hub Icons (512×512, origin centred) ────────────────────────────────────
global.spr_cal          = sprite_add(_d + "icon_calendar.png",     1, false, false, 256, 256);
global.spr_chest        = sprite_add(_d + "icon_chest.png",        1, false, false, 256, 256);
global.spr_gift         = sprite_add(_d + "icon_gift.png",         1, false, false, 256, 256);
global.spr_gold_coin    = sprite_add(_d + "icon_gold_coin.png",    1, false, false, 256, 256);
global.spr_heart        = sprite_add(_d + "icon_heart.png",        1, false, false, 256, 256);
global.spr_home         = sprite_add(_d + "icon_home.png",         1, false, false, 256, 256);
global.spr_bulb         = sprite_add(_d + "icon_bulb.png",         1, false, false, 256, 256);
global.spr_lock3d       = sprite_add(_d + "icon_lock3d.png",       1, false, false, 256, 256);
global.spr_position     = sprite_add(_d + "icon_position.png",     1, false, false, 256, 256);
global.spr_puzzle       = sprite_add(_d + "icon_puzzle.png",       1, false, false, 256, 256);
global.spr_shop3d       = sprite_add(_d + "icon_shop3d.png",       1, false, false, 256, 256);
global.spr_star3d       = sprite_add(_d + "icon_star3d.png",       1, false, false, 256, 256);
global.spr_stopwatch    = sprite_add(_d + "icon_stopwatch.png",    1, false, false, 256, 256);
global.spr_trophy3d     = sprite_add(_d + "icon_trophy3d.png",     1, false, false, 256, 256);
global.spr_boxing_glove = sprite_add(_d + "icon_boxing_glove.png", 1, false, false, 256, 256);

// ── Game card backgrounds (1400×400, origin centred) ──────────────────────────
global.spr_card_yellow = sprite_add(_d + "card_yellow.png", 1, false, false, 700, 200);
global.spr_card_purple = sprite_add(_d + "card_purple.png", 1, false, false, 700, 200);
global.spr_card_teal   = sprite_add(_d + "card_teal.png",   1, false, false, 700, 200);
global.spr_card_orange = sprite_add(_d + "card_orange.png", 1, false, false, 700, 200);

// ── Game icons (512×512, origin centred) ──────────────────────────────────────
global.spr_game_anygram  = sprite_add(_d + "game_anygram.png",  1, false, false, 256, 256);
global.spr_game_sudoku   = sprite_add(_d + "game_sudoku.png",   1, false, false, 256, 256);
global.spr_game_wordwave = sprite_add(_d + "game_wordwave.png", 1, false, false, 256, 256);
global.spr_game_mixup    = sprite_add(_d + "game_mixup.png",    1, false, false, 256, 256);

// ── Anygram tile (256×256, origin centred) ────────────────────────────────────
global.spr_tile = sprite_add(_d + "tile_empty.png", 1, false, false, 128, 128);

// ── Characters (origin centred) ───────────────────────────────────────────────
global.spr_blinky = sprite_add(_d + "char_blinky.png", 1, false, false, 332, 350);
