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
| 14 days | **Starfield theme variant** (warmer nebula) |
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
- Weekly Gem (spicier shared board, Mondays).
- Local achievements; personal daily-score calendar.
