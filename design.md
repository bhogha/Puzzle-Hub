# Puzzle Hub — Design System & Screen Spec

> **Purpose:** A self-contained design brief for generating new screens (Profile, Shop, and beyond) with Google Stitch. Paste the relevant sections into Stitch as the system prompt / design reference, then describe the specific screen you want. Everything here matches the live game's tokens (palette, type, spacing) so generated screens drop in without re-skinning.
>
> **Status:** Reflects v0.3 of the GameMaker build (June 2026). When the code and this doc disagree, the code (`scripts/scr_constants`, `scripts/scr_fonts`, `scripts/scr_draw`) wins — re-verify before relying on a value.

---

## 1. Product in one paragraph

Puzzle Hub is a **daily-puzzles mobile game**. Each calendar day serves 10 short, self-contained puzzles (Anygram, Sudoku, Wordle, and 7 more). Solving a puzzle grants XP; XP fills a level bar; leveling up and hitting daily milestones pay out Coins, the soft currency players spend on hints and boosters. The vibe is **bright, friendly, rounded, and rewarding** — a candy-colored arcade for word and logic players, not a stark utility. Think playful confidence: bold display type, chunky 3D buttons, glossy icons, and celebratory reward moments.

---

## 2. Platform & canvas

- **Target:** Mobile, **portrait only**. Primary device is modern iPhone (notch / Dynamic Island, home indicator).
- **Design canvas:** **1080 × 1920** (9:16 reference). Height is flexible at runtime to fill taller screens (~19.5:9), so **never hard-pin content to a fixed bottom pixel** — anchor to safe zones (see §8).
- **Density:** Designs are authored at ~2.77× a 390pt logical width. When Stitch outputs at a standard phone size, scale proportionally; the *ratios* below matter more than the raw pixel numbers.
- **Orientation of layout:** Top status/header zone → main content (centered or bottom-anchored) → fixed bottom tab bar.

---

## 3. Brand & visual identity

| Trait | Direction |
|---|---|
| **Personality** | Cheerful, encouraging, energetic. A supportive coach, never clinical. |
| **Shape language** | Heavily rounded. Corner radii are generous (pills are fully rounded; cards use ~40px radius on the 1080 canvas). No sharp corners anywhere. |
| **Depth** | Subtle, tasteful 3D: buttons have a darker "edge" underside (a chunky bottom lip), icons are glossy rendered 3D objects (stars, coins, trophies, a shopping bag, a person marker). Flat where it's content (puzzle boards), dimensional where it's interactive (buttons, nav). |
| **Surfaces** | Warm off-white background; opaque white cards and pills floating on it with soft shadows. Puzzle boards use a flat cream. |
| **Color use** | One warm neutral base, then a saturated accent per puzzle/context. Pink is the master brand accent (navigation, primary highlights). |
| **Motion** | Springy and celebratory: confetti bursts on wins, coins that stream into the wallet pill, tiles that fly and settle, tabs that pop in scale when selected. Easing is eased-out / bouncy, not linear. |

---

## 4. Color palette

All values are the live tokens from `scr_constants`. Use hex in Stitch.

### Core neutrals
| Token | Hex | Use |
|---|---|---|
| Background | `#FFF6F1` | App background (warm off-white). Default page fill. |
| White | `#FFFFFF` | Cards, pills, nav bar, button text. |
| Board cream | `#F1EAE1` | Puzzle board / empty-tile fill. |
| Tile | `#FFFAF5` | Light tile surface. |
| Dark (ink) | `#1F1430` | Primary text, dark icons. |
| Ink soft | `#503C64` | Secondary text. |
| Gray | `#A08C96` | Muted/disabled text, inactive tab labels, "coming soon". |
| Ink faint | `#C8BED2` | Hairline dividers, faint hints. |

