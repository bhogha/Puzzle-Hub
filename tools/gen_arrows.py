#!/usr/bin/env python3
"""Arrows – Puzzle Escape board generator for Puzzle Hub (v2 "weave" algorithm).

Design goals (2026-06-11 redesign): boards should read as a dense WEAVE of long,
winding arrows — lots of bends, very few short arrows, no trivial 2-cell arrows
sitting at the board edge, and as little empty space as possible.

Model (unchanged, matches scr_arrows.gml): each arrow is a connected orthogonal
path of cells with the arrowhead at cells[0] (TIP); the head direction is the
direction from cells[1] to cells[0]. Tapping launches the arrow snake-style;
it exits iff the straight LANE from its tip to the board edge is clear of every
other arrow. Solvability is guaranteed by REVERSE construction: every arrow's
lane is clear of all EARLIER-placed cells at placement time, so solving in
reverse placement order always clears the board.

v2 algorithm — why it produces nicer boards than v1:
  1. BEND-BIASED SNAKE GROWTH: arrows are grown as random walks that prefer to
     turn (bend_p), giving the curvy, woven look. Minimum length is 3 — the
     2-cell mop-up arrows of v1 are gone entirely.
  2. HEAD CHOICE AT EITHER END: a grown path tries both of its ends as the tip
     and prefers a tip whose exit lane is LONGEST — tips that sit on the edge
     pointing straight off the board (lane 0 == instantly free) are avoided
     whenever any alternative exists.
  3. DIRECTED HOLE FILLING: remaining holes seed new snakes grown out of the
     hole itself (min 3 cells), not dropped 2-cell dominoes.
  4. TAIL EXTENSION: leftover empty cells adjacent to an arrow's TAIL are
     absorbed into that arrow (lengthening it), with an index-aware safety
     check so reverse-solvability is preserved: a cell may join arrow k only if
     it is not on arrow k's own lane nor on the lane of any arrow placed AFTER
     k (their lanes must stay clear of cells that are still present when they
     are solved).
  5. BOARD SCORING: many candidate boards are packed and the best is kept —
     maximise fill and bends, reward long arrows, punish short arrows,
     edge-pointing tips (lane 0) and arrows that are free on the very first
     move.

Output JSON entry shape (matches scr_arrows.gml):
  { "date":"YYYY-MM-DD"(optional), "rows":19, "cols":14,
    "arrows":[ { "head":"R", "cells":[[r,c],[r,c], ...] }, ... ] }
"""
import json, random, datetime

ROWS, COLS = 19, 14
DIRS = {"U": (-1, 0), "D": (1, 0), "L": (0, -1), "R": (0, 1)}
DIR_KEYS = list(DIRS.keys())
BEND_P = 0.62          # probability of preferring a turn over going straight


def in_board(r, c):
    return 0 <= r < ROWS and 0 <= c < COLS


def ray(tip, head):
    """All cells on the straight exit lane from `tip` (exclusive) to the edge."""
    dr, dc = DIRS[head]
    r, c = tip[0] + dr, tip[1] + dc
    out = []
    while in_board(r, c):
        out.append((r, c))
        r += dr; c += dc
    return out


def head_dir(a, b):
    """Direction key pointing from cell b to cell a (a = tip, b = behind tip)."""
    dr, dc = a[0] - b[0], a[1] - b[1]
    for k, (kr, kc) in DIRS.items():
        if (kr, kc) == (dr, dc):
            return k
    return None


def grow_snake(empties, start, target, bend_p=BEND_P):
    """Grow a winding path of empty cells from `start`, preferring turns."""
    path = [start]
    used = {start}
    prev = None
    while len(path) < target:
        r, c = path[-1]
        cand = []
        for k, (dr, dc) in DIRS.items():
            nr, nc = r + dr, c + dc
            if (nr, nc) in empties and (nr, nc) not in used:
                cand.append((k, (nr, nc)))
        if not cand:
            break
        turns    = [x for x in cand if prev is not None and x[0] != prev]
        straight = [x for x in cand if prev is None or x[0] == prev]
        if turns and (not straight or random.random() < bend_p):
            k, nxt = random.choice(turns)
        else:
            k, nxt = random.choice(straight or turns)
        path.append(nxt); used.add(nxt); prev = k
    return path


