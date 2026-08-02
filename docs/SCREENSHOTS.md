# Screenshot shot list

ModHub requires **at least 3 screenshots at 1600×900** and has a **zero-tolerance
rule against AI-generated or externally synthesized imagery** — these must be
genuine in-game captures. The challenge with a script mod is making an invisible
mechanic *visible*, so every shot should show the **price effect**, not scenery.

Capture at **16:9 (shoot 1920×1080, downscale to 1600×900)** — an ultrawide
(21:9) capture has to be cropped and loses either the nav or the chart.

**Best surface: the in-game Prices menu** (Statistics → Prices). It lists one
commodity's **selling price across every station at once**, which is exactly the
value our mod scales — so the flooded station's number visibly drops below the
others. This one screen carries the whole before/after story.

## How to stage the effect quickly
1. Enable the mod and (optionally) Easy Dev Controls to give yourself a large
   stock of one crop and money.
2. Pick one selling station and one crop (wheat reads clearly).
3. Note the starting price, then sell repeatedly at that station until the price
   has visibly dropped (with defaults, ~150,000 L drives it well down; more is
   more dramatic). Keep `RMDLogging.debugEnabled = true` if you want the log to
   corroborate the numbers.

## The shots

### Shot 1 — "Baseline" (required)
Prices menu, one crop (wheat reads well) selected, **before** any dumping — all
stations clustered at similar prices. This is the "before".

### Shot 2 — "Flooded" (required, the money shot)
The **same Prices screen after** heavy selling at one station — that station's
price for the crop now sits **clearly below** the others, which held. Same
framing as Shot 1 so the before/after is obvious at a glance. This single pair is
the strongest possible demonstration: same crop, one flooded station, per-station
demand, all in one view.

### Shot 3 — "In the world" (required)
A loaded trailer tipping the crop at the sell point, or the in-world price
trigger — ties the abstract number to actual gameplay.

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
