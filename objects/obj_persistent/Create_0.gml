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
//
// IMPORTANT: GameMaker has no reliably-documented GML call that returns the iOS
// safe-area insets — os_get_info() does NOT expose them (the earlier
// "ios_safe_area_*" keys were never populated, so these globals stayed 0 and the
// UI sat under the Dynamic Island). We therefore:
//   1) still probe os_get_info() defensively, in case a runtime ever provides it;
//   2) otherwise estimate from the screen aspect for full-screen notch / Dynamic
//      Island iPhones — calibrated to Apple's portrait insets (matches an
//      iPhone 16 Pro within a few px).
// For pixel-perfect values on every device, install the "iOS Safe Area" native
// extension and assign its top/bottom (in px) into these two globals instead
// (convert with  round(px * global.PH_H_dyn / display_get_height())  as below).
global.safe_top_gui    = 0;
global.safe_bottom_gui = 0;
global.safe_src        = "desktop";   // which path set the insets: "extension" / "estimate" / "none" / "desktop" (debug readout)
global.safe_raw_top    = -1;          // raw px from the extension (-1 = extension gave nothing)
global.safe_raw_bottom = -1;
if (os_type == os_ios) {
    var _dh = max(display_get_height(), 1);
    global.safe_src = "none";

    // 1) "iOS Safe Area" native extension (Liquid Games) — true per-device insets.
    //    iOS_get_safe_area() returns a JSON string → json_decode → ds_map with
    //    detected/top/bottom/left/right (px). Convert px → GUI units. NOTE: this
    //    requires the extension to be imported into the project, otherwise the
    //    project will not compile (remove this block to fall back to the estimate).
    var _json = iOS_get_safe_area();
    if (is_string(_json) && _json != "") {
        var _m = json_decode(_json);
        if (ds_exists(_m, ds_type_map)) {
            if (ds_map_find_value(_m, "detected")) {
                var _t = ds_map_find_value(_m, "top");
                var _b = ds_map_find_value(_m, "bottom");
                if (is_real(_t)) global.safe_raw_top    = _t;
                if (is_real(_b)) global.safe_raw_bottom = _b;
                if (is_real(_t) && _t > 0) { global.safe_top_gui    = round(_t * global.PH_H_dyn / _dh); global.safe_src = "extension"; }
                if (is_real(_b) && _b > 0) { global.safe_bottom_gui = round(_b * global.PH_H_dyn / _dh); global.safe_src = "extension"; }
            }
            ds_map_destroy(_m);
        }
    }

    // 2) Aspect-ratio fallback if the extension reported nothing (e.g. not yet
    //    imported, or pre-iOS 11). Tall screens (height/width >= 2.0) are the
    //    only iOS devices with a top cutout + home indicator; SE/8/iPad get none.
    var _ratio = _dh / max(display_get_width(), 1);
    if (_ratio >= 2.0) {
        if (global.safe_top_gui    <= 0) { global.safe_top_gui    = round(global.PH_H_dyn * 0.075); if (global.safe_src != "extension") global.safe_src = "estimate"; } // ~Dynamic Island / notch
        if (global.safe_bottom_gui <= 0) { global.safe_bottom_gui = round(global.PH_H_dyn * 0.042); if (global.safe_src != "extension") global.safe_src = "estimate"; } // ~home indicator
    }
}
show_debug_message("[safe-area] src=" + global.safe_src
    + " top_gui=" + string(global.safe_top_gui) + " bottom_gui=" + string(global.safe_bottom_gui)
    + " raw_top_px=" + string(global.safe_raw_top) + " raw_bottom_px=" + string(global.safe_raw_bottom));