def pick_head(path, occ, allow_lane0=True):
    """Try both ends of `path` as the tip; return (cells, head) with cells[0]=tip,
    preferring the LONGEST clear exit lane (lane 0 only as a last resort)."""
    options = []
    for cells in (path, path[::-1]):
        if len(cells) < 2:
            continue
        h = head_dir(cells[0], cells[1])
        lane = ray(cells[0], h)
        if not lane and not allow_lane0:
            continue
        if any(p in occ for p in lane) or any(p in cells for p in lane):
            continue
        options.append((len(lane), cells, h))
    if not options:
        return None
    options.sort(key=lambda o: -o[0])           # longest lane first
    lane_len, cells, h = options[0]
    return cells, h


def pack_once():
    empties = {(r, c) for r in range(ROWS) for c in range(COLS)}
    occ = set()
    arrows = []          # [{head, cells}], placement index == list index
    lanes = []           # per-arrow frozen exit-lane cells

    def commit(cells, h):
        for p in cells:
            empties.discard(p); occ.add(p)
        arrows.append({"head": h, "cells": [list(p) for p in cells]})
        lanes.append(set(ray(cells[0], h)))

    def place(target_fn, max_fails, min_len, max_place=None, chain_p=0.95):
        """Pack snakes. With probability chain_p a snake is grown FROM a cell on
        a currently-free arrow's lane, so it blocks that arrow. Since the free
        set at any construction prefix IS the available-move set when the solve
        reaches that point, this keeps the whole solve narrow (few legal moves
        at every moment), not just the opening position."""
        fails = placed = 0
        while fails < max_fails and empties:
            if max_place is not None and placed >= max_place:
                break
            targets = free_lane_cells()
            if targets and random.random() < chain_p:
                start = random.choice(tuple(targets))
            else:
                start = random.choice(tuple(empties))
            path = grow_snake(empties, start, target_fn())
            if len(path) < min_len:
                fails += 1; continue
            pick = pick_head(path, occ, allow_lane0=False)
            if pick is None:
                fails += 1; continue
            commit(*pick); placed += 1; fails = 0

    def free_lane_map():
        """empty cell -> set of CURRENTLY-free arrow indices whose lane crosses
        it. Covering such a cell blocks that arrow — the main lever for narrow
        solve chains (few simultaneously-available moves)."""
        cellmap = {}
        for i in range(len(arrows)):
            lane_empty = [p for p in lanes[i] if p in empties]
            if lanes[i] and len(lane_empty) == len(lanes[i]):   # whole lane empty -> free
                for p in lane_empty:
                    cellmap.setdefault(p, set()).add(i)
        return cellmap

    def free_lane_cells():
        return set(free_lane_map())

    def block_free_arrows(rounds=40, min_cover=2):
        """Grow snakes THROUGH the lanes of currently-free arrows so they stop
        being free. A blocker is itself free when placed (net zero), so commit
        only snakes choking >= min_cover free lanes at once. Coverage-greedy:
        sample several candidates per round, keep the best."""
        fails = 0
        while fails < rounds:
            cellmap = free_lane_map()
            if not cellmap:
                break
            best = None
            for _ in range(25):
                start = random.choice(tuple(cellmap))
                path = grow_snake(empties, start, random.randint(4, 9))
                if len(path) < 3:
                    continue
                pick = pick_head(path, occ, allow_lane0=False)
                if pick is None:
                    continue
                cover = len({i for p in path for i in cellmap.get(p, ())})
                if best is None or cover > best[0]:
                    best = (cover, pick)
            if best is None or best[0] < min_cover:
                fails += 1
                continue
            commit(*best[1])
            fails = 0

    def fill_holes(min_len=3):
        """Seed new snakes out of every remaining hole, free-arrow lanes first.
        Edge-pointing (lane-0) tips are refused — they would be free forever."""
        changed = True
        while changed:
            changed = False
            ordered = list(free_lane_cells()) + list(empties)
            for cell in ordered:
                if cell not in empties:
                    continue
                path = grow_snake(empties, cell, random.randint(min_len, 6))
                if len(path) < min_len:
                    continue
                pick = pick_head(path, occ, allow_lane0=False)
                if pick is not None:
                    commit(*pick); changed = True

    def extend_tails():
        """Absorb leftover empty cells into adjacent arrow TAILS.
        Safety: new cell must avoid the arrow's own lane and the lane of every
        arrow placed AFTER it (reverse-solve order property)."""
        changed = True
        while changed:
            changed = False
            targets = free_lane_cells()
            for k, a in enumerate(arrows):
                tail = tuple(a["cells"][-1])
                nbrs = [(tail[0] + d[0], tail[1] + d[1]) for d in DIRS.values()]
                random.shuffle(nbrs)
                nbrs.sort(key=lambda p: 0 if p in targets else 1)   # block free arrows first
                for p in nbrs:
                    if p not in empties:
                        continue
                    if p in lanes[k] or any(p in lanes[j] for j in range(k + 1, len(arrows))):
                        continue
                    a["cells"].append(list(p))
                    empties.discard(p); occ.add(p)
                    changed = True
                    break

    # Phase A: a few long winding feature arrows while the board is open.
    place(lambda: random.randint(12, 17), 80, min_len=9, max_place=random.randint(3, 4))
    # Phase B: medium snakes pack the bulk of the board (more arrows = more taps,
    # and more arrows per lane = deeper blocking chains).
    place(lambda: random.randint(4, 8), 400, min_len=4)
    # Phase C: alternate choking the free arrows (while space still exists for
    # blockers) with density passes. Late arrows can only be blocked by even
    # later ones, so blocking runs again after every fill.
    block_free_arrows()
    fill_holes(min_len=3)
    block_free_arrows()
    extend_tails()
    fill_holes(min_len=3)        # extension may have re-opened reachable spots
    block_free_arrows()
    extend_tails()
    return arrows