### Brand & semantic accents
| Token | Hex | Role |
|---|---|---|
| **Pink** (brand) | `#E91E89` | Primary brand accent: active nav tab, key highlights, headline pops. |
| Pink soft / deep | `#FFD9EC` / `#B40A64` | Pink tints / pressed-edge. |
| **Gold** | `#F5B400` | **Coins** — always gold. Wallet, coin counts, prices. |
| **Yellow** | `#FFC633` | Stars / XP energy, Anygram theme. |
| Blue | `#2D7DF6` | Default action button body (CTAs), Shikaku theme. |
| Green | `#00BE49` | Success, Wordle theme. |
| Teal | `#14B8A6` | Word Wave theme, Shop icon accent. |
| Purple | `#7B3FF2` | Sudoku theme, profile avatar, level-up screens. |
| Violet | `#A838DE` | Hue Sort theme. |
| Orange / Amber | `#FF7A1A` / `#FFC04C` | Ladder theme. |
| Tangerine | `#FF5B38` | Word Bend theme. |
| Lime | `#C7E70F` | Color Link theme. |
| Silver | `#B8B9BD` | Arrows theme. |
| Sky blue | `#6EA5E6` | Hue Sort card. |

**Rule:** every accent has a matching **"deep" shade** (~30–40% darker) used for the 3D bottom edge of buttons and pressed states. When you draw a colored button, its underside lip is the deep variant of the same hue.

**Coins are always gold (`#F5B400`); XP/stars read as yellow→gold.** Don't recolor currency.

---

## 5. Typography

Two families only.

