# FS25 Realistic Market Demand — agent guide

Guidance for AI/coding agents working in **this mod's repository**. Human
contributors: see [CONTRIBUTING.md](CONTRIBUTING.md) (this file and that one
share the same standards).

## Objective

A Farming Simulator 25 script mod that tracks buyer demand by selling station
and fill type, and reduces effective sale prices as demand is consumed within a
monthly period. Prices recover when a new period begins.

## Technical constraints

- Target Farming Simulator 25 only.
- Lua executes inside the GIANTS Engine environment.
- **Do not invent GIANTS API functions.** Before using a GIANTS class or method,
  cite its location in one of:
  1. the FS25 API documentation (`scriptBinding.xml` in the game's
     `sdk/debugger/`),
  2. the supplied game script source (`gameSource.zip`, same folder — note most
     function *bodies* are stripped; internal mods like `FS25_precisionFarming`
     keep theirs),
  3. or a known working FS25 mod.
- Preserve original game behavior by chaining hooks. Prefer
  `Utils.appendedFunction`, `Utils.prependedFunction`, or
  `Utils.overwrittenFunction` (`utils/Utils.lua`). `overwrittenFunction`'s
  replacement is called as `(self, superFunc, ...)`; call `superFunc(self, ...)`.
- The server is authoritative for persistent economy state.
- No custom GUI in version 0.1.
- No custom i3d assets.
- Log all startup, hook installation, reset, and save/load operations.
- Prefix log messages with `[RealisticMarketDemand]` (use `RMDLogging`).
- Keep pure market math (`DemandModel`) separate from GIANTS integration code.

## Version 0.1 scope

- Single-player initially.
- Monthly demand periods.
- Demand tracked by sell station and fill type.
- Continuous price multiplier.
- XML save/load per savegame.
- Console/log diagnostics.
- No hard sale caps.

## Non-goals (deliberate scope boundaries)

- **No general economy rebalancing.** A wholesale-below / retail-above market
  spread was considered and explicitly rejected: it is a flat global margin, a
  different mechanic from dynamic per-station demand, and it would blur this
  mod's focused identity and collide with dedicated economy mods. Keep the mod to
  demand saturation.

## Architecture

| File | Responsibility | GIANTS deps |
|------|----------------|-------------|
| `scripts/DemandModel.lua` | Pure demand → multiplier math | none (unit-testable) |
| `scripts/DemandStore.lua` | Per-(station, fillType) state + XML I/O | XML fns only |
| `scripts/MarketDemandHooks.lua` | `SellingStation` overwrites | hook layer |
| `scripts/RealisticMarketDemand.lua` | Bootstrap singleton; wiring, keys, save | full |
| `scripts/RMDLogging.lua` | `[RealisticMarketDemand]` logger | none |

## Coding style

- Descriptive names; small functions; nil-safe handling.
- No hidden global state except the single mod bootstrap instance
  (`RealisticMarketDemand`).
- Public functions documented with `@param` / `@return`.
- Files stay under ~500 lines where practical.

## Required validation (after every change)

1. Check XML syntax (`modDesc.xml`, any save-format samples).
2. Scan for undefined or speculative GIANTS API calls (each must trace to a
   cited source above; the editor's "undefined global" warnings are silenced via
   the workspace `.luarc.json`, so verify against sources, not the linter).
3. Explain which in-game action tests the change.
4. State what log output should appear.

## Known verification points

See the "Known verification points" section of [README.md](README.md#known-verification-points):
the `sellFillType`↔`getEffectiveFillTypePrice` price linkage, and the
`FSCareerMissionInfo.saveToXMLFile` save seam (not present in stripped SDK
source; isolated in `RealisticMarketDemand:installSaveHook()`).
