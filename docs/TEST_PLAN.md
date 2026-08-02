# Test plan — Realistic Market Demand

Manual test matrix for release hardening. Log lines are in
`Documents/My Games/FarmingSimulator2025/log.txt`, prefixed
`[RealisticMarketDemand]`. Keep `RMDLogging.debugEnabled = true` while testing so
per-sale `SALE …` lines appear; set it back to `false` before packaging.

## 0. Bring-up (per launch)

| # | Action | Pass criteria |
|---|--------|---------------|
| 0.1 | Launch FS25 with the mod enabled, load a save | `Starting up`, both `Installed … hook` lines, `Installed save hook`, `Startup complete`. **No Lua errors / call stacks.** |
| 0.2 | Confirm the mod is active on the intended farm | `getIsServer` true in SP → demand tracked |

## 1. Price effect (the core behavior)

| # | Action | Pass criteria |
|---|--------|---------------|
| 1.1 | Drive to a selling station, open its price list for one crop (e.g. wheat), note the per-liter price | baseline recorded |
| 1.2 | Sell a load of that crop at that station | `SALE station=… fill=WHEAT liters=… paid=… perLiterPaid=… mult=…` appears; `mult` < 1.0 after the first load |
| 1.3 | Sell several more loads of the same crop at the **same** station | `perLiterPaid` decreases across sales; `mult` trends toward the 0.55 floor; `consumed` accumulates |
| 1.4 | Compare `perLiterPaid` ratios between two sales to their `mult` ratio | ratios match → **money paid reflects the demand multiplier (price-linkage confirmed)** |
| 1.5 | Check the same crop at a **different** station | unaffected (independent demand) |
| 1.6 | Check a **different** crop at the same station | unaffected (independent demand) |

## 2. Persistence

| # | Action | Pass criteria |
|---|--------|---------------|
| 2.1 | After some sales, save the game | `Saved demand for N station(s)`; `savegameN/realisticMarketDemand.xml` exists with N > 0 stations |
| 2.2 | Exit to menu, reload the same save | `Loaded demand for N station(s)`; reduced prices are still in effect (not reset to full) |
| 2.3 | Inspect `realisticMarketDemand.xml` | well-formed; `#fillType` uses names, `#consumedLiters`/`#period` sane |

## 3. Time / period behavior

| # | Action | Pass criteria |
|---|--------|---------------|
| 3.1 | Saturate one crop's price, then sleep/advance to the next in-game month | price for that crop recovers toward full |
| 3.2 | Play across a full in-game year (12 periods) | no runaway state; prices track the month; no error spam |
| 3.3 | Sell again in the new period | demand re-accumulates from zero for that period |

## 4. Compatibility

| # | Action | Pass criteria |
|---|--------|---------------|
| 4.1 | Run alongside common price/economy mods (e.g. price display/ticker, seasonal prices) | no conflict; hooks coexist |
| 4.2 | Run alongside another market-overhaul script that also hooks `SellingStation:sellFillType` / `getEffectiveFillTypePrice` | document behavior; if incompatible, note it in README |
| 4.3 | Different maps (base + at least one custom) | works on pre-placed map sell points, not just player-placed (watch for the name-key fallback WARN) |

## 5. Multiplayer / dedicated (currently declared unsupported)

| # | Action | Pass criteria |
|---|--------|---------------|
| 5.1 | Confirm `modDesc.xml` declares `<multiplayer supported="false"/>` | present |
| 5.2 | (If ever enabling MP) client vs server: demand mutated/saved only on server | writes guarded by `getIsServer` |

## 6. Packaging (ModHub readiness)

| # | Item | Pass criteria |
|---|------|---------------|
| 6.1 | `icon_RealisticMarketDemand.dds` present | no "Missing dds file" error at load |
| 6.2 | `RMDLogging.debugEnabled = false` | no per-sale spam in normal play |
| 6.3 | ZIP has `modDesc.xml` at its root; excludes dev-only files | loads from `mods/` as a zip |
| 6.4 | 3× genuine in-game screenshots (1600×900) showing the price effect | no synthetic imagery |
| 6.5 | Pure-math tests green (`tests/DemandModel.test.lua`) | all pass |
