# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-08-02

First release. Single-player feature; multiplayer-compatible (loads but stays
inactive in MP). PC only. Passes the GIANTS TestRunner (0.9.19).

### Added
- **Demand-based selling prices.** Demand is tracked per selling station and fill
  type; the effective price falls continuously toward a floor as you sell more of
  one crop at one station within an in-game month (no hard sell cap). Prices
  recover when a new month begins. Implemented by overwriting
  `SellingStation:getEffectiveFillTypePrice` (price) and `SellingStation:sellFillType`
  (records consumed liters, server-authoritative).
- **"Saturated market" penalty line in the income HUD**, next to Harvest Income,
  showing the money lost to saturation. Uses a custom `MoneyType.register`
  category plus display-only `g_currentMission:addMoneyChange`, so the balance
  (already reduced by the price hook) is not double-charged. Accumulated per farm
  across an unload and shown as one line.
- **Difficulty scaling** tied to the savegame's economic difficulty (read from
  `missionInfo.economicDifficulty`, adjusts live if changed in-game):
  Easy 0.60 floor / 300k L, Normal 0.50 / 150k L, Hard 0.40 / 75k L.
- **Per-savegame persistence** of demand state (XML in the savegame folder),
  restored on load.
- Procedural mod icon (512×512 BC1) via `tools/gen_icon.py`.
- English + German descriptions and the "Saturated market" label.
- Standalone unit tests for the pure demand math (`tests/DemandModel.test.lua`).

### Notes
- Layers on top of the base game's dynamic pricing rather than replacing it.
- Demand pricing runs in single-player only; in multiplayer the mod loads but
  stays inactive (full MP support is planned for a later version).
- General economy rebalancing (e.g. a wholesale/retail spread) is intentionally
  out of scope — left to dedicated economy mods for compatibility.

[Unreleased]: https://github.com/HLLMR/FS25_RealisticMarketDemand/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/HLLMR/FS25_RealisticMarketDemand/releases/tag/v1.0.0
