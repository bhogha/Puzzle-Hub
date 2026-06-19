// ── Palette ───────────────────────────────────────────────────────────────────
#macro PH_COL_BG          make_color_rgb(255,246,241)
#macro PH_COL_PINK        make_color_rgb(233, 30,137)
#macro PH_COL_PINK_SOFT   make_color_rgb(255,217,236)
#macro PH_COL_PINK_DEEP   make_color_rgb(180, 10,100)
#macro PH_COL_YELLOW      make_color_rgb(255,198, 51)
#macro PH_COL_YELLOW_SOFT make_color_rgb(255,241,176)
#macro PH_COL_YELLOW_DEEP make_color_rgb(200,150,  0)
#macro PH_COL_TEAL        make_color_rgb( 20,184,166)
#macro PH_COL_TEAL_SOFT   make_color_rgb(204,251,241)
#macro PH_COL_TEAL_DEEP   make_color_rgb( 13,148,136)
#macro PH_COL_PURPLE      make_color_rgb(123, 63,242)
#macro PH_COL_PURPLE_SOFT make_color_rgb(196,170,255)
#macro PH_COL_PURPLE_DEEP make_color_rgb( 80, 30,180)
#macro PH_COL_ORANGE      make_color_rgb(255,122, 26)
#macro PH_COL_ORANGE_DEEP make_color_rgb(194, 78,  0)
#macro PH_COL_BLUE        make_color_rgb( 45,125,246)
#macro PH_COL_BLUE_SOFT   make_color_rgb(205,224,255)
#macro PH_COL_BLUE_DEEP   make_color_rgb( 20, 80,190)
#macro PH_COL_GREEN       make_color_rgb(  0,190, 73)   // Wordle accent (#00be49)
#macro PH_COL_GREEN_SOFT  make_color_rgb(200,240,210)
#macro PH_COL_GREEN_DEEP  make_color_rgb(  0,140, 55)
#macro PH_COL_LIME        make_color_rgb(199,231, 15)   // Color Link accent (#c7e70f)
#macro PH_COL_LIME_DEEP   make_color_rgb(120,150,  0)
#macro PH_COL_VIOLET      make_color_rgb(168, 56,222)   // Hue Sort accent (#a838de)
#macro PH_COL_VIOLET_SOFT make_color_rgb(235,205,250)
#macro PH_COL_VIOLET_DEEP make_color_rgb(108, 24,158)
#macro PH_COL_TANGERINE      make_color_rgb(255, 91, 56) // Word Bend accent (#ff5b38)
#macro PH_COL_TANGERINE_DEEP make_color_rgb(200, 60, 28)
#macro PH_COL_WB_FOUND       make_color_rgb(170,202, 49) // Word Bend found cell (#aaca31)
#macro PH_COL_WB_FOUND_DEEP  make_color_rgb( 95,118, 18) // letter on a found cell
#macro PH_COL_GOLD        make_color_rgb(245,180,  0)
#macro PH_COL_DARK        make_color_rgb( 31, 20, 48)
#macro PH_COL_INK_SOFT    make_color_rgb( 80, 60,100)
#macro PH_COL_INK_FAINT   make_color_rgb(200,190,210)
#macro PH_COL_GRAY        make_color_rgb(160,140,150)
#macro PH_COL_WHITE       make_color_rgb(255,255,255)
#macro PH_COL_TILE        make_color_rgb(255,250,245)
#macro PH_COL_TILE_DARK   make_color_rgb(234,220,210)
// Word Wave "words to find" tiles (Penpot design): found = solid pink (#d63789)
// with white text + strike-through; to-find = tan (#e7d5bd) with faint-ink text.
#macro PH_COL_WORD_FOUND      make_color_rgb(214, 55,137)
#macro PH_COL_WORD_FOUND_DEEP make_color_rgb(170, 35,105)
#macro PH_COL_WORD_TODO       make_color_rgb(231,213,189)
#macro PH_COL_WORD_TODO_DEEP  make_color_rgb(200,180,150)
// Hue Sort board (Penpot redesign): flat base/empty tile + locked-corner dot.
#macro PH_COL_HUE_TILE_BG make_color_rgb(241,234,225)   // #f1eae1 board / empty tile
#macro PH_COL_HUE_LOCK    make_color_rgb( 72, 70, 68)   // #484644 locked-corner dot
// Shared puzzle-board background (Penpot Sudoku/Shikaku): flat cream #f1eae1.
#macro PH_COL_BOARD_BG    make_color_rgb(241,234,225)
#macro PH_COL_SKYBLUE     make_color_rgb(110,165,230)   // #6ea5e6 Hue Sort title
#macro PH_COL_SILVER      make_color_rgb(184,185,189)   // Arrows accent (#b8b9bd)
#macro PH_COL_SILVER_SOFT make_color_rgb(226,227,231)
#macro PH_COL_SILVER_DEEP make_color_rgb(108,110,118)
// Ladder (Word Ladder): amber accent/title/selected tile (#ffc04c), soft amber
// hint highlight (#ffe5a8), green correct flash (= PH_COL_WB_FOUND #aaca31),
// red wrong flash (#eb5a5a). Base/empty tile reuses PH_COL_BOARD_BG (#f1eae1).
#macro PH_COL_AMBER       make_color_rgb(255,192, 76)   // #ffc04c
#macro PH_COL_AMBER_DEEP  make_color_rgb(205,150, 40)
#macro PH_COL_AMBER_SOFT  make_color_rgb(255,229,168)   // #ffe5a8 hint highlight
#macro PH_COL_LADDER_BAD  make_color_rgb(235, 90, 90)   // #eb5a5a wrong flash
// Colordoku (Queens / Meowdoku) accent: bright teal queen gem / title / win.
// Deep variant is a readable teal for titles & text on light backgrounds.
#macro PH_COL_BRTEAL      make_color_rgb( 90,242,188)   // #5af2bc accent gem
#macro PH_COL_BRTEAL_DEEP make_color_rgb( 22,150,118)   // readable deep teal

