// ── Profile — Create ──────────────────────────────────────────────────────────
// Easter egg: tap the "Level" text 3 times within 2 seconds to wipe all save
// progress (XP, coins, solved puzzles, streak, gift claims, bonus words).
// On reset, a toast confirms the wipe and the room transitions back to rm_hub
// so the player sees the freshly-zeroed daily progression tube.
level_tap_count     = 0;
level_tap_last      = 0;            // current_time of last tap (ms)
LEVEL_TAP_WINDOW_MS = 2000;         // taps must be within this gap
LEVEL_TAP_REQUIRED  = 3;

// Reset confirmation toast (same look/feel as the Anygram toast).
toast_text  = "";
toast_col   = PH_COL_PINK_DEEP;
toast_timer = 0;
TOAST_DUR   = 120;                  // ~2s at 60fps

// Pending hub navigation after the reset toast plays out. -1 = inactive.
pending_hub_timer = -1;