def bends(cells):
    n = 0
    for i in range(2, len(cells)):
        d1 = (cells[i-1][0] - cells[i-2][0], cells[i-1][1] - cells[i-2][1])
        d2 = (cells[i][0] - cells[i-1][0], cells[i][1] - cells[i-1][1])
        if d1 != d2:
            n += 1
    return n


def solve_width(arrows, playouts=3):
    """Difficulty probe over random feasible solves. Returns:
      width    — avg number of LEGAL moves available per step (low = hunt = hard)
      blockers — avg distinct arrows on each initial lane (deep chains = hard)
      free_len — avg exit-lane LENGTH of the free arrows across the solve
                 (a free arrow whose tip is 2 cells from the edge is verified at
                 a glance; a 10-cell clear lane must be scanned — hunt cost)
      wide     — fraction of solve steps with >=4 legal moves (easy stretches)"""
    cells = [[tuple(c) for c in a["cells"]] for a in arrows]
    lanes = [ray(cells[i][0], arrows[i]["head"]) for i in range(len(arrows))]
    owner = {p: i for i, cs in enumerate(cells) for p in cs}
    blk = [len({owner[p] for p in lanes[i] if p in owner and owner[p] != i})
           for i in range(len(arrows))]
    widths, flens, wides = [], [], []
    for _ in range(playouts):
        alive = set(range(len(arrows)))
        w, fl, wd = [], [], 0
        while alive:
            occ = {p: i for i in alive for p in cells[i]}
            free = [i for i in alive if all(occ.get(p, i) == i for p in lanes[i])]
            if not free:
                return 99.0, 0.0, 0.0, 1.0   # unsolvable playout (should not happen)
            w.append(len(free))
            fl += [len(lanes[i]) for i in free]
            if len(free) >= 4:
                wd += 1
            alive.discard(random.choice(free))
        widths.append(sum(w) / len(w))
        flens.append(sum(fl) / len(fl))
        wides.append(wd / len(w))
    return (sum(widths) / len(widths), sum(blk) / len(blk),
            sum(flens) / len(flens), sum(wides) / len(wides))


def board_metrics(arrows):
    occ_by = {}
    for i, a in enumerate(arrows):
        for c in a["cells"]:
            occ_by[tuple(c)] = i
    fill = len(occ_by)
    lane0 = init_free = 0
    for i, a in enumerate(arrows):
        lane = ray(tuple(a["cells"][0]), a["head"])
        if not lane:
            lane0 += 1
        if all(occ_by.get(p, i) == i for p in lane):
            init_free += 1
    shorts = sum(1 for a in arrows if len(a["cells"]) <= 3)
    longs  = sum(1 for a in arrows if len(a["cells"]) >= 10)
    curve  = sum(bends(a["cells"]) for a in arrows)
    return fill, lane0, init_free, shorts, longs, curve