// ── Assets Path ───────────────────────────────────────────────────────────────
// On HTML5, relative asset paths are automatically resolved inside the "html5game/"
// folder on the server by the runner. Prepending working_directory (which is "html5game/")
// would double the prefix and cause 404 errors (e.g., "html5game/html5game/fonts/...").
// On other platforms, we prepend working_directory for correct bundle sandboxing.
#macro PH_ASSETS_PATH     ((os_browser != browser_not_a_browser) ? "" : working_directory)

// ── Canvas ────────────────────────────────────────────────────────────────────
// PH_W is fixed. PH_H is set at runtime in obj_persistent to match the device's
// actual aspect ratio, eliminating black bars on modern phones (e.g. iPhone 16 Pro
// is ~19.5:9, not 16:9). Use global.PH_H_dyn directly if you need the raw number.
#macro PH_W     1080
#macro PH_H     global.PH_H_dyn
#macro PH_SCALE (1080/390)

// ── Safe-area comfort padding ─────────────────────────────────────────────────
// Extra breathing room added ON TOP of the OS-reported iOS safe-area insets
// (global.safe_top_gui / safe_bottom_gui). Mobile-UI guidance recommends keeping
// content a comfortable distance from the Dynamic Island / status bar (top) and
// the home indicator (bottom) rather than flush against the raw inset — and on
// devices/sims that report a 0 inset this is the only thing preventing content
// from touching the very edge. Use the ph_safe_top()/ph_safe_bottom() helpers
// (scr_draw) instead of reading the raw insets for full-screen layouts.
#macro PH_PAD_TOP        40
#macro PH_PAD_BOTTOM     52

// Core-game screens bottom-anchor their play content (board + any pad/keyboard/
// list/wheel) so it sits just above the bottom HUD toolbar rather than crowding
// the top under the HUD. This is the gap left between the lowest play element and
// the bottom toolbar. Bump it to lift all puzzle content higher off the toolbar.
#macro PH_PLAY_BOTTOM_GAP 40

// ── Economy ──────────────────────────────────────────────────────────────────
#macro PH_XP_PER_PUZZLE     100
#macro PH_XP_PER_LEVEL      500
#macro PH_COINS_PER_LEVEL   100
#macro PH_COINS_FOR_4TH     100
#macro PH_HINT_COST         100
#macro PH_HINT_IDLE_SECS      5     // idle seconds before the HINT pill pulses a reminder
#macro PH_COLORDOKU_HINT_XS   3     // locked "ruled-out" X's placed per Colordoku hint
#macro PH_BONUS_WORD_XP      25
#macro PH_BONUS_WORD_COINS   10

// ── Wordle ────────────────────────────────────────────────────────────────────
#macro PH_WORDLE_LEN          6   // letters per word (6×6 board)
#macro PH_WORDLE_GUESSES      6   // base guess rows
#macro PH_WORDLE_EXTRA_MOVES  3   // one-time "extra moves" purchase adds this many rows
#macro PH_WORDLE_EXTRA_COST  100  // coins for the extra moves (or free via rewarded video)
#macro PH_WORDLE_GIVEUP_XP    25  // consolation XP on a missed/given-up puzzle (doubles to 50)