ph_load_fonts();
global.save              = ph_save_load();
// Count this app launch (once per session — obj_persistent lives the whole run).
// Gates the Daily Spin: it appears from the PH_SPIN_UNLOCK_SESSION-th session on.
global.save.session_count += 1;
ph_save_write(global.save);
global.selected_date_key = ph_today_key();
global.input_locked_until = 0;
// Re-arm the daily puzzle reminder if the player already opted in (iOS only).
ph_notify_boot();
// Queued level-up reward (set at puzzle completion, consumed by the Level-Up
// screen in rm_win). { level, base_reward } when pending; undefined otherwise.
global.pending_levelup   = undefined;
// Coins awarded on the last Level-Up claim, waiting to be celebrated by the hub
// coin-flow animation. 0 = nothing to play. Set by obj_win.lu_claim, consumed
// (reset to 0) by obj_hub.Create_0.
global.coin_flow_amount  = 0;
// Destination queued when the player triggers a win-screen shortcut (NEXT GAME /
// YESTERDAY) while a level-up is pending: { kind:"room", room, date }. The Level-Up
// screen (obj_win.lu_claim) consumes it and continues there instead of the hub.
global.post_levelup      = undefined;

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
var _d = PH_ASSETS_PATH + "icons/";
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

// ── Game card backgrounds (1430×450, origin centred → 715,225) ────────────────
global.spr_card_yellow = sprite_add(_d + "card_yellow.png", 1, false, false, 715, 225);
global.spr_card_purple = sprite_add(_d + "card_purple.png", 1, false, false, 715, 225);
global.spr_card_teal   = sprite_add(_d + "card_teal.png",   1, false, false, 715, 225);
global.spr_card_orange = sprite_add(_d + "card_orange.png", 1, false, false, 715, 225);
global.spr_card_blue   = sprite_add(_d + "card_blue.png",   1, false, false, 715, 225);
global.spr_card_green  = sprite_add(_d + "card_green.png",  1, false, false, 715, 225);
global.spr_card_skyblue = sprite_add(_d + "card_skyblue.png", 1, false, false, 715, 225);   // Hue Sort (#6ea5e6)
global.spr_card_lime    = sprite_add(_d + "card_lime.png",    1, false, false, 715, 225);   // Color Link (#c7e70f)
global.spr_card_tangerine = sprite_add(_d + "card_tangerine.png", 1, false, false, 715, 225); // Word Bend (#ff5b38)
global.spr_card_silver    = sprite_add(_d + "card_silver.png",    1, false, false, 715, 225);   // Arrows (#b8b9bd, 1430×450)
global.spr_card_brightteal = sprite_add(_d + "card_brightteal.png", 1, false, false, 715, 225); // Colordoku (#5af2bc)

// ── Event Hub mission card + claimed checkmark (Penpot "Events" assets) ────────
global.spr_card_mission = sprite_add(_d + "card_mission.png", 1, false, false, 705, 195); // 1410×390, divider+reward col baked in, origin centred
global.spr_checkmark    = sprite_add(_d + "Checkmark.png",    1, false, false,  97,  86); // 194×172 gold-outlined purple tick, origin centred

// ── Game icons (512×512, origin centred) ──────────────────────────────────────
global.spr_game_anygram  = sprite_add(_d + "game_anygram.png",  1, false, false, 256, 256);
global.spr_game_sudoku   = sprite_add(_d + "game_sudoku.png",   1, false, false, 256, 256);
global.spr_game_wordwave = sprite_add(_d + "game_wordwave.png", 1, false, false, 256, 256);
global.spr_game_mixup    = sprite_add(_d + "game_mixup.png",    1, false, false, 256, 256);
global.spr_game_shikaku  = sprite_add(_d + "game_shikaku.png",  1, false, false, 256, 256);
global.spr_game_wordle   = sprite_add(_d + "game_wordle.png",   1, false, false, 256, 256);
// Hue Sort icon is pending; fall back to the mix-up icon until art lands.
global.spr_game_huesort  = sprite_add(_d + "game_huesort.png",  1, false, false, 256, 256);
if (global.spr_game_huesort < 0) global.spr_game_huesort = global.spr_game_mixup;
global.spr_game_colorlink = sprite_add(_d + "game_colorlink.png", 1, false, false, 256, 256);
if (global.spr_game_colorlink < 0) global.spr_game_colorlink = global.spr_game_mixup;
global.spr_game_wordbend = sprite_add(_d + "game_wordbend.png", 1, false, false, 256, 256);   // Word Bend
if (global.spr_game_wordbend < 0) global.spr_game_wordbend = global.spr_game_wordwave;
global.spr_game_arrows = sprite_add(_d + "game_arrows.png", 1, false, false, 317, 256);   // Arrows (635×512)
if (global.spr_game_arrows < 0) global.spr_game_arrows = global.spr_game_mixup;
global.spr_game_ladder = sprite_add(_d + "game_ladder.png", 1, false, false, 256, 256);   // Ladder (Word Ladder)
if (global.spr_game_ladder < 0) global.spr_game_ladder = global.spr_game_wordle;
global.spr_game_colordoku = sprite_add(_d + "game_colordoku.png", 1, false, false, 256, 256);   // Colordoku (Queens)
if (global.spr_game_colordoku < 0) global.spr_game_colordoku = global.spr_game_sudoku;