def gen_board(attempts=40):
    best, best_score = None, -1e18
    for _ in range(attempts):
        arrows = pack_once()
        fill, lane0, init_free, shorts, longs, curve = board_metrics(arrows)
        width, blockers, free_len, wide = solve_width(arrows)
        score = (fill * 5 + curve * 0.5 + longs * 2
                 + blockers * 25 + free_len * 10
                 - width * 60 - wide * 120 - init_free * 15
                 - lane0 * 12 - shorts * 4)
        if score > best_score:
            best, best_score = arrows, score
    return {"rows": ROWS, "cols": COLS, "arrows": best}


def greedy_solvable(arrows):
    remaining = list(range(len(arrows)))
    cells = [[tuple(c) for c in a["cells"]] for a in arrows]
    while remaining:
        progressed = False
        for i in list(remaining):
            others = {p for j in remaining if j != i for p in cells[j]}
            if not any(p in others for p in ray(cells[i][0], arrows[i]["head"])):
                remaining.remove(i); progressed = True
        if not progressed:
            return False
    return True


def date_keys(start, count):
    y, m, d = map(int, start.split("-"))
    base = datetime.date(y, m, d)
    return [(base + datetime.timedelta(days=i)).isoformat() for i in range(count)]


def main():
    import sys
    # Optional chunked mode: gen_arrows.py <chunk_idx> <n_chunks> writes
    # puzzles_arrows.part<i>.json (merge the parts afterwards). No args = full run.
    chunk, n_chunks = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) == 3 else (0, 1)
    slots = [("date", dk) for dk in date_keys("2026-06-11", 30)] + [(None, None)] * 30
    random.seed(20260612 + chunk * 977)
    pool = []
    for si in range(chunk, len(slots), n_chunks):
        b = gen_board()
        if slots[si][0] == "date":
            b["date"] = slots[si][1]
        pool.append(b)
    out = "puzzles_arrows.json" if n_chunks == 1 else f"puzzles_arrows.part{chunk}.json"
    with open(out, "w") as f:
        json.dump(pool, f, separators=(",", ":"))
    if n_chunks > 1:
        assert all(greedy_solvable(b["arrows"]) for b in pool), "unsolvable board slipped through"
        print(f"chunk {chunk}/{n_chunks}: {len(pool)} boards -> {out} (all solvable)")
        return

    cells_tot = ROWS * COLS
    sizes  = [len(b["arrows"]) for b in pool]
    fills  = [sum(len(a["cells"]) for a in b["arrows"]) for b in pool]
    lens   = [len(a["cells"]) for b in pool for a in b["arrows"]]
    m      = [board_metrics(b["arrows"]) for b in pool]
    print(f"wrote {len(pool)} boards ({ROWS}x{COLS}={cells_tot} cells) -> puzzles_arrows.json")
    print(f"arrows/board: min {min(sizes)} max {max(sizes)} avg {sum(sizes)/len(sizes):.1f}")
    print(f"fill: min {min(fills)} max {max(fills)} avg {sum(fills)/len(fills):.1f} "
          f"({sum(fills)/len(fills)/cells_tot*100:.0f}%)")
    print(f"length: min {min(lens)} max {max(lens)} avg {sum(lens)/len(lens):.1f}")
    print(f"per board avg: long(>=10) {sum(x[4] for x in m)/len(m):.1f}  "
          f"short(<=3) {sum(x[3] for x in m)/len(m):.1f}  "
          f"lane0 tips {sum(x[1] for x in m)/len(m):.1f}  "
          f"free at start {sum(x[2] for x in m)/len(m):.1f}  "
          f"bends {sum(x[5] for x in m)/len(m):.0f}")
    sw = [solve_width(b["arrows"]) for b in pool]
    print(f"difficulty: avg available moves {sum(x[0] for x in sw)/len(sw):.1f}  "
          f"avg blockers/lane {sum(x[1] for x in sw)/len(sw):.2f}  "
          f"free-lane len {sum(x[2] for x in sw)/len(sw):.1f}  "
          f"wide steps {sum(x[3] for x in sw)/len(sw)*100:.0f}%")
    assert all(greedy_solvable(b["arrows"]) for b in pool), "unsolvable board slipped through"
    print("all boards verified solvable (tip-lane rule)")


if __name__ == "__main__":
    main()
