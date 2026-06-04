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
#macro PH_COL_GOLD        make_color_rgb(245,180,  0)
#macro PH_COL_DARK        make_color_rgb( 31, 20, 48)
#macro PH_COL_INK_SOFT    make_color_rgb( 80, 60,100)
#macro PH_COL_INK_FAINT   make_color_rgb(200,190,210)
#macro PH_COL_GRAY        make_color_rgb(160,140,150)
#macro PH_COL_WHITE       make_color_rgb(255,255,255)
#macro PH_COL_TILE        make_color_rgb(255,250,245)
#macro PH_COL_TILE_DARK   make_color_rgb(234,220,210)

// ── Canvas ────────────────────────────────────────────────────────────────────
// PH_W is fixed. PH_H is set at runtime in obj_persistent to match the device's
// actual aspect ratio, eliminating black bars on modern phones (e.g. iPhone 16 Pro
// is ~19.5:9, not 16:9). Use global.PH_H_dyn directly if you need the raw number.
#macro PH_W     1080
#macro PH_H     global.PH_H_dyn
#macro PH_SCALE (1080/390)

// ── Economy ──────────────────────────────────────────────────────────────────
#macro PH_XP_PER_PUZZLE     100
#macro PH_XP_PER_LEVEL      500
#macro PH_COINS_PER_LEVEL   100
#macro PH_COINS_FOR_4TH     100
#macro PH_HINT_COST         100
#macro PH_BONUS_WORD_XP      25
#macro PH_BONUS_WORD_COINS   10

// ── Wordle ────────────────────────────────────────────────────────────────────
#macro PH_WORDLE_LEN          6   // letters per word (6×6 board)
#macro PH_WORDLE_GUESSES      6   // base guess rows
#macro PH_WORDLE_EXTRA_MOVES  3   // one-time "extra moves" purchase adds this many rows
#macro PH_WORDLE_EXTRA_COST  100  // coins for the extra moves (or free via rewarded video)
#macro PH_WORDLE_GIVEUP_XP    25  // consolation XP on a missed/given-up puzzle (doubles to 50)

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

// ── Save ──────────────────────────────────────────────────────────────────────
#macro PH_SAVE_FILE "puzzlehub_save.json"

// ── Sharing ───────────────────────────────────────────────────────────────────
// URL shared from the Win Screen SHARE button (App Store listing).
#macro PH_SHARE_URL "https://apps.apple.com/tr/app/puzzle/id1190624509?l=tr"

// ── Debug / testing ───────────────────────────────────────────────────────────
// When true, Sudoku starts ~90% solved so the win flow is quick to reach.
// SET BACK TO false BEFORE SHIPPING.
#macro PH_SUDOKU_TEST_PREFILL true

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
        name:     "MIX-UP",
        subtitle: "Rearrange",
        room:     "",
        locked:   true,
        card_spr: global.spr_card_orange,
        icon_spr: global.spr_game_mixup,
        text_col: PH_COL_ORANGE_DEEP,
        btn_type: "locked",
    });
    return _cards;
}