// ── Anygram tile (256×256, origin centred) ────────────────────────────────────
global.spr_tile = sprite_add(_d + "tile_empty.png", 1, false, false, 128, 128);

// ── Game-screen HUD art ───────────────────────────────────────────────────────
// back_buton.png — new solid-black back chevron (103×178, origin centred). Drawn
//                  with c_white so it keeps its baked colour.
// Wheel_bg.png   — Anygram wheel disc: yellow fill + dashed ring baked in
//                  (750×750, origin centred). Replaces the hand-drawn disc/ring.
global.spr_back2    = sprite_add(_d + "back_buton.png", 1, false, true, 51, 89);
global.spr_wheel_bg = sprite_add(_d + "Wheel_bg.png",   1, false, false, 375, 375);
// arrow.png — straight arrow (1405×250), origin at the centre so it rotates about
// its midpoint. Used by Arrows for the arrowhead / straight-arrow art (Phase 2).
global.spr_arrow    = sprite_add(_d + "arrow.png", 1, false, false, 702, 125);
// highlight.png — white capsule (1305×100, 50px round caps) for the Word Wave
// selection/found markers, drawn via ph_draw_highlight (3-slice, no overlap).
global.spr_highlight = sprite_add(_d + "highlight.png", 1, false, false, 0, 0);

// ── UI background art (origin top-left so 9-slice / tiling math is direct) ─────
// Pill.png  — white capsule (with a baked soft drop shadow) used as the shared
//             background for all pill-shaped chips (HUD LVL/Coin, card buttons,
//             toolbar chips, etc.) via ph_draw_pill / ph_draw_chip.
// BG Pattern.png — tiled cream texture that replaces the old dot-grid background.
global.spr_pill       = sprite_add(_d + "Pill.png",       1, false, false, 0, 0);
global.spr_bg_pattern = sprite_add(_d + "BG Pattern.png", 1, false, false, 0, 0);

// retro tv icon.png — full-colour TV used on the "FREE" (rewarded-video) hint
// button (512×512, origin centred). Placeholder art until the ad SDK ships.
global.spr_tv = sprite_add(_d + "retro tv icon.png", 1, false, false, 256, 256);

// ── Image button backgrounds (origin top-left for the 3-slice in ph_draw_btn_bg) ─
// One sprite per button colour; ph_draw_btn_bg slices it to any width so a single
// source covers every button. All share the source frame (height 230: 20px margin,
// 149px body, ~10px drop shadow). Routed by colour via ph_btn_sprite_for, so every
// blue/green/pink/red reward + nav button across the app uses these automatically.
global.spr_btn_blue  = sprite_add(_d + "blue_button_xlarge.png", 1, false, false, 0, 0); // CLAIM/DOUBLE/HOME/NEXT/YESTERDAY/CANCEL/COLLECT
global.spr_btn_green = sprite_add(_d + "green_button_large.png", 1, false, false, 0, 0); // BUY / FREE (hint + Wordle lose)
global.spr_btn_pink  = sprite_add(_d + "share_button.png",       1, false, false, 0, 0); // SHARE
global.spr_btn_red   = sprite_add(_d + "giveup_button.png",      1, false, false, 0, 0); // GIVE UP
// share_icon.png — white share glyph (100×100, origin centred) tinted on the SHARE button.
global.spr_share_icon = sprite_add(_d + "share_icon.png", 1, false, true, 50, 50);

