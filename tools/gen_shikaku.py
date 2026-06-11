#!/usr/bin/env python3
"""Shikaku board generator for Puzzle Hub — 9x9, unique solution.

Produces 9x9 Shikaku ("divide by squares") boards. The grid is partitioned into
rectangles; each rectangle carries one clue number equal to its area (cell count),
printed at one cell inside it. The `rects` list is BOTH the clue source and the
unique solution.

Uniqueness is enforced with a backtracking exact-cover solver. The key speed-up:
scanning cells row-major, the first still-empty cell must be the TOP-LEFT corner
of whatever rectangle covers it (everything above / to its left is already filled),
so each branch only enumerates rectangles anchored at that corner.

Output JSON entry shape (matches scr_shikaku.gml):
  { "date":"YYYY-MM-DD"(optional), "size":9,
    "rects":[ {"r":,"c":,"w":,"h":,"cr":,"cc":}, ... ] }
"""
import json, random, datetime

N = 9
AREA_MIN, AREA_MAX = 2, 9     # allowed rectangle areas (1x1 only if forced)
DIM_MAX = 5                   # max width / height of any rectangle


# ── Random rectangle partition (always full coverage) ─────────────────────────
def random_partition(rng):
    grid = [[-1] * N for _ in range(N)]   # rect id per cell
    rects = []                            # (r, c, w, h)
    for r in range(N):
        for c in range(N):
            if grid[r][c] != -1:
                continue
            # (r,c) is the top-left of a new rectangle: all cells above/left filled.
            options = []
            for w in range(1, min(DIM_MAX, N - c) + 1):
                if grid[r][c + w - 1] != -1:
                    break
                for h in range(1, min(DIM_MAX, N - r) + 1):
                    if any(grid[r + h - 1][c + cc] != -1 for cc in range(w)):
                        break
                    area = w * h
                    if AREA_MIN <= area <= AREA_MAX:
                        options.append((w, h))
            if not options:                       # forced single cell
                w, h = 1, 1
            else:
                # bias toward LARGER rectangles so boards have fewer, chunkier
                # pieces (avg area ~5-6 -> ~14-17 rects, comparable to the other
                # puzzles' piece counts) rather than many tiny ones.
                weights = [(w * h) ** 2 for (w, h) in options]
                w, h = rng.choices(options, weights=weights, k=1)[0]
            rid = len(rects)
            for rr in range(h):
                for cc in range(w):
                    grid[r + rr][c + cc] = rid
            rects.append((r, c, w, h))
    return rects


# ── Unique-solution check ─────────────────────────────────────────────────────
def count_solutions(clues, limit=2):
    """clues: list of (val, r, c). Count distinct rectangle partitions consistent
    with the clues (each rect exactly one clue, area == that clue's value), up to
    `limit`."""
    # prefix sum of clue presence for O(1) "clues inside rectangle" counts
    pref = [[0] * (N + 1) for _ in range(N + 1)]
    clue_val = {}
    for (v, r, c) in clues:
        pref[r + 1][c + 1] += 1
        clue_val[(r, c)] = v
    for r in range(1, N + 1):
        for c in range(1, N + 1):
            pref[r][c] += pref[r - 1][c] + pref[r][c - 1] - pref[r - 1][c - 1]

    def clues_in(r0, c0, w, h):
        r1, c1 = r0 + h, c0 + w
        return pref[r1][c1] - pref[r0][c1] - pref[r1][c0] + pref[r0][c0]

    grid = [[False] * N for _ in range(N)]
    used = {}

    def first_empty():
        for r in range(N):
            row = grid[r]
            for c in range(N):
                if not row[c]:
                    return (r, c)
        return None

    solutions = [0]

    def backtrack():
        if solutions[0] >= limit:
            return
        cell = first_empty()
        if cell is None:
            solutions[0] += 1
            return
        r, c = cell
        for w in range(1, N - c + 1):
            if grid[r][c + w - 1]:
                break
            for h in range(1, N - r + 1):
                if any(grid[r + h - 1][c + cc] for cc in range(w)):
                    break
                cnt = clues_in(r, c, w, h)
                if cnt == 0:
                    continue
                if cnt > 1:
                    break          # taller rects only add clues -> stop growing h
                # exactly one clue inside; find it
                found = None
                for rr in range(r, r + h):
                    for cc in range(c, c + w):
                        if (rr, cc) in clue_val:
                            found = (rr, cc)
                            break
                    if found:
                        break
                if used.get(found):
                    continue
                if clue_val[found] != w * h:
                    continue
                # place
                for rr in range(r, r + h):
                    for cc in range(c, c + w):
                        grid[rr][cc] = True
                used[found] = True
                backtrack()
                used[found] = False
                for rr in range(r, r + h):
                    for cc in range(c, c + w):
                        grid[rr][cc] = False
                if solutions[0] >= limit:
                    return
        return

    backtrack()
    return solutions[0]


# ── Build one unique board ────────────────────────────────────────────────────
def gen_board(rng):
    for _ in range(300):
        rects = random_partition(rng)
        # reject boring boards: too few rects or too many 1x1 clues
        ones = sum(1 for (r, c, w, h) in rects if w * h == 1)
        if len(rects) < 13 or len(rects) > 18 or ones > 1:
            continue
        # try a few random clue-position assignments for uniqueness
        for _try in range(6):
            clues = []
            placed = []
            for (r, c, w, h) in rects:
                cr = rng.randrange(r, r + h)
                cc = rng.randrange(c, c + w)
                clues.append((w * h, cr, cc))
                placed.append({"r": r, "c": c, "w": w, "h": h, "cr": cr, "cc": cc})
            if count_solutions(clues, limit=2) == 1:
                return placed
    raise RuntimeError("could not generate a unique board")


def date_keys(start, count):
    y, m, d = map(int, start.split("-"))
    base = datetime.date(y, m, d)
    return [(base + datetime.timedelta(days=i)).isoformat() for i in range(count)]


def main():
    rng = random.Random(20260611)
    pool = []
    for dk in date_keys("2026-06-11", 30):       # curated launch month
        b = {"date": dk, "size": N, "rects": gen_board(rng)}
        pool.append(b)
    for _ in range(30):                           # undated seed-fallback pool
        pool.append({"size": N, "rects": gen_board(rng)})
    with open("puzzles_shikaku.json", "w") as f:
        json.dump(pool, f, separators=(",", ":"))
    counts = [len(b["rects"]) for b in pool]
    print(f"wrote {len(pool)} boards -> puzzles_shikaku.json")
    print(f"rects/board: min {min(counts)} max {max(counts)} "
          f"avg {sum(counts)/len(counts):.1f}")
    # final verification pass: every board unique + full coverage
    for b in pool:
        cov = [[0] * N for _ in range(N)]
        for rc in b["rects"]:
            for rr in range(rc["h"]):
                for cc in range(rc["w"]):
                    cov[rc["r"] + rr][rc["c"] + cc] += 1
        assert all(cov[r][c] == 1 for r in range(N) for c in range(N)), "coverage!"
        clues = [(rc["w"] * rc["h"], rc["cr"], rc["cc"]) for rc in b["rects"]]
        assert count_solutions(clues, limit=2) == 1, "non-unique board slipped through"
    print("all boards verified: full coverage + unique solution")


if __name__ == "__main__":
    main()
