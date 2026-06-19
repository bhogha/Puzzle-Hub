#!/usr/bin/env python3
"""Hue Sort board generator for Puzzle Hub — 4x4 bilinear gradients with corners
spaced around the hue wheel, tuned so the puzzle is comfortably solvable.

WHY THIS EXISTS
  Hue Sort builds the whole board by bilinearly interpolating four CORNER colours
  (see ph_huesort_make in scr_huesort.gml). The puzzle's difficulty is governed by
  the SMALLEST colour difference between two ADJACENT tiles: on a 4x4 grid adjacent
  tiles differ by only ~1/(N-1) = 1/3 of the distance between two adjacent corners,
  so when an edge's two corners are close the steps along it become nearly
  invisible and the player is guessing. Hand-authored boards drifted into "all
  warm" palettes whose edges barely move (min adjacent delta as low as ~4 on a
  0..255 RGB scale, where ~2-3 is the just-noticeable threshold).

  The fix (Bora, 2026-06-15): keep all 16 tiles but make the corners MORE DISTANT —
  specifically place the four corners at well-separated HUES around the colour wheel
  at high saturation, and reject any board whose minimum adjacent-tile perceptual
  delta (CIELAB dE76) falls below a floor. That forces every edge to span a real
  distance, so each of the 16 placements is readable. Target = "moderate": clearly
  easier than before, still a genuine perceptual challenge on the trickier tiles.

OUTPUT JSON entry shape (matches scr_huesort.gml):
  { "date":"YYYY-MM-DD"(optional), "size":4,
    "corners":{ "tl":"RRGGBB","tr":"RRGGBB","bl":"RRGGBB","br":"RRGGBB" } }

USAGE
  python3 tools/gen_huesort.py                          # 30 past + 30 future
  python3 tools/gen_huesort.py --append                 # add 60 new days after last
  python3 tools/gen_huesort.py --append --add 90 --start-date 2026-10-01
  python3 tools/gen_huesort.py --min-delta 22 --seed 7  # stricter separation

Re-runs are deterministic for a given --seed. Append derives its seed from the
start date by default, so each top-up differs yet stays reproducible.
"""
import argparse, colorsys, datetime, json, math, os, statistics, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)                       # .../Puzzle Hub
OUT_PATH = os.path.join(PROJECT, "datafiles", "puzzles_huesort.json")

N = 4   # board is N x N (matches PH_HUESORT_SIZE)

# "Moderate" difficulty floor: the smallest allowed CIELAB dE76 between any two
# 4-neighbour tiles on the finished board. ~18 reads as clearly distinct on screen
# without making the gradient look like four flat blocks. (Current hand-authored
# boards bottomed out around dE 4-12 on their hardest edges.)
MIN_ADJ_DELTA = 18.0

# Corners sit near 90-degrees apart on the hue wheel so all four EDGES span a real
# distance (not just opposite corners). Saturation/value stay high and vibrant.
SAT_RANGE = (0.62, 0.92)
VAL_RANGE = (0.82, 1.00)
HUE_JITTER = 0.06          # +/- fraction of the wheel each corner may wobble


