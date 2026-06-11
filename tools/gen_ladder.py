#!/usr/bin/env python3
"""Word Ladder generator for Puzzle Hub.

Produces datafiles/puzzles_ladder.json — a pool of valid, guaranteed-solvable
word ladders (seed word + 10 rungs, each rung one letter apart, every word a
real, recognisable word). Matches the schema read by scr_ladder.gml:

  [ { "date":"YYYY-MM-DD"(optional), "length":N, "start":"<N letters>",
      "steps":[ {"word":"<N letters>","clue":"..."} x 10 ] }, ... ]

WHY ALGORITHMIC, NOT LLM:
  Word ladders have a hard constraint — every step must change EXACTLY one
  letter AND land on a real word. LLMs get this wrong constantly. So we build
  the ladders by graph walk over a real word list (100% correct by
  construction) and use the LLM (Gemini) ONLY for the clues, where a mistake is
  cosmetic, not game-breaking. Clues are cached so re-runs are cheap.

WORD UNIVERSE:
  The curated "Level Editors/Word List.txt" (common, recognisable words). Using
  it as the validity universe guarantees every rung is a word a player knows.

USAGE:
  # Full run with real clues (run on your machine, where Gemini is reachable):
  GEMINI_API_KEY=xxxxx python3 tools/gen_ladder.py

  # Structure only / placeholder clues (no network, e.g. CI or preview):
  python3 tools/gen_ladder.py --no-clues

  # Tune counts / lengths / seed:
  python3 tools/gen_ladder.py --past 60 --future 60 --fallbacks 10 \
                              --lengths 4,5 --seed 20260611

  # TOP UP later — add 60 NEW dated days after the last day already in the file,
  # leaving every existing entry untouched (word reuse across days is allowed):
  GEMINI_API_KEY=xxxxx python3 tools/gen_ladder.py --append
  #   --add N            how many new days (default 60)
  #   --start-date DATE  force the first new date (default: day after last in file)

Re-running is safe and deterministic for a given --seed; clue cache lives at
tools/ladder_clue_cache.json so already-described words are never re-queried.
"""

import argparse, collections, datetime, json, os, random, re, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)                       # .../Puzzle Hub
OUT_PATH = os.path.join(PROJECT, "datafiles", "puzzles_ladder.json")
CACHE_PATH = os.path.join(HERE, "ladder_clue_cache.json")

# Candidate locations for the shared curated word list.
WORDLIST_CANDIDATES = [
    os.path.join(PROJECT, "..", "Level Editors", "Word List.txt"),
    os.path.join(PROJECT, "..", "Daily Puzzle", "Level Editors", "Word List.txt"),
]

CHAIN_LEN = 11          # seed + 10 rungs
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
PLACEHOLDER_CLUE = "(clue pending — run gen_ladder.py with GEMINI_API_KEY)"


# ── Word list ───────────────────────────────────────────────────────────────
def load_words():
    path = next((p for p in WORDLIST_CANDIDATES if os.path.exists(p)), None)
    if not path:
        sys.exit("ERROR: Word List.txt not found. Checked:\n  " +
                 "\n  ".join(WORDLIST_CANDIDATES))
    raw = open(path, encoding="utf-8").read()
    words = {w.upper() for w in re.findall(r"[A-Za-z]+", raw) if len(w) > 1}
    return words


def build_graph(words, length):
    """Adjacency map (one-letter-apart) for all words of a given length."""
    nodes = [w for w in words if len(w) == length]
    buckets = collections.defaultdict(list)
    for w in nodes:
        for i in range(length):
            buckets[w[:i] + "_" + w[i + 1:]].append(w)
    adj = collections.defaultdict(set)
    for ws in buckets.values():
        for a in ws:
            for b in ws:
                if a != b:
                    adj[a].add(b)
    return adj


