#!/usr/bin/env python3
"""Word Bend board generator for Puzzle Hub — 5x5, fully tiled, S-shaped bias.

Word Bend covers the whole board with hidden words whose orthogonal (bending)
cell-paths tile the grid exactly once. The player finds a word by tracing its
exact cell-path (the match is geometric, not letter-based — see ph_wordbend_match
in scr_wordbend.gml), so ANY real word of the right length can fill a given path.

Generation, per board:
  1. Build a random Hamiltonian path over the 5x5 (backbite) and cut it into
     contiguous snake segments (each is a valid Word Bend word path). The segments
     tile the board → always fully solvable.
  2. Score the geometry for "snakiness" and keep the best of several candidates,
     so paths zig-zag like an S rather than forming straight lines or square
     blobs. (Soft preference, not a hard rule — see SNAKINESS below.)
  3. Assign each segment a DISTINCT real word of its length from the curated
     Level Editors word bank (common, recognisable words).

SNAKINESS (why it looks S-like, not square):
  We reward TURNS and especially ALTERNATING turns (left-right-left…). A straight
  run has no turns; a square spiral turns the same way repeatedly; an S keeps
  flipping direction. Maximising alternating turns favours snakes. Longer segments
  are also weighted up in the cut, since length 3 can bend at most once.

Output JSON entry shape (matches scr_wordbend.gml):
  { "date":"YYYY-MM-DD"(optional), "size":5,
    "words":[ {"text":"WORD","path":[[r,c],...]}, ... ] }

USAGE:
  python3 tools/gen_wordbend.py                         # 30 past + 30 future
  python3 tools/gen_wordbend.py --append                # add 60 new days after last
  python3 tools/gen_wordbend.py --append --add 90 --start-date 2026-10-01
  python3 tools/gen_wordbend.py --candidates 40 --seed 7   # snakier / different pool

Re-runs are deterministic for a given --seed. Append derives its seed from the
start date by default, so each top-up differs yet stays reproducible.
"""
import argparse, collections, datetime, json, os, random, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)                       # .../Puzzle Hub
OUT_PATH = os.path.join(PROJECT, "datafiles", "puzzles_wordbend.json")

N = 5
NCELLS = N * N
LEN_MIN, LEN_MAX = 3, 6
DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]
# Cut bias: heavier weights on longer segments so paths have room to snake.
LEN_WEIGHTS = {3: 1, 4: 2, 5: 4, 6: 5}

WORDLIST_CANDIDATES = [
    os.path.join(PROJECT, "..", "Level Editors", "Word List.txt"),
    os.path.join(PROJECT, "..", "Daily Puzzle", "Level Editors", "Word List.txt"),
]


# ── Word bank ─────────────────────────────────────────────────────────────────
def load_words():
    path = next((p for p in WORDLIST_CANDIDATES if os.path.exists(p)), None)
    if not path:
        sys.exit("ERROR: Word List.txt not found:\n  " + "\n  ".join(WORDLIST_CANDIDATES))
    toks = re.split(r"[,\s]+", open(path, encoding="utf-8").read())
    words = [t.strip().upper() for t in toks if t.strip()]
    words = [w for w in words if w.isalpha() and LEN_MIN <= len(w) <= LEN_MAX]

    # The curated list has a few typos (WHISTL, COMPAC, ...). Letters are shown on
    # the board, so drop misspellings via offline pyspellchecker when available.
    valid = None
    try:
        from spellchecker import SpellChecker
        valid = SpellChecker()
    except ImportError:
        print("NOTE: pyspellchecker not installed — skipping typo filter. "
              "For best results: pip install pyspellchecker")

    buckets = {L: [] for L in range(LEN_MIN, LEN_MAX + 1)}
    seen, dropped = set(), []
    for w in words:
        if w in seen:
            continue
        seen.add(w)
        if valid is not None and w.lower() not in valid:
            dropped.append(w)
            continue
        buckets[len(w)].append(w)
    if dropped:
        print(f"dropped {len(dropped)} misspelled entries, e.g. {dropped[:8]}")
    print("word bank sizes:", {L: len(buckets[L]) for L in buckets})
    return buckets