// ── Missions (weekly, personal install-anchored window) ───────────────────────
// See Docs/MISSIONS_PLAN.md. A "week" is a personal 7-day window: it starts when
// the previous week's rewards are collected (or on first init), freezes to a
// "finished" state when all missions are done or the timer expires, and only
// advances to a fresh week when the player taps COLLECT. Counters are weekly and
// reset each cycle. Reward XP is granted through ph_grant_xp(...,false) so a
// level-crossing routes through the Level-Up screen; every reward is < 500 (one
// level) so a single claim crosses at most one boundary.
#macro PH_WEEK_LENGTH_DAYS      7
#macro PH_WEEK_SET_SIZE         20   // missions drawn per week
#macro PH_WEEK_QUICK_COUNT      6
#macro PH_WEEK_CORE_COUNT       11
#macro PH_WEEK_CHALLENGE_COUNT  3
#macro PH_WEEK_DRAW_COOLDOWN    2    // weeks a used mission id is excluded from redraw

#macro PH_MISSION_XP_QUICK      50
#macro PH_MISSION_XP_CORE_LOW   150
#macro PH_MISSION_XP_CORE_HIGH  300
#macro PH_MISSION_XP_CHALLENGE  450  // kept under 500 (= one level) — see MISSIONS_PLAN §13.1
#macro PH_WEEK_COMPLETE_BONUS   300
#macro PH_MISSION_SPEED_SECS    90   // "Speedster" per-solve time threshold

// ── Starting state (per GDD: new players start at 100 XP / 300 coins) ─────────
#macro PH_INITIAL_XP       100
#macro PH_INITIAL_COINS    300

// ── Daily schedule ────────────────────────────────────────────────────────────
#macro PH_PUZZLES_PER_DAY   10
#macro PH_GIFT_PUZZLE_INDEX  3   // 0-based (4th slot)
#macro PH_ANYGRAM_INDEX      0
#macro PH_SUDOKU_INDEX       1
#macro PH_WORDWAVE_INDEX     2
#macro PH_SHIKAKU_INDEX      3
#macro PH_WORDLE_INDEX       4
#macro PH_HUESORT_INDEX      5
#macro PH_COLORLINK_INDEX    6
#macro PH_WORDBEND_INDEX     7
#macro PH_ARROWS_INDEX       8
#macro PH_LADDER_INDEX       9

// ── Hue Sort ──────────────────────────────────────────────────────────────────
#macro PH_HUESORT_SIZE       4   // N×N board (4 locked corner anchors)

// ── Arrows ────────────────────────────────────────────────────────────────────
#macro PH_ARROWS_COLS         14   // board columns (non-square; fills the portrait screen)
#macro PH_ARROWS_ROWS         19   // board rows
#macro PH_ARROWS_PENALTY_SECS  5   // time added on a blocked tap (no loss state — only time is lost)
#macro PH_ARROWS_MONO          true                       // single-ink ribbons (harder: player must trace paths); false = rainbow palette
#macro PH_ARROWS_INK           make_color_rgb(26,30,54)   // mono ribbon colour (deep navy, like the reference)

// ── Ladder ────────────────────────────────────────────────────────────────────
#macro PH_LADDER_PENALTY_SECS  5   // time added on a wrong guess (no loss state — only time is lost)

// ── Daily Spin ────────────────────────────────────────────────────────────────
// Free once-per-day prize wheel shown on the hub to drive D1+ retention. Unlocks
// on the player's PH_SPIN_UNLOCK_SESSION-th app launch (so brand-new players see
// it on their *second* session), then offers one free spin per calendar day.
// Six equal slices, prize picked uniformly at random; the player may double the
// coins by watching a (placeholder) rewarded video. Reward is COINS only for now;
// a consecutive-day progression bump is planned later (see GDD §Daily Spin).
#macro PH_SPIN_UNLOCK_SESSION 2     // first app session on which the wheel appears
#macro PH_SPIN_SLICES         6     // wedges on the wheel (matches ph_spin_prizes length)
#macro PH_SPIN_SPIN_SECS      2.6   // wheel spin duration (seconds) before it settles
#macro PH_SPIN_FULL_TURNS     5     // extra full rotations before landing on the prize
// ⚠️ TEST MODE: when > 0 the spin becomes available again this many MINUTES after a
// claim (instead of once per calendar day) so the returning-player flow can be
// tested without waiting a day. SET TO 0 BEFORE SHIPPING to restore daily behaviour.
#macro PH_SPIN_TEST_COOLDOWN_MINS 10

/// The six coin prizes, one per wheel slice (clockwise from the slice under the
/// pointer). Picked uniformly. Keep length == PH_SPIN_SLICES. Mirror any change
/// in GDD.md. Average ≈ 68 coins/spin.
function ph_spin_prizes() {
    return [10, 25, 50, 75, 100, 150];
}

// ── Save ──────────────────────────────────────────────────────────────────────
#macro PH_SAVE_FILE "puzzlehub_save.json"

// ── Sharing ───────────────────────────────────────────────────────────────────
// URL shared from the Win Screen SHARE button (App Store listing).
#macro PH_SHARE_URL "https://apps.apple.com/tr/app/puzzle/id1190624509?l=tr"