// ── Hub date badge + progress-bar art ─────────────────────────────────────────
// today_circle.png — solid yellow circle behind the "today/selected" date number
//                    in the 7-day strip (124×124, origin centred).
// icon_check.png    — full-colour solved badge (pink disc + white tick baked in),
//                     so it is drawn directly with c_white (no tint) (38×38, centred).
global.spr_today_circle = sprite_add(_d + "today_circle.png", 1, false, false, 62, 62);
global.spr_check_badge  = sprite_add(_d + "icon_check.png",   1, false, false, 19, 19);
// Progress-bar segments (195×90). Origin x=0 / y=45 (left edge, vertically
// centred) so the bar tiles left-to-right with simple per-cell math. There is no
// dedicated grey_left cap; ph_draw_progress_segments mirrors grey_right for it.
global.spr_pb_purple_left   = sprite_add(_d + "progress_bar_purple_left.png",   1, false, false, 0, 45);
global.spr_pb_purple_center = sprite_add(_d + "progress_bar_purple_center.png", 1, false, false, 0, 45);
global.spr_pb_purple_right  = sprite_add(_d + "progress_bar_purple_right.png",  1, false, false, 0, 45);
global.spr_pb_grey_center   = sprite_add(_d + "progress_bar_grey_center.png",   1, false, false, 0, 45);
global.spr_pb_grey_right    = sprite_add(_d + "progress_bar_grey_right.png",    1, false, false, 0, 45);
// Expanded month-grid day boxes (106×107, origin centred): pink box marks the
// selected day, yellow box marks today.
global.spr_cal_day_sel   = sprite_add(_d + "calendar_day_bg_box_purple.png", 1, false, false, 53, 54);
global.spr_cal_day_today = sprite_add(_d + "calendar_day_bg_box_yellow.png", 1, false, false, 53, 54);

// ── Characters (origin centred) ───────────────────────────────────────────────
global.spr_blinky = sprite_add(_d + "char_blinky.png", 1, false, false, 332, 350);

// ── Onboarding tutorial finger pointer (origin centred) ───────────────────────
// Used by scr_tutorial coachmarks to point at the element the player should tap.
global.spr_finger = sprite_add(_d + "finger.png", 1, false, false, 153, 190);

// ── Screen-transition state (iris cover → reveal) ─────────────────────────────
// This persistent object spans every room, so it owns the transition: Step advances
// it (and swaps the room under full cover), Draw GUI renders the iris on top. Kick
// it off with ph_trans_begin(ox, oy, col, room). Drawn on top via a very low depth.
depth = -100000;
global.trans_active = false;
global.trans_phase  = 0;          // 1 = cover (iris in), 2 = reveal (iris out)
global.trans_t      = 0;          // frames elapsed in the current phase
global.trans_ox     = PH_W/2;     // iris origin (tap point)
global.trans_oy     = global.PH_H_dyn/2;
global.trans_col    = c_white;    // cover colour (the tapped card's accent)
global.trans_room   = -1;         // target room index, swapped to under full cover
global.TRANS_COVER_FR  = 16;      // cover beat — iris ACCELERATES out to fill (ph_ease_in)
global.TRANS_REVEAL_FR = 22;      // reveal beat — iris DECELERATES back to a point (ph_ease_out)

// ── Idle anchor (for the HINT-pill nudge) ─────────────────────────────────────
// Reset to current_time on any tap anywhere (see Step); the shared
// ph_hint_pill_nudge pulses the HINT pill once (current_time - this) exceeds
// PH_HINT_IDLE_SECS so a stuck player is reminded help is available.
global.ph_idle_anchor = current_time;