# ── Hamiltonian path (backbite) ───────────────────────────────────────────────
def initial_snake():
    path = []
    for r in range(N):
        cols = range(N) if r % 2 == 0 else range(N - 1, -1, -1)
        for c in cols:
            path.append((r, c))
    return path


def hamiltonian_path(rng, iters=4000):
    path = initial_snake()
    for _ in range(iters):
        if rng.random() < 0.5:
            path.reverse()
        end = path[-1]
        nbrs = [(end[0] + dr, end[1] + dc) for dr, dc in DIRS]
        nbrs = [(r, c) for r, c in nbrs if 0 <= r < N and 0 <= c < N]
        w = rng.choice(nbrs)
        j = path.index(w)
        if j >= len(path) - 2:
            continue
        path = path[:j + 1] + path[j + 1:][::-1]
    return path


def cut_lengths(total, rng):
    for _ in range(200):
        parts, rem = [], total
        ok = True
        while rem > 0:
            choices = [L for L in range(LEN_MIN, LEN_MAX + 1)
                       if L <= rem and (rem - L == 0 or rem - L >= LEN_MIN)]
            if not choices:
                ok = False
                break
            weights = [LEN_WEIGHTS[L] for L in choices]
            parts.append(rng.choices(choices, weights=weights, k=1)[0])
            rem -= parts[-1]
        if ok:
            rng.shuffle(parts)
            return parts
    raise RuntimeError("could not compose segment lengths")


# ── Snakiness scoring ─────────────────────────────────────────────────────────
def segment_snakiness(seg):
    """Higher = more S-like. The dominant term is SPARSITY: a winding S leaves
    gaps inside its bounding box (bbox_area > length), while a solid rectangle or
    2x2 square fills its bbox exactly (sparsity 0). We add turn and alternating-
    turn rewards so among equally sparse shapes the zig-zags win."""
    steps = [(b[0] - a[0], b[1] - a[1]) for a, b in zip(seg, seg[1:])]
    crosses = []
    for d0, d1 in zip(steps, steps[1:]):
        cr = d0[0] * d1[1] - d0[1] * d1[0]   # +1 left, -1 right, 0 straight
        if cr != 0:
            crosses.append(cr)
    turns = len(crosses)
    alternations = sum(1 for a, b in zip(crosses, crosses[1:]) if a != b)
    rs = [c[0] for c in seg]
    cs = [c[1] for c in seg]
    bbox = (max(rs) - min(rs) + 1) * (max(cs) - min(cs) + 1)
    sparsity = bbox - len(seg)                # 0 = compact block, >0 = winding
    return 3 * sparsity + turns + 2 * alternations


def board_snakiness(segments):
    return sum(segment_snakiness(s) for s in segments)


# ── Board generation ──────────────────────────────────────────────────────────
def gen_geometry(rng, candidates):
    """Return the snakiest (path, lengths) over `candidates` random tries."""
    best, best_score = None, -1
    for _ in range(candidates):
        path = hamiltonian_path(rng)
        lengths = cut_lengths(NCELLS, rng)
        segs, idx = [], 0
        for L in lengths:
            segs.append(path[idx:idx + L])
            idx += L
        score = board_snakiness(segs)
        if score > best_score:
            best, best_score = (path, lengths), score
    return best


def gen_board(rng, buckets, candidates):
    path, lengths = gen_geometry(rng, candidates)
    avail = {L: buckets[L][:] for L in buckets}
    for L in avail:
        rng.shuffle(avail[L])
    words, idx = [], 0
    for L in lengths:
        seg = path[idx:idx + L]
        idx += L
        if not avail[L]:
            return None
        words.append({"text": avail[L].pop(), "path": [[r, c] for (r, c) in seg]})
    return {"size": N, "words": words}


def one_board(rng, buckets, candidates):
    b = None
    while b is None:
        b = gen_board(rng, buckets, candidates)
    return b


