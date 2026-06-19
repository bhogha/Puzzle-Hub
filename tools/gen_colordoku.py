#!/usr/bin/env python3
"""
gen_colordoku.py — generate the Colordoku (color-region Queens) daily puzzle pool.

Colordoku is the "Queens / Meowdoku" genre: an N×N board split into N coloured
regions. The solution places exactly one queen (a teal gem in Puzzle Hub) so that:
  - every ROW has exactly one queen,
  - every COLUMN has exactly one queen,
  - every COLOUR REGION has exactly one queen,
  - no two queens TOUCH — including diagonally (the LinkedIn-Queens / Meowdoku
    rule shown in the reference: "Queens cannot touch other Queens"). Two queens
    may share a long diagonal as long as they are not in adjacent cells.

Because one queen sits in every row and every column, the solution is a
permutation p[] (p[r] = the queen's column on row r). The only way two such
queens can be adjacent is on consecutive rows, so the no-touch rule reduces to
|p[r] - p[r+1]| >= 2 for every r.

The puzzle the player sees has NO givens — only the colour regions. We only ship
a board whose region layout yields a UNIQUE solution (the genre's "no guessing"
promise), verified by an exact-cover backtracking solver.

Output: datafiles/puzzles_colordoku.json — an array of
  { "date":"YYYY-MM-DD", "size":N,
    "regions":[N*N ints 0..N-1 row-major],     # colour-region id per cell
    "solution":[N*N ints 0/1 row-major] }       # 1 = queen in the unique solution

Selection at runtime mirrors the other puzzles: exact date match, else seed
fallback. Re-run any time to regenerate; deterministic given --seed/--today.

Usage:
  python3 tools/gen_colordoku.py                 # 30 past + 30 future, N=6
  python3 tools/gen_colordoku.py --size 6 --seed 20260616
"""

import argparse, datetime, json, os, random, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(HERE, "..", "datafiles", "puzzles_colordoku.json")


# ── Solution placement (one queen / row, / col, no touch) ─────────────────────
def random_solution(rng, n):
    """Return a permutation p[] (p[r]=col on row r) with |p[r]-p[r+1]|>=2, or None."""
    cols = list(range(n))
    rng.shuffle(cols)
    p = []

    def place(r):
        if r == n:
            return True
        for c in cols:
            if c in p:
                continue
            if r > 0 and abs(c - p[-1]) < 2:   # would touch the previous row's queen
                continue
            p.append(c)
            if place(r + 1):
                return True
            p.pop()
        return False

    return p[:] if place(0) else None


# ── Region growing (contiguous colour zones, one queen each) ──────────────────
def grow_regions(rng, n, p):
    """
    Partition the board into n contiguous regions, one seeded at each queen cell.
    Returns regions[r][c] in 0..n-1 (region id == the row of its queen).
    Growth prefers the smallest region's frontier, keeping zones balanced/snug.
    """
    region = [[-1] * n for _ in range(n)]
    sizes = [1] * n
    for r in range(n):
        region[r][p[r]] = r           # seed: queen cell -> region r

    unassigned = n * n - n
    while unassigned > 0:
        # Candidate moves: (region_id, (r,c)) for empty cells 4-adjacent to a region.
        cand = {}
        for r in range(n):
            for c in range(n):
                if region[r][c] != -1:
                    continue
                neigh = set()
                for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < n and 0 <= nc < n and region[nr][nc] != -1:
                        neigh.add(region[nr][nc])
                if neigh:
                    cand[(r, c)] = neigh
        if not cand:
            return None                # disconnected pocket (shouldn't happen on a grid)

        # Bias toward feeding the smallest adjacent region for balanced shapes.
        min_size = min(sizes)
        weighted = []
        for (r, c), neigh in cand.items():
            for rid in neigh:
                w = 4 if sizes[rid] == min_size else 1
                weighted += [((r, c), rid)] * w
        (r, c), rid = rng.choice(weighted)
        region[r][c] = rid
        sizes[rid] += 1
        unassigned -= 1
    return region


# ── Solver: count solutions of (regions only) up to a cap ─────────────────────
def count_solutions(n, region, cap=2):
    """Count placements satisfying row/col/region uniqueness + no-touch, capped."""
    found = 0
    used_col = [False] * n
    used_reg = [False] * n
    prev_col = [-1]

    def solve(r):
        nonlocal found
        if found >= cap:
            return
        if r == n:
            found += 1
            return
        for c in range(n):
            if used_col[c]:
                continue
            rid = region[r][c]
            if used_reg[rid]:
                continue
            if r > 0 and prev_col[0] != -1 and abs(c - prev_col[0]) < 2:
                continue
            used_col[c] = True
            used_reg[rid] = True
            save = prev_col[0]
            prev_col[0] = c
            solve(r + 1)
            prev_col[0] = save
            used_reg[rid] = False
            used_col[c] = False
            if found >= cap:
                return

    solve(0)
    return found


# ── One full board ────────────────────────────────────────────────────────────
def one_board(rng, n, region_tries=60):
    """Generate a uniquely-solvable Colordoku board; retries solutions/regions."""
    for _ in range(400):
        p = random_solution(rng, n)
        if p is None:
            continue
        for _ in range(region_tries):
            region = grow_regions(rng, n, p)
            if region is None:
                continue
            if count_solutions(n, region, cap=2) == 1:
                regions_flat = [region[r][c] for r in range(n) for c in range(n)]
                solution_flat = [1 if p[r] == c else 0
                                 for r in range(n) for c in range(n)]
                return regions_flat, solution_flat
    raise RuntimeError("failed to generate a unique board (raise tries)")


def make_entry(rng, n, date=None):
    regions, solution = one_board(rng, n)
    e = {"size": n, "regions": regions, "solution": solution}
    return {"date": date, **e} if date else e


def date_range(start, count, step):
    return [(start + datetime.timedelta(days=step * i)).isoformat() for i in range(count)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=6, help="board size N (N×N, N regions)")
    ap.add_argument("--past", type=int, default=30, help="dated days before today")
    ap.add_argument("--future", type=int, default=30, help="dated days from today on")
    ap.add_argument("--fallbacks", type=int, default=0, help="undated fallback boards")
    ap.add_argument("--seed", type=int, default=20260616)
    ap.add_argument("--today", default=datetime.date.today().isoformat())
    args = ap.parse_args()

    rng = random.Random(args.seed)
    today = datetime.date.fromisoformat(args.today)
    past = list(reversed(date_range(today - datetime.timedelta(days=1), args.past, -1)))
    future = date_range(today, args.future, 1)
    dated = past + future

    boards = [make_entry(rng, args.size, d) for d in dated]
    for _ in range(args.fallbacks):
        boards.append(make_entry(rng, args.size))

    json.dump(boards, open(OUT_PATH, "w", encoding="utf-8"), separators=(",", ":"))
    print(f"wrote {len(boards)} boards to {os.path.relpath(OUT_PATH)}  "
          f"(N={args.size}, {args.past} past + {args.future} future, "
          f"{args.fallbacks} fallbacks)")

    # Quick sanity report on the first board.
    b = boards[0]
    n = b["size"]
    print(f"sample {b['date']}:")
    palette = "ABCDEF"
    for r in range(n):
        row = ""
        for c in range(n):
            i = r * n + c
            ch = palette[b["regions"][i]]
            row += ("[" + ch + "]") if b["solution"][i] else (" " + ch + " ")
        print("  " + row)


if __name__ == "__main__":
    main()
