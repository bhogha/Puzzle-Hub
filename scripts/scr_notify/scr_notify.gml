// ── scr_notify — local "spin ready" reminder notification (iOS) ──────────────
// Schedules a "Your daily spin is ready!" reminder delivered by the OS even when
// the app is closed, SYNCED to the Daily Spin cooldown: it fires the moment the
// next free spin becomes available. Backed by the native iOS `LocalNotifications`
// extension (UserNotifications framework). Tapping it just opens the app.
//
// Timing model: `notif_setup_daily_puzzle(seconds)` (native) takes a delay —
//   seconds > 0  → one-shot, that many seconds from now (synced to the cooldown);
//   seconds == 0 → repeating daily reminder at 9:30 AM (production, once-per-day);
//   seconds < 0  → schedule nothing (the spin is already available).
// `ph_notify_spin_delay_secs()` computes that value from the spin state, so the
// reminder always lands exactly when the player can spin again.
//
// iOS ONLY for now: every entry point is guarded by `os_type == os_ios`, so other
// platforms compile and run unaffected. To add Android later, add a parallel
// native module and route it here behind an `os_android` branch.
//
// Opt-in flow (per design): the iOS permission prompt is shown ONCE, the first
// time the player finishes a puzzle (warmer than a cold first-launch prompt). The
// "already asked" flag is persisted in `save.notif_requested`. After opt-in, the
// reminder is re-armed on every boot AND whenever a spin is claimed (the cooldown
// resets), so it always points at the next spin.

/// True on a platform where local notifications are wired up (iOS only for now).
function ph_notify_supported() {
    return (os_type == os_ios);
}

/// Seconds to wait before the "spin ready" reminder should fire:
///   > 0  → fire that many seconds from now (one-shot, synced to the cooldown);
///   == 0 → use the repeating daily 9:30 AM reminder (production once-per-day mode);
///   < 0  → the spin is already available, so nothing should be scheduled.
/// Driven by PH_SPIN_TEST_COOLDOWN_MINS so it matches ph_spin_eligible exactly.
function ph_notify_spin_delay_secs() {
    // Production (daily): keep the once-a-day 9:30 AM reminder.
    if (PH_SPIN_TEST_COOLDOWN_MINS <= 0) return 0;
    // Test cooldown: fire when the N-minute window since the last claim elapses.
    var _s = global.save;
    if (!variable_struct_exists(_s, "spin_claimed_dt")
    ||  !is_real(_s.spin_claimed_dt) || _s.spin_claimed_dt <= 0) return -1; // never claimed → spin is ready now
    var _remain_min = PH_SPIN_TEST_COOLDOWN_MINS
                    - date_minute_span(_s.spin_claimed_dt, date_current_datetime());
    if (_remain_min <= 0) return -1;                 // cooldown already elapsed → ready now
    return _remain_min * 60;
}

/// (Re)arm the "spin ready" reminder for the current spin state. Idempotent — the
/// native side replaces the existing request and never re-prompts once the user
/// has answered. No-op on unsupported platforms or before opt-in.
function ph_notify_sync_spin() {
    if (!ph_notify_supported()) return;
    if (!variable_struct_exists(global.save, "notif_requested")) return;
    if (!global.save.notif_requested) return;
    notif_setup_daily_puzzle(ph_notify_spin_delay_secs());
}

/// Re-arm at boot IF the player already opted in (covers cooldowns that elapsed
/// while the app was closed).
function ph_notify_boot() {
    ph_notify_sync_spin();
}

/// Called once after the player's first solved puzzle: request notification
/// permission (shows the iOS prompt the first time) and arm the reminder for the
/// current spin state. Marks the save so the prompt only ever runs once.
function ph_notify_request_after_first_solve() {
    if (!ph_notify_supported()) return;
    if (variable_struct_exists(global.save, "notif_requested") && global.save.notif_requested) return;
    global.save.notif_requested = true;
    ph_save_write(global.save);
    notif_setup_daily_puzzle(ph_notify_spin_delay_secs());
}

/// Cancel the scheduled reminder (for a future Settings toggle). iOS-guarded.
function ph_notify_cancel() {
    if (!ph_notify_supported()) return;
    notif_cancel_all();
}