# ── Verification (mirrors the tiling rule ph_wordbend relies on) ───────────────
def verify(board):
    n = board["size"]
    cov = [0] * (n * n)
    for wd in board["words"]:
        if len(wd["text"]) != len(wd["path"]) or not wd["text"].isalpha():
            return False
        prev = None
        for (r, c) in wd["path"]:
            if not (0 <= r < n and 0 <= c < n):
                return False
            cov[r * n + c] += 1
            if prev is not None and abs(r - prev[0]) + abs(c - prev[1]) != 1:
                return False
            prev = (r, c)
    return all(x == 1 for x in cov)


def ascii_board(board):
    """Render a board: each word gets a letter id so you can see the snaking."""
    n = board["size"]
    grid = [["·"] * n for _ in range(n)]
    for i, wd in enumerate(board["words"]):
        ch = chr(ord("A") + i % 26)
        for (r, c) in wd["path"]:
            grid[r][c] = ch
    return "\n".join(" ".join(row) for row in grid)


# ── Dates ─────────────────────────────────────────────────────────────────────
def date_range(start_date, n, step):
    return [(start_date + datetime.timedelta(days=step * i)).isoformat()
            for i in range(n)]


def make_entry(board, date=None):
    return {"date": date, **board} if date else board


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
    ap.add_argument("--candidates", type=int, default=60,
                    help="snakiness tries per board — higher = snakier, slower (default 60)")
    ap.add_argument("--seed", type=int, default=None,
                    help="RNG seed. Default: 20260611 fresh, or derived from start date on append")
    ap.add_argument("--today", default=datetime.date.today().isoformat(),
                    help="fresh mode: anchor date YYYY-MM-DD (today)")
    ap.add_argument("--preview", type=int, default=2, help="ASCII-print this many boards")
    args = ap.parse_args()

    buckets = load_words()
    if args.append:
        boards, dated, label = _append(args, buckets)
    else:
        boards, dated, label = _fresh(args, buckets)

    assert all(verify(b) for b in boards if "size" in b), \
        "a non-tiling / bad-word board slipped through"

    # Stats + preview.
    snk = [board_snakiness([[tuple(c) for c in wd["path"]] for wd in b["words"]])
           for b in boards]
    wc = [len(b["words"]) for b in boards]
    ln = [len(wd["text"]) for b in boards for wd in b["words"]]
    print(f"\n{label}")
    print(f"  words/board: min {min(wc)} max {max(wc)} avg {sum(wc)/len(wc):.1f}")
    print(f"  word-length mix: {dict(sorted(collections.Counter(ln).items()))}")
    print(f"  snakiness/board: avg {sum(snk)/len(snk):.1f} (higher = more S-like)")
    print("  all boards verified: tile the 5x5 + valid real words")
    for b in boards[:args.preview]:
        print(f"\n  {b.get('date','(fallback)')}  "
              f"{[wd['text'] for wd in b['words']]}")
        print("    " + ascii_board(b).replace("\n", "\n    "))


def _fresh(args, buckets):
    rng = random.Random(args.seed if args.seed is not None else 20260611)
    today = datetime.date.fromisoformat(args.today)
    past = list(reversed(date_range(today - datetime.timedelta(days=1), args.past, -1)))
    future = date_range(today, args.future, 1)
    dated = past + future

    boards = []
    for d in dated:
        boards.append(make_entry(one_board(rng, buckets, args.candidates), d))
    for _ in range(args.fallbacks):
        boards.append(one_board(rng, buckets, args.candidates))

    json.dump(boards, open(OUT_PATH, "w", encoding="utf-8"), separators=(",", ":"))
    label = (f"Wrote {len(boards)} boards -> {OUT_PATH}\n"
             f"  dated: {len(dated)} ({args.past} past + {args.future} future), "
             f"undated fallbacks: {args.fallbacks}")
    return boards, dated, label


def _append(args, buckets):
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
    new_boards = [make_entry(one_board(rng, buckets, args.candidates), d) for d in new_dates]
    merged = existing + new_boards

    json.dump(merged, open(OUT_PATH, "w", encoding="utf-8"), separators=(",", ":"))
    label = (f"Appended {len(new_boards)} boards ({new_dates[0]} → {new_dates[-1]}) "
             f"-> {OUT_PATH}\n  pool was {len(existing)}, now {len(merged)} "
             f"(existing untouched)")
    return new_boards, new_dates, label


if __name__ == "__main__":
    main()
