# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Notes / to verify
- Confirm in-game that reducing `SellingStation:getEffectiveFillTypePrice` also
  reduces the money paid by `sellFillType` (the two are assumed linked).
- Confirm the `FSCareerMissionInfo.saveToXMLFile` save seam fires (not present in
  the stripped SDK source).
- Add a real `icon_RealisticMarketDemand.dds` (referenced by `modDesc.xml`).

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
