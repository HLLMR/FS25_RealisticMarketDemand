# Screenshot shot list

ModHub requires **at least 3 screenshots at 1600×900** and has a **zero-tolerance
rule against AI-generated or externally synthesized imagery** — these must be
genuine in-game captures. The challenge with a script mod is making an invisible
mechanic *visible*, so every shot should show the **price effect**, not scenery.

Set FS25 to 1600×900 (or crop to it). Hide unnecessary HUD clutter if possible.

## How to stage the effect quickly
1. Enable the mod and (optionally) Easy Dev Controls to give yourself a large
   stock of one crop and money.
2. Pick one selling station and one crop (wheat reads clearly).
3. Note the starting price, then sell repeatedly at that station until the price
   has visibly dropped (with defaults, ~150,000 L drives it well down; more is
   more dramatic). Keep `RMDLogging.debugEnabled = true` if you want the log to
   corroborate the numbers.

## The shots

### Shot 1 — "Baseline price" (required)
The selling station's price display for the chosen crop **before** any dumping,
showing a healthy/normal price per liter. This is the "before".
- Frame: the in-world price trigger or the prices overview, crop + price legible.

### Shot 2 — "Flooded price" (required, the money shot)
The **same station, same crop, after** heavy selling — price visibly reduced.
Ideally composed to match Shot 1's framing so the before/after is obvious at a
glance.
- Bonus: if the UI shows it, capture the moment mid-sale with the lower payout.

### Shot 3 — "Spread your sales" (required)
Two things that make the mechanic legible:
- Option A: the **same crop at two different stations** showing **different**
  prices (one flooded, one fresh) — demonstrates per-station demand.
- Option B: the **prices overview** with the flooded crop clearly lower than its
  neighbors at that station.

### Shot 4 — "In action" (optional hero)
A loaded trailer tipping the crop at the sell point, price panel visible — a
nice storefront image that still ties to the mechanic.

### Shot 5 — "Recovery" (optional, strong for the description)
The same crop/station a month later, price recovered toward normal — sells the
"patience pays" story. Pairs well with Shot 2.

## Caption ideas (for the listing)
- "Dump it all at once and the price sags…"
- "…sell across stations and months to keep prices high."
- "Every station, every crop, tracked independently."

## Also needed (not a screenshot, but a visual asset)
- **`icon_RealisticMarketDemand.dds`** — the mod icon (currently missing; throws
  a load error). Use `FSIconGenerator` (in `.giants/utilities/`) from a genuine
  in-game capture or a simple made-in-editor image. 256×256 DXT-compressed .dds
  per GIANTS' icon spec.
