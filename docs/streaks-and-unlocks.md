# Streaks & the unlock ladder (design for 1.3.0)

Agreed 2026-08-10 (Ben + Claude). Everything here is local-only — no
accounts, no network, no purchases. The ladder is fully visible from day
one: anticipation, not extortion. Unlocks are cosmetic only, never
gameplay power.

## Streak rules

- A streak = consecutive calendar days with a completed Daily Gem
  (first run of the day counts it, same as scoring).
- Missing a day resets to 0 — with **one Free Pass earned per 7-day
  streak** (banked, max 2): an automatic save when you miss a single
  day. Kindness beats Duolingo-style monetized freezes; we're free, we
  can just be kind.
- Streak shows on the Daily card (🔥 N) and rides the share text.

## The visible ladder (v1)

Shown in a "Collection" screen and previewed on the Daily card —
locked items appear as silhouettes with their unlock condition:

| Streak | Unlock |
|-------:|--------|
| 3 days | **Ocean palette** (cool blues/teals) |
| 7 days | **Aurora palette** + first Free Pass |
| 14 days | **Custom Studio** — design your own gems: color picker + curated shape set (38), auto-derived glows, shareable GEMS1. theme codes |
| 21 days | **Gem trail effect** (subtle swap sparkle) |
| 30 days | **Golden gem set** + "Gem Master" title in share text |

- **Colorblind-friendly palette is NOT on the ladder** — accessibility
  is never an unlock. It ships free in Settings for everyone.
- Ladder extends later (60/100-day) once anyone gets close.

## Share text integration

`💎 Daily Gem 8/14 — 12,340 · 🔥 9-day streak · [title if earned]`
plus combo/power-up highlights from the run (the Wordle-grid analog:
every share is a small brag and an ad).

## Also riding 1.3.0

- Opt-in daily reminder (local notification; offered after 3rd daily).
- Wakelock scoped to active gameplay (already committed, e70778a).
- Palette system itself (the ladder's delivery mechanism + colorblind).

## Later / separate

- 2.5D tile polish (bevels, glints, shadows — pre-rendered sprite
  treatment; an art day, not an engine change). True 3D: no.
- **Studio wing 2: drawn shapes** — a small pixel-art editor (~12x12
  grid, stored as bitmap, rendered in place of icons). Theme codes are
  versioned (GEMS1.) so drawn-shape payloads ride the same envelope.
- Starfield theme variant (was the old 14-day rung; Studio took it).
- Weekly Gem (spicier shared board, Mondays).
- Local achievements; personal daily-score calendar.

## Creator/viral vector (Ben, 2026-08-10)

Theme codes are broadcastable artifacts with a built-in install funnel —
a creator shares their code, followers need the game to use it. Zero
backend throughout. Amplifiers, by leverage: (1) GEMS2 envelope with
theme NAME + AUTHOR so imports read "Install 'Midnight' by @creator?" —
attribution is why creators share; (2) one-tap links lit.ai/gems/t/<code>
(static page, code in URL; opens app or shows gem preview + store
button — the page IS the funnel); (3) drawn shapes turn themes into
creator merch (mascot gems); (4) "play the daily in my theme" as the
creator call-to-action that exercises everything at once.