| Family | Weight(s) | Role | Notes |
|---|---|---|---|
| **Lilita One** | Regular (it's a single chunky display weight) | **All display / headings / titles / numbers-as-emphasis, big buttons** | Rounded, bold, playful. ALL-CAPS for titles and labels. This is the "voice" of the brand. |
| **Nunito** | Regular, SemiBold, Bold, ExtraBold, Black | **Body, descriptions, button labels, small UI text, reward numbers** | Friendly humanist sans. Use ExtraBold/Black for emphasis, Regular/SemiBold for flavor lines. |

### Type scale (on the 1080 canvas — scale proportionally)
| Use | Family | ~Size |
|---|---|---|
| Hero / win headline | Lilita One | 96–156 |
| Screen title (header) | Lilita One | 44 |
| Card title | Lilita One | 60 |
| Section / level label | Lilita One | 60 |
| Big reward number ("100 ⭐") | Nunito ExtraBold | 96 |
| Button label | Nunito Bold | 50 |
| Body / description | Nunito ExtraBold | 36 |
| Secondary line | Nunito Bold | 28 |
| Tab label / fine print | Nunito Bold | 22 |

**Conventions:** Titles and tab labels are **UPPERCASE**. Headlines use Lilita One; supportive/flavor sentences ("Claim your reward!", "Coins, hints & cosmetics") use Nunito. Numbers that are celebratory (rewards, big counts) use chunky Nunito ExtraBold/Black; numbers inside Lilita contexts stay Lilita.

---

## 6. Iconography & imagery

- **3D glossy icons** for anything rewarding or navigational: coin, star, trophy, stopwatch, shopping bag (Shop), person/marker (Profile), puzzle piece (Games). Rendered with light from top-left, soft highlights — they read as little objects, drawn full-color (not tinted).
- **Flat tinted line/solid icons** for utility: back chevron, hint, profile glyph. These are single-color and tinted to context (usually dark ink or white).
- **No photography.** No literal illustration of people. Keep it iconographic and geometric.
- **Avatars:** a colored circle (purple by default) with a white person glyph centered. No uploaded photos in v1.

---

## 7. Components

These are the reusable building blocks. New screens should compose from these, not invent new primitives.

### 7.1 Pill (chip)
Fully-rounded capsule. Opaque white by default with dark text; or an accent fill with white text. Used for: wallet (coin) chip, level chip, time/score chips, status labels ("PLAY", "COMING SOON"), toasts. Soft drop shadow.

### 7.2 3D button
A rounded-rectangle button (radius ~30) with a **darker bottom edge lip** (the "deep" shade of its color) giving a pressable, chunky look. White Nunito-Bold label, optional leading 3D icon.
- **Primary action:** Blue body (`#2D7DF6`) / blue-deep edge — or the screen's accent color.
- **Reward button:** carries a word label (e.g. **CLAIM**) and may show a small **TV badge** for the rewarded-video / "double" variant (e.g. **DOUBLE**).
- **Label is a verb in caps:** PLAY, CLAIM, BUY, CONTINUE, WATCH.

### 7.3 Card
Opaque white rounded rectangle (radius ~40) with a soft warm shadow (`~#BEAA9B` edge), floating on the background. Holds grouped content (stats, a shop item, an info block). The home screen's **puzzle tiles** are a specialized card: colored per puzzle, with a 3D game icon on the left, title + one-line subtitle, and a right-side white status pill (PLAY / time / COMING SOON).

### 7.4 Bottom navigation bar
Fixed, white, full-width, sits above the home indicator. **Three tabs, in order:**

1. **Shop** (leftmost) — 3D shopping-bag icon
2. **Games** (center) — 3D puzzle-piece icon (the Hub / home)
3. **Profile** (rightmost) — 3D person-marker icon

Active tab: icon **scales up**, label turns **pink** (`#E91E89`), and a short **pink underline pill** sits beneath it. Inactive: smaller icon, gray label (`#A08C96`). Labels are Nunito-Bold, ~22px, Title-case ("Shop", "Games", "Profile").

### 7.5 Header row
Top of secondary screens: a **back chevron** on the left (dark ink) and a **centered UPPERCASE screen title** in Lilita One (~44). Pushed down below the status bar / Dynamic Island via the safe-area inset.

### 7.6 Progress bar
Rounded track (faint warm gray) with a rounded fill in the context accent (purple on Profile, accent per screen). Used for the XP-to-next-level bar and daily progress.

### 7.7 Reward / celebration block
Centered stack used on win and level-up screens: headline (Lilita) → big reward amount + 3D star/coin (Nunito ExtraBold ~96) → "Claim your reward!" line → CLAIM / DOUBLE buttons. Confetti burst behind. Reuse this pattern for any "you earned X" moment.

---

## 8. Layout rules

- **Safe areas matter.** Never place content flush to the top or bottom edge. Reserve a top inset for the Dynamic Island / status bar and a bottom inset for the home indicator. Headers start *below* the inset; the nav bar extends *into* the bottom inset but keeps its tappable content above it.
- **Bottom-anchored content on play screens:** puzzle boards sit just above the bottom toolbar, leaving the empty band under the top header — so the thumb-reach zone holds the action. Apply the same instinct to interactive screens: put primary actions in the lower-middle, comfortably reachable.
- **Generous margins:** main cards inset ~80px from the screen edges on the 1080 canvas (~7.5%). Breathe.
- **One primary action per screen.** Make it the most prominent button.
- **Vertical rhythm:** header → hero/identity element → grouped cards → primary CTA → nav. Consistent gaps.

---

## 9. Voice & tone (UX copy)

The brand talks like an upbeat friend who's good at games — warm, brief, never condescending.

**Principles:** Clear over clever. Short. Verbs on buttons. Celebrate wins without gushing. Frame empty/locked states as anticipation, not apology.

| Context | Tone | Example |
|---|---|---|
| Buttons / CTAs | Confident verb, caps | `PLAY`, `CLAIM`, `BUY`, `CONTINUE`, `WATCH` |
| Success | Warm, brief | "Nice solve!", "Claim your reward!" |
| Locked / upcoming | Anticipatory | "Coming soon", "Unlocks at Level 3" |
| Empty state | Inviting, points to action | "No puzzles played yet — start today's set!" |
| Currency | Plain | "100 coins", never "100 monies" or jargon |
| Errors (rare) | Empathetic + fix | "Not enough coins. Earn more by solving puzzles or watch a video." |

**Terminology — use these exact words everywhere (consistency):**
*Puzzle* (not game/level for an individual challenge), *Coins* (soft currency, gold), *XP* (experience points), *Level*, *Hint*, *Booster*, *Streak*, *Daily set*. A "game" = one of the 10 puzzle types. "Today's puzzles" = the daily set of 10.

---

## 10. Economy context (for content on Profile / Shop / rewards)

So generated screens show the right numbers and labels:

- New players start with **100 XP** and **300 Coins**.
- **+100 XP** per puzzle solved (max 1000/day across 10 puzzles).
- **Level = floor(XP / 500) + 1.** Every **500 XP** = one level up.
- **Level up → +100 Coins.**
- Solve **4 puzzles in a day → +100 Coins** milestone.
- **Hint costs 100 Coins** (or watch a rewarded video for free).
- Coins are spent in the **Shop** on **Hints** and **Boosters** (and, later, cosmetics).
- There are **10 puzzles per day**; daily progress shows as `N/10`.

---

## 11. Existing screen for reference — the Hub (Games tab)

So new screens feel consistent: the Hub has a **level chip (top-left)**, a **coin wallet pill (top-right, gold coin + count)**, a 7-day date strip with an expandable month calendar, a **daily progress tube** (`N/10`), and a vertically scrolling list of **puzzle tiles** (one colored card per puzzle: 3D icon, title, subtitle, right status pill). The bottom nav's center "Games" tab is active here. Match this header treatment (level + wallet) and tile/card styling on other screens.

---

## 12. Screens to design

### 12.1 PROFILE  *(rebuild — current screen is a placeholder)*

**Goal:** A player's identity + progression home. Show who they are, how far they've come, and give light reasons to keep playing.

**Header:** back chevron (left) + centered title **`PROFILE`**.

**Identity block (top card):**
- Avatar: purple (`#7B3FF2`) circle with white person glyph, centered near the top of the card.
- Editable display name below the avatar (Lilita One). Placeholder copy: **"Player"** with a small edit affordance. Microcopy when unset: tap to name → field hint "Enter a name".
- **Level** label: `LEVEL 4` (Lilita One, ~60).
- **XP progress bar** (purple fill) with label `320 / 500 XP` beneath it (Nunito Bold, gray).
- **Coin wallet:** gold coin icon + count, e.g. `300 coins`.

**Stats grid (cards or a 2×N grid of stat pills):** surface the numbers players are proud of —
- **Day streak** (e.g. "🔥 7-day streak")
- **Puzzles solved** (lifetime total)
- **Best time** or favorite puzzle
- **Today's progress** `N/10`

Each stat: big number (Lilita or Nunito ExtraBold) + small caps caption (Nunito Bold, gray).

**Optional rows (future-friendly, can be "coming soon"):** Achievements / Badges, Settings, Notifications, Restore purchases. Frame any unbuilt row as `Coming soon` in gray rather than hiding it.

**Bottom nav:** Profile tab active (rightmost, pink).

**Copy for this screen:**
| Element | Copy | Notes |
|---|---|---|
| Title | `PROFILE` | Uppercase, Lilita |
| Name (unset) | `Player` / hint: `Tap to add your name` | |
| Level | `LEVEL 4` | |
| XP bar caption | `320 / 500 XP` | live values |
| Streak stat | `7` + caption `DAY STREAK` | |
| Solved stat | `128` + caption `PUZZLES SOLVED` | |
| Today stat | `3/10` + caption `TODAY` | |
| Achievements row (locked) | `Achievements` · `Coming soon` | gray |
| Empty stats (brand-new player) | `Solve your first puzzle to start your streak!` | inviting |

> **Stitch prompt seed (Profile):** "Design a mobile profile screen for a playful daily-puzzle game. Warm off-white background (#FFF6F1). Top header with a back chevron and centered uppercase title 'PROFILE' in a chunky rounded display font (Lilita One). A white rounded card with a purple circular avatar (white person icon), an editable display name, 'LEVEL 4' label, a purple XP progress bar reading '320 / 500 XP', and a gold coin count '300 coins'. Below, a 2×2 grid of white stat cards: day streak, puzzles solved, best time, today's progress (3/10), each with a big number and small uppercase caption in gray. Fixed bottom tab bar with three tabs — Shop, Games, Profile — Profile active in pink with an underline pill and a scaled-up 3D person icon. Rounded, friendly, chunky 3D buttons, soft shadows."

---

### 12.2 SHOP  *(rebuild — current screen is a placeholder)*

**Goal:** Let players spend Coins on things that help them play. Clear value, obvious prices, no dark patterns.

**Header:** back chevron (left) + centered title **`SHOP`**. **Coin wallet pill top-right** (gold coin + balance) so players always see what they can afford.

**Sections (each a labeled group of item cards):**

1. **Hints & Boosters** (the core utility)
   - *Hint pack* — buy hints to reveal part of a puzzle. e.g. "5 Hints — 400 coins".
   - *Single hint* — `100 coins` (matches in-puzzle price).
   - *Booster* (future): time freeze, extra Wordle guesses, etc.

2. **Coins** (earn / top-up)
   - **Watch a video → +Coins** (rewarded video, free). 3D TV badge on the button. Copy: "Watch to earn".
   - Coin bundles (if monetized later): small/medium/large with a 3D coin-pile icon. Mark `Coming soon` if not built.

3. **Cosmetics** (future) — themes, avatars, tile skins. `Coming soon`.

**Item card anatomy:** 3D icon (left or top) → item name (Lilita) → one-line benefit (Nunito) → **price button** on the right (gold coin + number, or `WATCH` with TV badge, or `FREE`). When the player can't afford it, dim the button and show a tiny "Earn more" affordance rather than a hard error.

**Bottom nav:** Shop tab active (leftmost, pink).

**Copy for this screen:**
| Element | Copy | Notes |
|---|---|---|
| Title | `SHOP` | |
| Section: hints | `HINTS & BOOSTERS` | section label, Lilita/Nunito caps |
| Hint item | `Single Hint` · benefit `Reveal a piece of any puzzle` · price `100` (gold coin) | |
| Hint pack | `5 Hints` · `Best value` tag · price `400` | |
| Earn coins | `Watch & Earn` · `Get free coins by watching a short video` · button `WATCH` + TV badge | |
| Coin bundle (locked) | `Coin Bundle` · `Coming soon` | gray |
| Cosmetics section | `THEMES & SKINS` · `Coming soon` | gray, anticipatory |
| Can't afford | button dim + caption `Earn more by solving puzzles` | empathetic, no scolding |
| Purchase success toast | `Added to your wallet!` / `Hints ready — go solve!` | warm, brief |
| Confirm spend (if used) | title `Buy 5 Hints for 400 coins?` · buttons `BUY` / `CANCEL` | name the action + cost |

> **Stitch prompt seed (Shop):** "Design a mobile shop screen for a playful daily-puzzle game. Warm off-white background (#FFF6F1). Header with back chevron, centered uppercase title 'SHOP' (chunky rounded display font), and a gold coin balance pill in the top-right. Grouped sections with uppercase labels: 'HINTS & BOOSTERS' and 'WATCH & EARN'. Each item is a white rounded card with a glossy 3D icon (lightbulb hint, coin pile, TV), an item name in Lilita One, a one-line benefit in Nunito, and a chunky 3D price button on the right showing a gold coin + number (e.g. 100), or a 'WATCH' button with a small 3D TV badge for the rewarded video. Disabled/unaffordable buttons are dimmed. A 'THEMES & SKINS — Coming soon' section in gray at the bottom. Fixed bottom tab bar — Shop, Games, Profile — with Shop active in pink (underline pill, scaled-up 3D shopping-bag icon). Rounded corners, soft warm shadows, friendly and energetic."

---

## 13. Quick reference for Stitch (paste-ready primer)

> Mobile portrait puzzle game, 1080×1920 canvas. Background `#FFF6F1`. Two fonts: **Lilita One** (chunky rounded display, ALL-CAPS titles, buttons, big numbers) and **Nunito** (body, labels, flavor text). Brand accent **pink `#E91E89`**; coins are **gold `#F5B400`**; default action button **blue `#2D7DF6`**. Every colored button has a darker bottom-edge lip (3D look) and a white caps verb label. Pills are fully rounded (white-on-bg or accent-on-white). Cards are white, ~40px radius, soft warm shadow. Fixed bottom nav: **Shop · Games · Profile**, active tab pink with an underline pill and a scaled 3D icon. Glossy 3D icons for rewards/nav; flat tinted icons for utility. Respect top (Dynamic Island) and bottom (home indicator) safe areas. Tone: warm, brief, encouraging, celebratory.

---

*Maintained alongside `GDD.md` and `PROJECT_CACHE.md`. Update palette/type/economy here whenever `scr_constants` or `scr_fonts` change.*