# ── Ladder construction ─────────────────────────────────────────────────────
def random_chain(adj, rng, used_starts, used_words, length, tries=4000):
    """Find a chain of CHAIN_LEN distinct words via randomised DFS with backtrack.

    Prefers a fresh start word and minimises overlap with words already used in
    other puzzles so the pool stays varied.
    """
    candidates = sorted(w for w in adj if adj[w])  # sort first → process-independent
    rng.shuffle(candidates)
    for start in candidates:
        if start in used_starts:
            continue
        for _ in range(tries // max(1, len(candidates))):
            chain = _dfs(adj, rng, start, used_words)
            if chain:
                return chain
    # Fallback: relax the "fresh start" preference.
    for start in candidates:
        for _ in range(40):
            chain = _dfs(adj, rng, start, used_words)
            if chain:
                return chain
    return None


def _dfs(adj, rng, start, used_words):
    """One randomised depth-first attempt to extend start to CHAIN_LEN."""
    path = [start]
    inpath = {start}
    while len(path) < CHAIN_LEN:
        nbrs = sorted(adj[path[-1]] - inpath)  # sort first → process-independent
        if not nbrs:
            return None  # dead end; caller retries from scratch
        # Bias toward words not already used elsewhere in the pool.
        rng.shuffle(nbrs)
        nbrs.sort(key=lambda w: w in used_words)  # unused first (stable)
        nxt = nbrs[0]
        path.append(nxt)
        inpath.add(nxt)
    return path


def validate_chain(chain, length):
    assert len(chain) == CHAIN_LEN, f"chain len {len(chain)} != {CHAIN_LEN}"
    assert len(set(chain)) == CHAIN_LEN, "repeated word in chain"
    for w in chain:
        assert len(w) == length and w.isalpha(), f"bad word {w!r}"
    for a, b in zip(chain, chain[1:]):
        diff = sum(1 for x, y in zip(a, b) if x != y)
        assert diff == 1, f"{a}->{b} changes {diff} letters"


# ── Clues (Gemini) ──────────────────────────────────────────────────────────
def load_cache():
    if os.path.exists(CACHE_PATH):
        try:
            return json.load(open(CACHE_PATH, encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_cache(cache):
    json.dump(cache, open(CACHE_PATH, "w", encoding="utf-8"),
              ensure_ascii=False, indent=2, sort_keys=True)


def _gemini_call(url, batch, max_retries=6):
    """One batch -> Gemini, with exponential backoff on 429/503. Returns parsed
    dict or None. Honors the Retry-After header when present."""
    prompt = (
        "Write a short crossword-style clue for each word below. Rules: "
        "max 8 words per clue, family-friendly, do NOT use the word itself "
        "or its plural/forms in the clue. Return ONLY a strict JSON object "
        "mapping each WORD (uppercase) to its clue string.\n\nWords: "
        + ", ".join(batch)
    )
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.7,
                             "responseMimeType": "application/json"},
    }).encode("utf-8")
    for attempt in range(max_retries):
        req = urllib.request.Request(url, data=body,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.load(resp)
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            return json.loads(text)
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 503) and attempt < max_retries - 1:
                wait = e.headers.get("Retry-After")
                wait = float(wait) if wait and wait.isdigit() else min(60, 2 ** attempt * 3)
                print(f"    {e.code} — backing off {wait:.0f}s "
                      f"(retry {attempt + 1}/{max_retries - 1})")
                time.sleep(wait)
                continue
            print(f"    HTTP {e.code}: {e.read().decode('utf-8', 'ignore')[:200]}")
            return None
        except (urllib.error.URLError, KeyError, json.JSONDecodeError) as e:
            print(f"    request error: {e}")
            return None
    return None


def gemini_clues(words, api_key, cache, batch_size=25):
    """Fill clues for `words` using Gemini, batching uncached words. Mutates cache.
    Each successful batch is persisted immediately, so a later failure or Ctrl-C
    never loses progress — just re-run to resume the remaining words."""
    need = sorted({w for w in words if w not in cache})
    if not need:
        print("  all clues already cached.")
        return
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/"
           f"{GEMINI_MODEL}:generateContent?key={api_key}")
    done = 0
    for i in range(0, len(need), batch_size):
        batch = need[i:i + batch_size]
        parsed = _gemini_call(url, batch)
        if parsed is None:
            print(f"  stopped at {done}/{len(need)} clues. "
                  f"Cached so far are saved — re-run to resume the rest.")
            return
        for w in batch:
            clue = parsed.get(w) or parsed.get(w.upper()) or parsed.get(w.title())
            if clue:
                cache[w] = str(clue).strip()
        save_cache(cache)
        done += len(batch)
        print(f"  clues {done}/{len(need)}")
        time.sleep(1.5)   # stay well under free-tier RPM


