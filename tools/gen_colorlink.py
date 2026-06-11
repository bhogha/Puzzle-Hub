#!/usr/bin/env python3
"""Color Link (Flow Free) board generator for Puzzle Hub — 12x9 (rows x cols).

Method (matches the documented approach, on a non-square ROWS x COLS board): build
a random Hamiltonian path that visits every one of the ROWS*COLS cells, then cut it
into K contiguous segments. Each segment becomes one flow — its two ends are the
endpoint dots and its cells are the solution path. Because the segments are
slices of a single board-filling path they always tile the board with no gaps or
overlaps, so the puzzle is guaranteed solvable.

The board is taller than it is wide (12 rows x 9 cols) so it fills the portrait
play area to the top. K is kept at 7-8 (the most "dot pairs" the 8-colour palette
allows without colour reuse) so the bigger board carries more flows.

Output JSON entry shape (matches scr_colorlink.gml):
  { "date":"YYYY-MM-DD"(optional), "rows":12, "cols":9,
    "flows":[ {"color":i,"a":[r,c],"b":[r,c],"path":[[r,c],...]}, ... ] }
"""
import json, random, datetime, sys

ROWS, COLS = 12, 9
NCELLS = ROWS * COLS
FLOWS_MIN, FLOWS_MAX = 9, 10     # more (shorter) flows = more dot pairs, easier solve
SEG_MIN = 4                       # min cells per flow (avoid trivial short flows)
SEG_MAX = 15                      # cap so no single flow snakes across the whole board

sys.setrecursionlimit(10000)
DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]


def neighbors(r, c):
    for dr, dc in DIRS:
        nr, nc = r + dr, c + dc
        if 0 <= nr < ROWS and 0 <= nc < COLS:
            yield nr, nc


def initial_snake():
    """A boustrophedon (snake) Hamiltonian path covering every cell."""
    path = []
    for r in range(ROWS):
        cols = range(COLS) if r % 2 == 0 else range(COLS - 1, -1, -1)
        for c in cols:
            path.append((r, c))
    return path


def hamiltonian_path(rng, iters=5000):
    """Random Hamiltonian path via the BACKBITE algorithm: from a snake path,
    repeatedly take an endpoint, pick a random grid-neighbour w of it that lies
    earlier in the path, and reverse the tail past w. Each move maps one
    Hamiltonian path to another, so it never fails and mixes quickly."""
    path = initial_snake()
    for _ in range(iters):
        if rng.random() < 0.5:
            path.reverse()                     # operate on either end
        end = path[-1]
        nbrs = [(end[0] + dr, end[1] + dc) for dr, dc in DIRS]
        nbrs = [(r, c) for r, c in nbrs if 0 <= r < ROWS and 0 <= c < COLS]
        w = rng.choice(nbrs)
        j = path.index(w)
        if j >= len(path) - 2:                  # w is already the adjacent cell -> no-op
            continue
        path = path[:j + 1] + path[j + 1:][::-1]
    return path


def cut_lengths(total, k, lo, hi, rng):
    """Random composition of `total` into k parts, each in [lo, hi]."""
    if total < lo * k or total > hi * k:
        raise ValueError("total out of range for k parts")
    while True:
        # start each part at lo, distribute the remainder randomly (respecting hi)
        parts = [lo] * k
        rem = total - lo * k
        ok = True
        for _ in range(rem):
            choices = [i for i in range(k) if parts[i] < hi]
            if not choices:
                ok = False
                break
            parts[rng.choice(choices)] += 1
        if ok:
            return parts


def gen_board(rng):
    path = hamiltonian_path(rng)
    k = rng.randint(FLOWS_MIN, FLOWS_MAX)
    lengths = cut_lengths(NCELLS, k, SEG_MIN, SEG_MAX, rng)
    flows = []
    idx = 0
    for i, L in enumerate(lengths):
        seg = path[idx:idx + L]
        idx += L
        flows.append({
            "color": i,
            "a": [seg[0][0], seg[0][1]],
            "b": [seg[-1][0], seg[-1][1]],
            "path": [[r, c] for (r, c) in seg],
        })
    return {"rows": ROWS, "cols": COLS, "flows": flows}


# ── Verification (mirrors ph_colorlink_is_solved) ─────────────────────────────
def verify(board):
    rows, cols = board["rows"], board["cols"]
    cov = [-1] * (rows * cols)
    for f, fl in enumerate(board["flows"]):
        p = fl["path"]
        if len(p) < 2:
            return False
        a = fl["a"][0] * cols + fl["a"][1]
        b = fl["b"][0] * cols + fl["b"][1]
        first = p[0][0] * cols + p[0][1]
        last = p[-1][0] * cols + p[-1][1]
        if not ((first == a and last == b) or (first == b and last == a)):
            return False
        for i, (r, c) in enumerate(p):
            ci = r * cols + c
            if cov[ci] != -1:
                return False
            cov[ci] = f
            if i > 0:
                pr, pc = p[i - 1]
                if abs(r - pr) + abs(c - pc) != 1:
                    return False
    return all(x != -1 for x in cov)


def date_keys(start, count):
    y, m, d = map(int, start.split("-"))
    base = datetime.date(y, m, d)
    return [(base + datetime.timedelta(days=i)).isoformat() for i in range(count)]


def main():
    rng = random.Random(20260611)
    pool = []
    for dk in date_keys("2026-06-11", 30):
        b = gen_board(rng)
        b["date"] = dk
        pool.append(b)
    for _ in range(30):
        pool.append(gen_board(rng))
    assert all(verify(b) for b in pool), "an unsolvable / non-tiling board slipped through"
    with open("puzzles_colorlink.json", "w") as f:
        json.dump(pool, f, separators=(",", ":"))
    fc = [len(b["flows"]) for b in pool]
    ln = [len(fl["path"]) for b in pool for fl in b["flows"]]
    print(f"wrote {len(pool)} boards -> puzzles_colorlink.json")
    print(f"flows/board: min {min(fc)} max {max(fc)} avg {sum(fc)/len(fc):.1f}")
    print(f"flow length: min {min(ln)} max {max(ln)} avg {sum(ln)/len(ln):.1f}")
    print("all boards verified: tile the board + valid endpoints/contiguity")


if __name__ == "__main__":
    main()
