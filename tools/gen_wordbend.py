#!/usr/bin/env python3
"""Word Bend board generator for Puzzle Hub — 9x9, fully tiled with words.

Word Bend requires the whole board to be covered by hidden words whose orthogonal
(bending) cell-paths tile the grid exactly once. Because the player finds a word by
tracing its exact cell-path (the match is geometric, not letter-based — see
ph_wordbend_match), ANY real word of the right length can fill a given path.

So generation is two clean steps:
  1. Build a random Hamiltonian path over the 9x9 (backbite algorithm) and cut it
     into contiguous snake segments of length 3..7. Each segment is a simple
     orthogonal path that may bend — exactly a Word Bend word path. The segments
     tile the board, so it is always fully solvable.
  2. Assign each segment a DISTINCT real word of its length, drawn from the curated
     Level Editors word bank (common, recognisable words).

Lengths are capped at 7 because the word bank only has a handful of 8-9 letter
words; the bulk land at 4-6, giving ~14-18 words per board (the requested
"balanced mix").

Output JSON entry shape (matches scr_wordbend.gml):
  { "date":"YYYY-MM-DD"(optional), "size":9,
    "words":[ {"text":"WORD","path":[[r,c],...]}, ... ] }
"""
import json, random, datetime, os, re

N = 9
NCELLS = N * N
LEN_MIN, LEN_MAX = 3, 7
DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]


# ── Word bank ─────────────────────────────────────────────────────────────────
def load_words():
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(here, "..", "..", "Level Editors", "Word List.txt"),
        os.path.join(here, "..", "..", "Daily Puzzle", "Level Editors", "Word List.txt"),
        "/sessions/tender-festive-ramanujan/mnt/Daily Puzzle/Level Editors/Word List.txt",
    ]
    path = next((p for p in candidates if os.path.exists(p)), None)
    if path is None:
        raise FileNotFoundError("Word List.txt not found in: " + " | ".join(candidates))
    raw = open(path).read()
    toks = re.split(r"[,\s]+", raw)
    words = [t.strip().upper() for t in toks if t.strip()]
    words = [w for w in words if w.isalpha() and LEN_MIN <= len(w) <= LEN_MAX]
    # The curated list has a few typos (WHISTL, WINSOM, COMPAC, LIQUD, FOURNY, ...).
    # Since the letters are shown on the board, validate every word against a real
    # English dictionary (offline pyspellchecker) and drop anything misspelled.
    from spellchecker import SpellChecker
    sp = SpellChecker()
    buckets = {L: [] for L in range(LEN_MIN, LEN_MAX + 1)}
    seen = set()
    dropped = []
    for w in words:
        if w in seen:
            continue
        seen.add(w)
        if w.lower() not in sp:
            dropped.append(w)
            continue
        buckets[len(w)].append(w)
    if dropped:
        print(f"dropped {len(dropped)} misspelled entries, e.g. {dropped[:8]}")
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


def cut_lengths(total, lo, hi, rng):
    for _ in range(200):
        parts, rem = [], total
        ok = True
        while rem > 0:
            choices = [L for L in range(lo, hi + 1)
                       if L <= rem and (rem - L == 0 or rem - L >= lo)]
            if not choices:
                ok = False
                break
            # mild bias toward the middle so the mix stays balanced
            weights = [3 if 4 <= L <= 6 else 1 for L in choices]
            L = rng.choices(choices, weights=weights, k=1)[0]
            parts.append(L)
            rem -= L
        if ok:
            rng.shuffle(parts)
            return parts
    raise RuntimeError("could not compose segment lengths")


def gen_board(rng, buckets):
    path = hamiltonian_path(rng)
    lengths = cut_lengths(NCELLS, LEN_MIN, LEN_MAX, rng)
    # pre-shuffle word pools per board so words are distinct within the board
    avail = {L: buckets[L][:] for L in buckets}
    for L in avail:
        rng.shuffle(avail[L])
    words = []
    idx = 0
    for L in lengths:
        seg = path[idx:idx + L]
        idx += L
        if not avail[L]:
            return None                      # exhausted (shouldn't happen)
        text = avail[L].pop()
        words.append({"text": text, "path": [[r, c] for (r, c) in seg]})
    return {"size": N, "words": words}


# ── Verification (mirrors the tiling rule ph_wordbend relies on) ───────────────
def verify(board):
    n = board["size"]
    cov = [0] * (n * n)
    for wd in board["words"]:
        if len(wd["text"]) != len(wd["path"]):
            return False
        if not wd["text"].isalpha():
            return False
        prev = None
        for (r, c) in wd["path"]:
            if not (0 <= r < n and 0 <= c < n):
                return False
            cov[r * n + c] += 1
            if prev is not None and abs(r - prev[0]) + abs(c - prev[1]) != 1:
                return False                 # non-orthogonal / non-contiguous step
            prev = (r, c)
    return all(x == 1 for x in cov)          # every cell covered exactly once


def date_keys(start, count):
    y, m, d = map(int, start.split("-"))
    base = datetime.date(y, m, d)
    return [(base + datetime.timedelta(days=i)).isoformat() for i in range(count)]


def main():
    rng = random.Random(20260611)
    buckets = load_words()
    print("word bank sizes:", {L: len(buckets[L]) for L in buckets})
    pool = []

    def one():
        b = None
        while b is None:
            b = gen_board(rng, buckets)
        return b

    for dk in date_keys("2026-06-11", 30):
        b = one()
        b["date"] = dk
        pool.append(b)
    for _ in range(30):
        pool.append(one())
    assert all(verify(b) for b in pool), "a non-tiling / bad-word board slipped through"
    with open("puzzles_wordbend.json", "w") as f:
        json.dump(pool, f, separators=(",", ":"))
    wc = [len(b["words"]) for b in pool]
    ln = [len(wd["text"]) for b in pool for wd in b["words"]]
    from collections import Counter
    print(f"wrote {len(pool)} boards -> puzzles_wordbend.json")
    print(f"words/board: min {min(wc)} max {max(wc)} avg {sum(wc)/len(wc):.1f}")
    print(f"word-length mix: {dict(sorted(Counter(ln).items()))}")
    print("all boards verified: tile the board + valid real words")


if __name__ == "__main__":
    main()