// ── Debug / testing ───────────────────────────────────────────────────────────
// When true, Sudoku starts ~90% solved so the win flow is quick to reach.
// SET BACK TO false BEFORE SHIPPING.
#macro PH_SUDOKU_TEST_PREFILL true

// When true, the hub draws a small safe-area readout (source + inset values) so
// you can confirm whether the insets came from the extension or the estimate.
// SET BACK TO false BEFORE SHIPPING.
#macro PH_DEBUG_SAFEAREA false

// ── Game cards ────────────────────────────────────────────────────────────────
function ph_game_cards() {
    var _cards = [];
    array_push(_cards, {
        name:     "ANYGRAM",
        subtitle: "Word cross",
        room:     "rm_anygram",
        locked:   false,
        card_spr: global.spr_card_yellow,
        icon_spr: global.spr_game_anygram,
        text_col: make_color_rgb(180, 130, 0),
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "SUDOKU",
        subtitle: "Number logic",
        room:     "rm_sudoku",
        locked:   false,
        card_spr: global.spr_card_purple,
        icon_spr: global.spr_game_sudoku,
        text_col: make_color_rgb(80, 30, 180),
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "WORD WAVE",
        subtitle: "Find the hidden word",
        room:     "rm_wordwave",
        locked:   false,
        card_spr: global.spr_card_teal,
        icon_spr: global.spr_game_wordwave,
        text_col: PH_COL_TEAL_DEEP,
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "SHIKAKU",
        subtitle: "Divide by squares",
        room:     "rm_shikaku",
        locked:   false,
        card_spr: global.spr_card_blue,
        icon_spr: global.spr_game_shikaku,
        text_col: PH_COL_BLUE_DEEP,
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "WORDLE",
        subtitle: "Guess the word",
        room:     "rm_wordle",
        locked:   false,
        card_spr: global.spr_card_green,
        icon_spr: global.spr_game_wordle,
        text_col: make_color_rgb(0, 90, 40),
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "HUE SORT",
        subtitle: "Sort color tiles",
        room:     "rm_huesort",
        locked:   false,
        card_spr: global.spr_card_skyblue,
        icon_spr: global.spr_game_huesort,
        text_col: PH_COL_BLUE_DEEP,
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "COLOR LINK",
        subtitle: "Link colors",
        room:     "rm_colorlink",
        locked:   false,
        card_spr: global.spr_card_lime,
        icon_spr: global.spr_game_colorlink,
        text_col: PH_COL_LIME_DEEP,
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "WORD BEND",
        subtitle: "Fill the grid with words",
        room:     "rm_wordbend",
        locked:   false,
        card_spr: global.spr_card_tangerine,
        icon_spr: global.spr_game_wordbend,
        text_col: PH_COL_TANGERINE_DEEP,
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "ARROWS",
        subtitle: "Slide the arrows out",
        room:     "rm_arrows",
        locked:   false,
        card_spr: global.spr_card_silver,
        icon_spr: global.spr_game_arrows,
        text_col: PH_COL_SILVER_DEEP,
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "LADDER",
        subtitle: "Change one letter at a time",
        room:     "rm_ladder",
        locked:   false,
        card_spr: global.spr_card_orange,
        icon_spr: global.spr_game_ladder,
        text_col: PH_COL_AMBER_DEEP,
        btn_type: "play_light",
    });
    array_push(_cards, {
        name:     "COLORDOKU",
        subtitle: "One queen per colour, row & column",
        room:     "rm_colordoku",
        locked:   false,
        card_spr: global.spr_card_brightteal,
        icon_spr: global.spr_game_colordoku,
        text_col: PH_COL_BRTEAL_DEEP,
        btn_type: "play_light",
    });
    return _cards;
}

// ── Game tips ─────────────────────────────────────────────────────────────────
// One-line objective hint shown above each puzzle's grid (Nunito-regular, faint
// ink — see ph_draw_game_tip in scr_draw). Player-facing copy lives here so it
// stays in one place; mirror any change in GDD.md. Keys match the puzzle's
// controller (anygram / sudoku / wordwave / shikaku / wordle / huesort).
function ph_game_tip(_key) {
    switch (_key) {
        case "anygram":  return "Find the hidden words";
        case "sudoku":   return "Fill the grid with missing numbers";
        case "wordwave": return "Find the hidden words on the grid";
        case "shikaku":  return "Draw a rectangle for each number";
        case "wordle":   return "Find the hidden word of the day";
        case "huesort":  return "Swap tiles so the colors blend smoothly";
        case "colorlink": return "Connect colors without leaving empty spaces";
        case "wordbend":  return "Find words using every letter on the board";
        case "arrows":    return "Guide arrows out without causing any collisions";
        case "ladder":    return "Change one letter at a time";
        case "colordoku": return "Place one queen per colour, row and column";
        default:         return "";
    }
}

