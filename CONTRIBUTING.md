# Contributing to Realistic Market Demand

Thanks for your interest in improving this Farming Simulator 25 mod! Bug reports,
feature ideas, and pull requests are all welcome.

## Ways to contribute

- **Report a bug** — open an issue using the Bug Report template. Please include
  your FS25 version, the mod version, whether you're in single-player or
  multiplayer, and the relevant lines from `log.txt` (they're prefixed
  `[RealisticMarketDemand]`).
- **Request a feature** — open an issue using the Feature Request template.
- **Submit a fix or feature** — open a pull request (see below).

## Project layout

```
modDesc.xml                       Mod manifest (version, source files, metadata)
scripts/DemandModel.lua           Pure math: demand -> price multiplier (no GIANTS calls)
scripts/DemandStore.lua           Per-(station, fillType) state + XML save/load
scripts/MarketDemandHooks.lua     SellingStation hook installation
scripts/RealisticMarketDemand.lua Bootstrap: wiring, station keys, save hook
scripts/RMDLogging.lua            Logging helper
tests/DemandModel.test.lua        Standalone unit tests for the pure math
```

## Development setup

1. Clone the repo into (or symlink it from) your FS25 `mods/` folder:
   `Documents/My Games/FarmingSimulator2025/mods/FS25_RealisticMarketDemand`
2. Enable the mod when starting/loading a single-player savegame.
3. Watch `Documents/My Games/FarmingSimulator2025/log.txt` for
   `[RealisticMarketDemand]` output. Set `RMDLogging.debugEnabled = true` in
   `scripts/RMDLogging.lua` for per-sale detail.

## Coding standards

This project follows a few firm rules — PRs are reviewed against them:

- **Never invent GIANTS API.** Every GIANTS class/method must be traceable to
  the FS25 `scriptBinding.xml`, the game's `gameSource.zip`, or a known working
  mod. Cite the source in a comment or the PR description.
- **Preserve base-game behavior.** Extend via `Utils.overwrittenFunction` /
  `appendedFunction` / `prependedFunction` and always chain the original
  (`superFunc`). Never silently drop vanilla behavior.
- **Server authority.** Persistent economy state is mutated and saved on the
  server only.
- **Keep pure math pure.** `DemandModel.lua` must not call any GIANTS function,
  so it stays unit-testable.
- **Nil-safe and small.** Descriptive names, small functions, guard against nil,
  files under ~500 lines where practical.
- **Document public functions** with `@param` / `@return`.
- **Log** startup, hook installation, resets, and save/load, prefixed
  `[RealisticMarketDemand]`.

## Testing

Run the pure-math tests before submitting (needs a Lua interpreter or the GIANTS
TestRunner):

```
lua tests/DemandModel.test.lua
```

For any gameplay-affecting change, describe the in-game action that exercises it
and the expected log output. See the validation checklist in
[CLAUDE.md](CLAUDE.md#required-validation-after-every-change).

## Pull request process

1. Branch from `main`.
2. Keep the change focused; update `CHANGELOG.md` under "Unreleased".
3. Make sure `tests/DemandModel.test.lua` passes and `modDesc.xml` is
   well-formed.
4. In the PR description, note which in-game action tests the change and what log
   output confirms it.
5. Be prepared for review against the coding standards above.

## License of contributions

By contributing you agree that your contributions are licensed under the
project's [CC BY-NC-SA 4.0](LICENSE) license.
