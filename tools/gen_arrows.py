#!/usr/bin/env python3
"""Arrows – Puzzle Escape board generator for Puzzle Hub.

Produces always-solvable 8x8 boards of bent, multi-cell "snake" arrows.

Model: each arrow is a connected orthogonal path of cells with an arrowhead at
cells[0] (the TIP) pointing one of 4 directions (U/D/L/R). cells[1] is the cell
directly behind the tip (opposite the head direction), so the head points `head`
and the tip is always the frontmost cell.

Movement (matches the source game): tapping launches the arrow SNAKE-STYLE — the
tip travels straight out in the head direction and the rest of the body follows
its own trail, head-first, off the board. So the only cells that must be clear
are the straight LANE in front of the tip (from tip+dir to the board edge); the
body slithers through cells the arrow already occupied. An arrow can exit iff
that tip-lane is clear of every OTHER arrow.

Solvability is guaranteed by REVERSE construction: arrows are placed one at a
time onto an empty grid; a new arrow is only committed if its tip-lane is clear
of all already-placed cells AND of its own body (so the tip stays frontmost).
The forward solution order is the reverse of the placement order, so a full
clear always exists; a greedy forward solver double-checks each board. Because
removing an arrow only frees cells, the player can never get stuck.
"""
import json, random

N = 9
DIRS = {"U": (-1, 0), "D": (1, 0), "L": (0, -1), "R": (0, 1)}

def tip_lane_clear(cells, head, blocked):
    """True if the straight lane in front of the tip (cells[0]) to the board
    edge contains no cell in `blocked`."""
    dr, dc = DIRS[head]
    r, c = cells[0][0] + dr, cells[0][1] + dc
    while 0 <= r < N and 0 <= c < N:
        if (r, c) in blocked:
            return False
        r += dr; c += dc
    return True

def try_make_arrow(grid, length, head):
    """Grow a candidate arrow of up to `length` cells with the given head dir.
    Body grows backward from the tip (cells[1] = tip - dir), then bends freely."""
    dr, dc = DIRS[head]
    empties = [(r, c) for r in range(N) for c in range(N) if grid[r][c] is None]
    random.shuffle(empties)
    for (hr, hc) in empties:
        br, bc = hr - dr, hc - dc            # cell directly behind the tip
        if not (0 <= br < N and 0 <= bc < N) or grid[br][bc] is not None:
            continue
        cells = [(hr, hc), (br, bc)]
        used = set(cells)
        cur = (br, bc)
        for _ in range(length - 2):
            nbrs = [(cur[0] + d[0], cur[1] + d[1]) for d in DIRS.values()]
            random.shuffle(nbrs)
            nxt = None
            for (nr, nc) in nbrs:
                if 0 <= nr < N and 0 <= nc < N and grid[nr][nc] is None and (nr, nc) not in used:
                    nxt = (nr, nc); break
            if nxt is None:
                break
            cells.append(nxt); used.add(nxt); cur = nxt
        if len(cells) >= 2:
            return cells
    return None

def occupied_set(arrows):
    s = set()
    for a in arrows:
        for c in a["cells"]:
            s.add(tuple(c))
    return s

def greedy_solvable(arrows):
    """Forward check: repeatedly remove any arrow whose tip-lane is currently
    clear of every other remaining arrow."""
    remaining = list(range(len(arrows)))
    while remaining:
        progressed = False
        for i in list(remaining):
            others = set()
            for j in remaining:
                if j == i:
                    continue
                for c in arrows[j]["cells"]:
                    others.add(tuple(c))
            cells = [tuple(c) for c in arrows[i]["cells"]]
            if tip_lane_clear(cells, arrows[i]["head"], others):
                remaining.remove(i); progressed = True
        if not progressed:
            return False
    return True

def pack_once():
    """Pack arrows onto an empty board until no more can be placed. Each arrow is
    committed only if its tip-lane is clear of every already-placed cell AND its
    own body, so the placement order reversed is always a valid solve order (the
    board is solvable by construction). Returns the arrow list."""
    grid = [[None] * N for _ in range(N)]
    arrows = []
    fails = 0
    while fails < 250:
        # Bias toward medium arrows but allow 2-cell arrows to mop up leftover
        # gaps so the board fills as densely as possible.
        length = random.choices([2, 3, 4, 5, 6], weights=[1, 4, 4, 3, 2])[0]
        head = random.choice(list(DIRS.keys()))
        cand = try_make_arrow(grid, length, head)
        if cand is None:
            fails += 1
            continue
        blocked = occupied_set(arrows) | set(cand)
        if tip_lane_clear(cand, head, blocked):
            for (r, c) in cand:
                grid[r][c] = len(arrows)
            arrows.append({"head": head, "cells": [[r, c] for (r, c) in cand]})
            fails = 0
        else:
            fails += 1
    return arrows


def gen_board(attempts=120):
    """Generate the DENSEST solvable board found over many packing attempts
    ("fill the board with arrows as much as possible")."""
    best, best_fill = None, -1
    for _ in range(attempts):
        arrows = pack_once()
        if len(arrows) < 8 or not greedy_solvable(arrows):
            continue
        fill = sum(len(a["cells"]) for a in arrows)
        if fill > best_fill:
            best, best_fill = arrows, fill
    if best is None:
        raise RuntimeError("could not generate a board")
    return {"size": N, "arrows": best}

def date_keys(start, count):
    import datetime
    y, m, d = map(int, start.split("-"))
    base = datetime.date(y, m, d)
    return [(base + datetime.timedelta(days=i)).isoformat() for i in range(count)]

def main():
    random.seed(20260611)
    dated_keys = date_keys("2026-06-11", 30)   # curated launch month
    pool = []
    for dk in dated_keys:
        b = gen_board(); b["date"] = dk; pool.append(b)
    for _ in range(30):                          # undated seed-fallback pool
        pool.append(gen_board())
    with open("puzzles_arrows.json", "w") as f:
        json.dump(pool, f, separators=(",", ":"))
    sizes = [len(b["arrows"]) for b in pool]
    cells = [sum(len(a["cells"]) for a in b["arrows"]) for b in pool]
    print(f"wrote {len(pool)} boards -> puzzles_arrows.json")
    print(f"arrows/board: min {min(sizes)} max {max(sizes)} avg {sum(sizes)/len(sizes):.1f}")
    print(f"filled cells/board: min {min(cells)} max {max(cells)} avg {sum(cells)/len(cells):.1f} ({sum(cells)/len(cells)/(N*N)*100:.0f}%)")
    assert all(greedy_solvable(b["arrows"]) for b in pool), "unsolvable board slipped through"
    print("all boards verified solvable (tip-lane rule)")
    print("sample board[0]:", json.dumps(pool[0]["arrows"], separators=(",", ":")))

if __name__ == "__main__":
    main()