# ── Clues (WordNet, offline / free) ──────────────────────────────────────────
def wordnet_clues(words, cache):
    """Fill clues from WordNet glosses — no network, no API key, no quota.
    Needs nltk + the wordnet corpus:  pip install nltk
    (the corpus auto-downloads on first run). Mutates cache."""
    try:
        import nltk
        from nltk.corpus import wordnet as wn
    except ImportError:
        sys.exit("WordNet clues need nltk:  pip install nltk")
    try:
        wn.ensure_loaded()
    except LookupError:
        print("  downloading WordNet corpus (one-time) ...")
        nltk.download("wordnet", quiet=True)
        nltk.download("omw-1.4", quiet=True)

    need = [w for w in dict.fromkeys(words) if w not in cache]
    filled = 0
    for w in need:
        syns = wn.synsets(w.lower())
        clue = None
        if syns:
            # Prefer noun/verb senses; fall back to the first sense.
            pick = next((s for s in syns if s.pos() in ("n", "v")), syns[0])
            gloss = pick.definition()
            gloss = re.split(r"[;(]", gloss)[0].strip()        # first clause only
            gloss = re.sub(rf"\b{re.escape(w.lower())}\b", "___", gloss, flags=re.I)
            parts = gloss.split()
            if parts:
                clue = " ".join(parts[:9]).rstrip(",.")
                clue = clue[0].upper() + clue[1:]
        if clue:
            cache[w] = clue
            filled += 1
    save_cache(cache)
    print(f"  WordNet filled {filled}/{len(need)} new clues "
          f"({len(need) - filled} had no entry → placeholder)")


# ── Dates ───────────────────────────────────────────────────────────────────
def date_range(start_date, n, step):
    return [(start_date + datetime.timedelta(days=step * i)).isoformat()
            for i in range(n)]


# ── Build helpers ─────────────────────────────────────────────────────────────
def build_chains(n, lengths, graphs, rng, used_starts, used_words):
    """Build n validated chains, mixing the given lengths ~evenly."""
    length_seq = [lengths[i % len(lengths)] for i in range(n)]
    rng.shuffle(length_seq)
    chains = []
    for L in length_seq:
        chain = random_chain(graphs[L], rng, used_starts, used_words, L)
        if not chain:
            sys.exit(f"ERROR: could not build a length-{L} chain "
                     f"(graph exhausted after {len(chains)} puzzles)")
        validate_chain(chain, L)
        used_starts.add(chain[0])
        used_words.update(chain)
        chains.append((L, chain))
    return chains


def fill_clues(mode, words, cache):
    if mode == "none":
        print("clues: none — using placeholders")
    elif mode == "wordnet":
        print("clues: WordNet (offline) ...")
        wordnet_clues(words, cache)
    else:  # gemini
        key = os.environ.get("GEMINI_API_KEY")
        if not key:
            print("clues: gemini selected but no GEMINI_API_KEY set — using "
                  "placeholders. (Or run with --clues wordnet for free offline clues.)")
        else:
            print(f"clues: Gemini ({GEMINI_MODEL}) ...")
            gemini_clues(words, key, cache)


def make_entry(L, chain, cache, date=None):
    entry = {"length": L, "start": chain[0],
             "steps": [{"word": w, "clue": cache.get(w, PLACEHOLDER_CLUE)}
                       for w in chain[1:]]}
    return {"date": date, **entry} if date else entry


