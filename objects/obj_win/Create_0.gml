// ── Level-Up reward screen (rm_win) ───────────────────────────────────────────
// Shown after a puzzle's win screen when that puzzle pushed the player over a
// level boundary (global.pending_levelup is set in the *_check_win functions).
// The player picks a reward: take the base coins, or DOUBLE them by watching a
// placeholder rewarded video. Either choice grants coins, clears the pending
// flag, and returns to the hub.
//
// NOTE: this object is the repurposed (formerly dead) obj_win + rm_win pair —
// the in-game win overlay is drawn inside each puzzle controller, so this slot
// was free. See GDD §2.6.

lu = variable_global_exists("pending_levelup") ? global.pending_levelup : undefined;

// Safety: reached with nothing pending (e.g. direct room load) → bounce to hub.
valid = !is_undefined(lu);
if (!valid) {
    room_goto(rm_hub);
} else {
    level       = lu.level;
    base_reward = lu.base_reward;        // 100 (PH_COINS_PER_LEVEL)
}

claimed = false;                          // guards against double-granting
anim_t  = 0;                              // card slide-in 0..1

// Placeholder rewarded video (DOUBLE path) — mirrors the hint flow's timing.
// NB: `video_open` is a reserved GameMaker built-in, so this is `vid_open`.
vid_open      = false;
video_timer   = 0;
VIDEO_X_DELAY = 300;                      // ~5s @60fps before the close X appears

// Button hit-test bounds — written at settled positions by Draw_64 each frame.
PAY_L = 70;            PAY_R = PH_W/2 - 15;
PAY_T = PH_H - 300;    PAY_B = PH_H - 160;
DBL_L = PH_W/2 + 15;   DBL_R = PH_W - 70;
DBL_T = PH_H - 300;    DBL_B = PH_H - 160;

// ── Confetti (one-shot celebratory burst, same model as the win screens) ──────
confetti_pieces = [];
var _pal   = [PH_COL_PINK, PH_COL_YELLOW, PH_COL_TEAL, PH_COL_PURPLE, PH_COL_WHITE, PH_COL_ORANGE];
var _n_pal = array_length(_pal);
if (valid) {
    for (var _bi = 0; _bi < 70; _bi++) {
        var _ang   = random(2*pi);
        var _speed = 12 + random(16);
        array_push(confetti_pieces, {
            x: PH_W/2 + cos(_ang)*4, y: 620 + sin(_ang)*4,
            vx: cos(_ang)*_speed,    vy: sin(_ang)*_speed,
            rot: random(360), vrot: -8 + random(16),
            size: 14 + irandom(10),
            col: _pal[irandom(_n_pal-1)], shape: irandom(2),
        });
    }
}

/// Grant the chosen reward once, clear the pending flag, and return to the hub.
lu_claim = function(_amount) {
    if (claimed) return;
    claimed = true;
    ph_grant_coins(global.save, _amount);
    ph_save_write(global.save);
    global.pending_levelup = undefined;
    room_goto(rm_hub);
};
