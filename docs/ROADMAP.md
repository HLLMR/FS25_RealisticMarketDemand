# Roadmap

The issue drafts below are paste-ready for GitHub. Create a **next milestone** and
open them under it.

## v1.0.0 (released) — demand saturation

Shipped: per-station, per-fillType demand keyed on an absolute period id;
continuous price multiplier with monthly recovery; XML persistence;
saturated-market penalty line in the finance HUD; difficulty scaling tied to the
savegame's economic difficulty; procedural icon; EN/DE descriptions. Passes the
GIANTS TestRunner (single-player; multiplayer declared unsupported).

## Next — multiplayer & tuning depth

Headline: real multiplayer support. Plus a couple of smaller follow-ups. (The
"in-game settings menu" idea below is largely **superseded** — difficulty now
follows the savegame's economic difficulty automatically — but a menu could still
expose finer control later.)

---

### Issue: In-game settings menu

**Labels:** enhancement, v0.2
**Summary**

Expose the demand tuning in-game instead of only as code constants
(`DEFAULT_PRICE_FLOOR`, `DEFAULT_LITERS_FOR_FULL_DROP`), so players can adjust how
hard demand bites without editing Lua.

**Scope**
- Register a section into the game's settings UI (General/Gameplay settings
  frame) with, at minimum:
  - Price floor (e.g. 0.30–0.90).
  - Liters-for-full-drop (e.g. 20k–300k).
  - Enable/disable the saturated-market HUD line.
- Persist the settings per savegame (write alongside the demand XML, or into the
  savegame settings), and load on start.
- Apply live: settings feed `DemandModel` config on change.
- Server-authoritative: in MP the host's settings win (ties into the MP issue).

**Acceptance**
- Changing the floor/threshold in the menu visibly changes price behavior in the
  same session.
- Settings survive save/reload.
- No hard-coded English: label strings via l10n.

**Notes**
- Keep `DemandModel` pure; the menu writes into the config it already accepts.

---

### Issue: Optional multiplayer / dedicated-server support

**Labels:** enhancement, v0.2
**Summary**

Currently `modDesc` declares `<multiplayer supported="false"/>`. Demand is
mutated and saved server-side already; MP needs the client display path and
sync so joined players see the same reduced prices and penalty line.

**Scope**
- Server stays authoritative for demand state and persistence (already true).
- Sync demand → clients so `getEffectiveFillTypePrice` shows the reduced price on
  clients (initial full-state sync on join + incremental updates on sale). Use a
  proper event (`Event`/`writeStream`/`readStream`), not per-frame broadcast.
- Ensure the finance-HUD penalty line shows for the selling farm's clients.
- Flip `modDesc` to `supported="true"` only once tested on a listen server AND a
  dedicated server.

**Acceptance**
- Two-client MP: both see the same per-station prices; selling by one updates the
  other's displayed prices.
- Dedicated server: no errors; demand persists in the server savegame.

**Notes**
- Watch the per-tick sale rate — batch/coalesce sync so it doesn't flood the
  network.

---

### Issue (smaller): Localization pass + currency formatting

**Labels:** enhancement, good first issue, v0.2
- Add l10n for more languages (de, fr at least) for the "Saturated market" label
  and any settings strings.
- Consider `g_i18n:formatMoney` for the penalty amount if a formatted variant is
  wanted anywhere user-facing.

### Issue (smaller): Per-fillType / per-station tuning overrides

**Labels:** enhancement, v0.2
- Optional config (XML) to override floor/threshold for specific fill types or
  station types (e.g. perishables saturate faster). Off by default; global
  defaults unless overridden.