# ── Main ────────────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--append", action="store_true",
                    help="add new dated days to the existing pool instead of "
                         "regenerating it (existing entries are left untouched)")
    ap.add_argument("--add", type=int, default=60,
                    help="append mode: how many new dated days to add (default 60)")
    ap.add_argument("--start-date", default=None,
                    help="append mode: first new date YYYY-MM-DD "
                         "(default: the day after the last dated day in the file)")
    ap.add_argument("--past", type=int, default=30, help="fresh mode: dated days before today")
    ap.add_argument("--future", type=int, default=30, help="fresh mode: dated days from today on")
    ap.add_argument("--fallbacks", type=int, default=10, help="fresh mode: undated fallback ladders")
    ap.add_argument("--lengths", default="4,5", help="comma list of word lengths to mix")
    ap.add_argument("--seed", type=int, default=None,
                    help="RNG seed (reproducible). Default: 20260611 fresh, "
                         "or derived from the start date in append mode so each top-up differs")
    ap.add_argument("--clues", choices=["gemini", "wordnet", "none"], default="gemini",
                    help="clue source: gemini (API key), wordnet (offline/free), or none")
    ap.add_argument("--no-clues", action="store_true",
                    help="alias for --clues none (placeholder clues)")
    ap.add_argument("--today", default=datetime.date.today().isoformat(),
                    help="fresh mode: anchor date YYYY-MM-DD (today)")
    args = ap.parse_args()

    lengths = [int(x) for x in args.lengths.split(",") if x.strip()]
    words = load_words()
    graphs = {L: build_graph(words, L) for L in lengths}
    for L in lengths:
        usable = sum(1 for w in graphs[L] if graphs[L][w])
        print(f"length {L}: {usable} connected words available")

    cache = load_cache()
    mode = "none" if args.no_clues else args.clues

    if args.append:
        _append(args, lengths, graphs, cache, mode)
    else:
        _fresh(args, lengths, graphs, cache, mode)


def _fresh(args, lengths, graphs, cache, mode):
    rng = random.Random(args.seed if args.seed is not None else 20260611)
    total = args.past + args.future + args.fallbacks
    used_starts, used_words = set(), set()
    chains = build_chains(total, lengths, graphs, rng, used_starts, used_words)

    all_rungs = [w for _, ch in chains for w in ch[1:]]
    fill_clues(mode, all_rungs, cache)

    today = datetime.date.fromisoformat(args.today)
    past_dates = list(reversed(date_range(today - datetime.timedelta(days=1),
                                          args.past, -1)))     # oldest first
    future_dates = date_range(today, args.future, 1)
    dated = past_dates + future_dates

    out = [make_entry(L, ch, cache, dated[i] if i < len(dated) else None)
           for i, (L, ch) in enumerate(chains)]
    json.dump(out, open(OUT_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    n_clued = sum(1 for w in set(all_rungs) if w in cache)
    print(f"\nWrote {len(out)} ladders -> {OUT_PATH}")
    print(f"  dated: {len(dated)} ({args.past} past + {args.future} future), "
          f"undated fallbacks: {len(out) - len(dated)}")
    print(f"  unique rung words: {len(set(all_rungs))}, with real clues: {n_clued}")


def _append(args, lengths, graphs, cache, mode):
    if not os.path.exists(OUT_PATH):
        sys.exit(f"ERROR: --append needs an existing pool at {OUT_PATH}. "
                 f"Run once without --append first.")
    existing = json.load(open(OUT_PATH, encoding="utf-8"))
    existing_dates = {e["date"] for e in existing if isinstance(e, dict) and "date" in e}

    # Where do the new days start?
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

    # Default seed varies per top-up so successive appends differ; still reproducible.
    seed = args.seed if args.seed is not None else int(start.strftime("%Y%m%d"))
    rng = random.Random(seed)

    # Word reuse across days is allowed → start with empty 'used' sets (these only
    # keep variety WITHIN this batch). Old days are never touched.
    chains = build_chains(args.add, lengths, graphs, rng, set(), set())
    all_rungs = [w for _, ch in chains for w in ch[1:]]
    fill_clues(mode, all_rungs, cache)

    new_entries = [make_entry(L, ch, cache, new_dates[i])
                   for i, (L, ch) in enumerate(chains)]
    merged = existing + new_entries
    json.dump(merged, open(OUT_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

    n_clued = sum(1 for w in set(all_rungs) if w in cache)
    print(f"\nAppended {len(new_entries)} dated ladders "
          f"({new_dates[0]} → {new_dates[-1]}) -> {OUT_PATH}")
    print(f"  pool was {len(existing)}, now {len(merged)} entries (existing untouched)")
    print(f"  new unique rung words: {len(set(all_rungs))}, with real clues: {n_clued}")


if __name__ == "__main__":
    main()
