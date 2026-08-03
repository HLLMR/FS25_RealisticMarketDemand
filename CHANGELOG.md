# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Difficulty preset** setting (Easy / Normal / Hard) mapping to price floor +
  litersForFullDrop, applied live and persisted per savegame. Injected into the
  in-game General Settings menu (`scripts/RMDSettings.lua`, defensive: any GUI
  failure leaves the mechanic untouched, and it dumps the settings-frame tree to
  the debug log on first open to verify the injection target on each build).
  Presets: easy 0.60/120k L, normal 0.45/70k L, hard 0.30/40k L.
- "Saturated market" penalty line in the income HUD (next to Harvest Income),
  showing the money lost to saturation. Uses a custom `MoneyType.register` finance
  category plus display-only `g_currentMission:addMoneyChange` — which does NOT
  change the balance (already reduced by the price hook), so no double-charge.
  `addMoneyChange` does NOT auto-aggregate (per-tick calls stack a line each), so
  the penalty is accumulated per farm across an unload and flushed to ONE line
  once the flow goes idle (~1.2s debounce). (Replaced the earlier center-screen
  `showBlinkingWarning` toast, which fired but was easy to miss and in the wrong
  place.)

### Changed
- Punchier default tuning so the effect is actually felt: price floor 0.55 → 0.40
  and litersForFullDrop 250,000 → 60,000 (a few large trailers into one station
  now visibly tanks its price).

### Decided (scope)
- Wholesale-below / retail-above market spread is **out of scope** — this mod
  stays focused on demand saturation. General economy rebalancing is left to
  dedicated economy mods for compatibility.

### Fixed
- Restore-from-savegame no longer relies on `savegameDirectory` being populated
  at `loadMap` (it isn't for existing saves). Loading is now deferred via
  `ensureLoaded()` and retried lazily before the first price lookup or sale.

### Changed
- Hook double-install guard now marks the `SellingStation` class itself, so a
  mod-script reload (e.g. Easy Dev Controls) can't stack a second wrapper.
- Added per-method nil checks before installing the `SellingStation` overwrites.
- Added a per-sale diagnostic log (behind `RMDLogging.debugEnabled`, temporarily
  ON for v0.1 validation) printing liters, price paid, per-liter paid, and the
  applied multiplier.

### Verified in-game (FS25, 2026-08-02)
- Both `SellingStation` hooks install with no Lua errors.
- **Price-linkage confirmed:** money paid tracks the demand multiplier
  (e.g. ~€0.207/L paid at mult 0.72 on a ~€0.28/L base). The per-station price in
  the in-game Prices menu drops accordingly (Grain River Silo €287 → €207 after
  flooding it with wheat).
- **Persistence confirmed both ways:** the save seam writes the demand file, and
  the deferred load restores it on reload (`Loaded demand for 1 station(s)`).
- Station keying via the placeable `uniqueId` works for pre-placed map stations.

### Balance note
- Default tuning is gentle: ~156,000 L of one crop at one station only reached
  mult ~0.72. Consider a lower `litersForFullDrop` and/or floor to make the
  effect more noticeable (pending a tuning pass).

### Added
- Mod icon `icon_RealisticMarketDemand.dds` (256×256 DXT5), generated
  procedurally by `tools/gen_icon.py`.

### To do before release
- Set `RMDLogging.debugEnabled` back to `false`.
- Capture the three ModHub screenshots (guidance in `docs/SCREENSHOTS.md`).

## [0.1.0] - 2026-07-14

Initial scaffold. Single-player.

### Added
- Demand tracking per selling station and fill type, keyed by the station's
  persistent placeable `uniqueId` and the fill type name.
- Continuous price multiplier that falls linearly from 1.0 toward a floor
  (default 0.55) as consumption approaches `litersForFullDrop` (default
  250,000 L) within a monthly period; no hard sale cap.
- Monthly demand periods; consumption resets when a new period begins so prices
  recover.
- `SellingStation:getEffectiveFillTypePrice` overwrite that applies the demand
  multiplier to the effective price.
- `SellingStation:sellFillType` overwrite that records sold liters as consumed
  demand (server-authoritative).
- XML save/load of demand state per savegame.
- `[RealisticMarketDemand]`-prefixed logging of startup, hook installation, and
  save/load; optional per-sale debug output.
- Standalone unit tests for the pure demand math (`tests/DemandModel.test.lua`).

[Unreleased]: https://github.com/HLLMR/FS25_RealisticMarketDemand/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/HLLMR/FS25_RealisticMarketDemand/releases/tag/v0.1.0