# ── Colour helpers ────────────────────────────────────────────────────────────
def hsv_to_rgb255(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return (round(r * 255), round(g * 255), round(b * 255))


def to_hex(rgb):
    return "".join("%02X" % c for c in rgb)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _srgb_to_linear(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb_to_lab(rgb):
    r, g, b = (_srgb_to_linear(c) for c in rgb)
    # linear sRGB -> XYZ (D65)
    x = r * 0.4124 + g * 0.3576 + b * 0.1805
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = r * 0.0193 + g * 0.1192 + b * 0.9505
    # normalise by D65 white point
    x /= 0.95047; z /= 1.08883
    def f(t):
        return t ** (1 / 3) if t > 0.008856 else (7.787 * t + 16 / 116)
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def de76(rgb_a, rgb_b):
    la, lb = rgb_to_lab(rgb_a), rgb_to_lab(rgb_b)
    return math.sqrt(sum((la[i] - lb[i]) ** 2 for i in range(3)))


# ── Board metrics (mirrors ph_huesort_make's bilinear fill) ───────────────────
def board_tiles(corners):
    tl, tr, bl, br = (corners[k] for k in ("tl", "tr", "bl", "br"))
    g = []
    for r in range(N):
        fy = r / (N - 1)
        for c in range(N):
            fx = c / (N - 1)
            top = lerp(tl, tr, fx)
            bot = lerp(bl, br, fx)
            g.append(tuple(round(v) for v in lerp(top, bot, fy)))
    return g


def min_adjacent_delta(corners):
    g = board_tiles(corners)
    m = 1e9
    for r in range(N):
        for c in range(N):
            i = r * N + c
            for dr, dc in ((0, 1), (1, 0)):
                rr, cc = r + dr, c + dc
                if rr < N and cc < N:
                    m = min(m, de76(g[i], g[rr * N + cc]))
    return m


# ── Board generation ──────────────────────────────────────────────────────────
def make_corners(rng):
    """Four corners at ~90-degrees-apart hues, high S/V, lightly jittered. Returns
    a dict of RGB tuples keyed tl/tr/bl/br. Hues are placed so the two gradient
    axes (across and down) each span a clear colour change."""
    base = rng.random()                      # random wheel rotation
    # Order around the wheel; diagonal corners are complementary, edges ~90 apart.
    offsets = {"tl": 0.0, "tr": 0.25, "br": 0.5, "bl": 0.75}
    corners = {}
    for k, off in offsets.items():
        h = base + off + rng.uniform(-HUE_JITTER, HUE_JITTER)
        s = rng.uniform(*SAT_RANGE)
        v = rng.uniform(*VAL_RANGE)
        corners[k] = hsv_to_rgb255(h, s, v)
    return corners


def gen_board(rng, min_delta, tries=400):
    for _ in range(tries):
        corners = make_corners(rng)
        if min_adjacent_delta(corners) >= min_delta:
            return {k: to_hex(v) for k, v in corners.items()}
    return None   # extremely unlikely; caller raises


def one_board(rng, min_delta):
    for _ in range(50):
        b = gen_board(rng, min_delta)
        if b is not None:
            return b
    sys.exit(f"ERROR: could not satisfy --min-delta {min_delta}; lower it.")


# ── Dates ─────────────────────────────────────────────────────────────────────
def date_range(start_date, n, step):
    return [(start_date + datetime.timedelta(days=step * i)).isoformat()
            for i in range(n)]


def make_entry(corners, date=None):
    e = {"size": N, "corners": corners}
    return {"date": date, **e} if date else e


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--append", action="store_true",
                    help="add new dated days to the existing pool (existing untouched)")
    ap.add_argument("--add", type=int, default=60,
                    help="append mode: how many new dated days to add (default 60)")
    ap.add_argument("--start-date", default=None,
                    help="append mode: first new date YYYY-MM-DD "
                         "(default: day after the last dated day in the file)")
    ap.add_argument("--past", type=int, default=30, help="fresh mode: dated days before today")
    ap.add_argument("--future", type=int, default=30, help="fresh mode: dated days from today on")
    ap.add_argument("--fallbacks", type=int, default=0, help="fresh mode: undated fallback boards")
    ap.add_argument("--min-delta", type=float, default=MIN_ADJ_DELTA,
                    help=f"min adjacent-tile CIELAB dE76 floor (default {MIN_ADJ_DELTA}; "
                         f"higher = easier / more contrast)")
    ap.add_argument("--seed", type=int, default=None,
                    help="RNG seed. Default: 20260615 fresh, or derived from start date on append")
    ap.add_argument("--today", default=datetime.date.today().isoformat(),
                    help="fresh mode: anchor date YYYY-MM-DD (today)")
    ap.add_argument("--preview", type=int, default=4, help="print this many boards' corners")
    args = ap.parse_args()

    import random
    if args.append:
        boards, label = _append(args)
    else:
        boards, label = _fresh(args, random)

    # Stats: the per-board hardest adjacent step + corner spread.
    adj = [min_adjacent_delta({k: _hex(v) for k, v in b["corners"].items()}) for b in boards]
    print(f"\n{label}")
    print(f"  boards: {len(boards)}")
    print(f"  min adjacent dE76 (hardest step / board): "
          f"floor {min(adj):.1f}  median {statistics.median(adj):.1f}  max {max(adj):.1f}")
    print(f"  (difficulty floor enforced: dE76 >= {args.min_delta})")
    for b in boards[:args.preview]:
        print(f"  {b.get('date','(fallback)')}  {b['corners']}")


def _hex(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def _fresh(args, random):
    rng = random.Random(args.seed if args.seed is not None else 20260615)
    today = datetime.date.fromisoformat(args.today)
    past = list(reversed(date_range(today - datetime.timedelta(days=1), args.past, -1)))
    future = date_range(today, args.future, 1)
    dated = past + future

    boards = [make_entry(one_board(rng, args.min_delta), d) for d in dated]
    for _ in range(args.fallbacks):
        boards.append(make_entry(one_board(rng, args.min_delta)))

    json.dump(boards, open(OUT_PATH, "w", encoding="utf-8"), separators=(",", ":"))
    label = (f"Wrote {len(boards)} boards -> {OUT_PATH}\n"
             f"  dated: {len(dated)} ({args.past} past + {args.future} future), "
             f"undated fallbacks: {args.fallbacks}")
    return boards, label


def _append(args):
    import random
    if not os.path.exists(OUT_PATH):
        sys.exit(f"ERROR: --append needs an existing pool at {OUT_PATH}. "
                 f"Run once without --append first.")
    existing = json.load(open(OUT_PATH, encoding="utf-8"))
    existing_dates = {e["date"] for e in existing if isinstance(e, dict) and "date" in e}

    if args.start_date:
        start = datetime.date.fromisoformat(args.start_date)
    elif existing_dates:
        start = datetime.date.fromisoformat(max(existing_dates)) + datetime.timedelta(days=1)
    else:
        start = datetime.date.today()
    new_dates = date_range(start, args.add, 1)

    clash = sorted(set(new_dates) & existing_dates)
    if clash:
        sys.exit(f"ERROR: {len(clash)} new date(s) already exist (e.g. {clash[0]}). "
                 f"Pick a later --start-date.")

    seed = args.seed if args.seed is not None else int(start.strftime("%Y%m%d"))
    rng = random.Random(seed)
    new_boards = [make_entry(one_board(rng, args.min_delta), d) for d in new_dates]
    merged = existing + new_boards

    json.dump(merged, open(OUT_PATH, "w", encoding="utf-8"), separators=(",", ":"))
    label = (f"Appended {len(new_boards)} boards ({new_dates[0]} -> {new_dates[-1]}) "
             f"-> {OUT_PATH}\n  pool was {len(existing)}, now {len(merged)} "
             f"(existing untouched)")
    return merged, label


if __name__ == "__main__":
    main()
