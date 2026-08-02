-- RealisticMarketDemand.lua
-- The single mod bootstrap instance. Registered with addModEventListener, it:
--   * builds the pure model + demand store on map load,
--   * loads persisted demand from the savegame,
--   * installs the SellingStation hooks (via MarketDemandHooks),
--   * installs a save hook so demand is written back on save,
--   * exposes getPriceMultiplier / recordSale as the `context` the hooks call,
--   * translates engine objects (stations, fill type indices) into the stable
--     string keys the store uses.
--
-- Server authority: demand is economy state, so it is only mutated and persisted
-- on the server. In single-player (v0.1) the local game is always the server.
--
-- Engine globals used here, with their source:
--   addModEventListener, g_currentModName, g_currentModDirectory - standard mod
--     bootstrap globals (used by the reference mods FS25_RealisticEconomy and
--     FS25_ZYX_SeasonalPrices).
--   g_currentMission, g_currentMission.missionInfo.savegameDirectory - verified
--     in ai/AISystem.lua:358 (subsystems write their own files into this dir).
--   g_currentMission:getIsServer() - used across the game source (e.g.
--     SeasonalPrices.lua:102 in the working mod).
--   g_fillTypeManager:getFillTypeNameByIndex - FillTypeManager is the fill type
--     registry (fillTypes/FillTypeManager.lua).
--   g_currentMission.environment:getPeriodAndAlphaIntoPeriod() - verified in the
--     working mod SeasonalPrices.lua:122; returns (period, alpha).
--   Placeable:getUniqueId() - verified in placeables/Placeable.lua:1179.

RealisticMarketDemand = {}

RealisticMarketDemand.MOD_NAME = g_currentModName
RealisticMarketDemand.MOD_DIRECTORY = g_currentModDirectory
RealisticMarketDemand.SAVE_FILENAME = "realisticMarketDemand.xml"

-- Saturated-market penalty notification tuning. Sales fire per-tick during an
-- unload, so penalties accumulate per (station, fillType) and a single toast is
-- shown once the flow has been idle for DEBOUNCE_MS.
RealisticMarketDemand.NOTIFY_DEBOUNCE_MS = 1200
RealisticMarketDemand.NOTIFY_DURATION_MS = 3000
RealisticMarketDemand.NOTIFY_MIN_AMOUNT = 100

--- Called by the mod event system once the map has finished loading.
-- @param string filename the loaded map filename (unused)
function RealisticMarketDemand:loadMap(filename)
    RMDLogging.info("Starting up (mod '%s')", tostring(RealisticMarketDemand.MOD_NAME))

    self.isServer = g_currentMission ~= nil and g_currentMission:getIsServer()
    if not self.isServer then
        RMDLogging.info("Not the server; demand state will not be tracked here")
    end

    self.model = DemandModel.new({
        priceFloor = DemandModel.DEFAULT_PRICE_FLOOR,
        litersForFullDrop = DemandModel.DEFAULT_LITERS_FOR_FULL_DROP,
    })
    self.store = DemandStore.new(self.model)
    self.warnedMissingKey = false
    self.loaded = false
    -- self.pendingPenalty[key] = { amount, fillTypeName, lastTime } accumulates
    -- the money lost to saturation across an unload, flushed to a toast in update().
    self.pendingPenalty = {}

    -- Try to restore persisted demand now. For existing savegames the savegame
    -- directory is often NOT populated yet at loadMap time (observed in-game), so
    -- ensureLoaded() retries lazily before the first price lookup or sale.
    self:ensureLoaded()

    -- The hooks call back into this instance as their `context`.
    MarketDemandHooks.install(self)

    self:installSaveHook()

    RMDLogging.info("Startup complete (floor=%.2f, litersForFullDrop=%d)",
        self.model.priceFloor, self.model.litersForFullDrop)
end

--- Called by the mod event system when the map is unloaded.
function RealisticMarketDemand:deleteMap()
    RMDLogging.info("Shutting down")
    self.model = nil
    self.store = nil
    self.loaded = false
    self.pendingPenalty = {}
end

------------------------------------------------------------
-- context interface (called by MarketDemandHooks)
------------------------------------------------------------

--- Price multiplier for a station/fillType. Read-only; safe to call often.
-- @param table station the SellingStation instance
-- @param number fillTypeIndex runtime fill type index
-- @return number multiplier price multiplier in [priceFloor, 1.0]
function RealisticMarketDemand:getPriceMultiplier(station, fillTypeIndex)
    if self.store == nil then
        return 1.0
    end
    self:ensureLoaded()

    local stationKey = self:getStationKey(station)
    local fillTypeName = self:getFillTypeName(fillTypeIndex)
    if stationKey == nil or fillTypeName == nil then
        return 1.0
    end

    return self.store:getMultiplier(stationKey, fillTypeName, self:getCurrentPeriod())
end

--- Handle a completed sale tick: consume demand and accumulate the saturation
-- penalty for the point-of-sale toast. Server-only, write path.
-- @param table station the SellingStation instance
-- @param number fillDelta liters just sold
-- @param number fillTypeIndex runtime fill type index
-- @param number pricePaid money the vanilla sellFillType actually paid
-- @param number preMultiplier the demand multiplier that applied to this sale
function RealisticMarketDemand:onSale(station, fillDelta, fillTypeIndex, pricePaid, preMultiplier)
    if not self.isServer or self.store == nil then
        return
    end
    if fillDelta == nil or fillDelta <= 0 then
        return
    end
    self:ensureLoaded()

    local stationKey = self:getStationKey(station)
    local fillTypeName = self:getFillTypeName(fillTypeIndex)
    if stationKey == nil or fillTypeName == nil then
        return
    end

    local period = self:getCurrentPeriod()
    self.store:recordSale(stationKey, fillTypeName, fillDelta, period)
    self:accumulatePenalty(stationKey, fillTypeName, pricePaid, preMultiplier)

    RMDLogging.debug(
        "SALE station=%s fill=%s liters=%.0f paid=%.0f mult=%.4f consumed=%.0f",
        stationKey, fillTypeName, fillDelta or 0, pricePaid or 0, preMultiplier or 1.0,
        self.store:getConsumedLiters(stationKey, fillTypeName))
end

--- Accumulate the money lost to saturation for this sale tick. The penalty is
-- the difference between what a fresh market would have paid and what was paid:
-- pricePaid / mult - pricePaid. Only tracked when demand actually reduced price.
-- @param string stationKey stable station key
-- @param string fillTypeName fill type name
-- @param number pricePaid money paid this tick
-- @param number preMultiplier the multiplier that applied (< 1 means saturated)
function RealisticMarketDemand:accumulatePenalty(stationKey, fillTypeName, pricePaid, preMultiplier)
    if pricePaid == nil or pricePaid <= 0 then
        return
    end
    if preMultiplier == nil or preMultiplier <= 0 or preMultiplier >= 1.0 then
        return
    end

    local penalty = pricePaid * (1.0 - preMultiplier) / preMultiplier
    local key = stationKey .. "|" .. fillTypeName
    local pending = self.pendingPenalty[key]
    if pending == nil then
        pending = { amount = 0, fillTypeName = fillTypeName }
        self.pendingPenalty[key] = pending
    end
    pending.amount = pending.amount + penalty
    pending.lastTime = g_time
end

--- Mod event callback. Flushes accumulated saturation penalties to a toast once
-- the unload flow for a (station, fillType) has been idle past the debounce.
-- @param number dt frame delta in ms (unused; we debounce on g_time)
function RealisticMarketDemand:update(dt)
    if self.pendingPenalty == nil then
        return
    end
    for key, pending in pairs(self.pendingPenalty) do
        if g_time - pending.lastTime > RealisticMarketDemand.NOTIFY_DEBOUNCE_MS then
            if pending.amount >= RealisticMarketDemand.NOTIFY_MIN_AMOUNT then
                self:showPenaltyNotification(pending.fillTypeName, pending.amount)
            end
            self.pendingPenalty[key] = nil
        end
    end
end

--- Show a brief on-screen "saturated market" penalty notice.
-- @param string fillTypeName fill type name
-- @param number amount money lost to saturation this unload
function RealisticMarketDemand:showPenaltyNotification(fillTypeName, amount)
    if g_currentMission == nil or g_currentMission.showBlinkingWarning == nil then
        return
    end
    -- TODO(l10n): move to an l10n string and use g_i18n:formatMoney for currency.
    local text = string.format("Saturated market (%s): -%d", tostring(fillTypeName), math.floor(amount))
    g_currentMission:showBlinkingWarning(text, RealisticMarketDemand.NOTIFY_DURATION_MS)
    RMDLogging.debug("Penalty notice: %s", text)
end

------------------------------------------------------------
-- save / load wiring
------------------------------------------------------------

--- Load persisted demand once the savegame directory is available. Safe to call
-- repeatedly and from hot paths: it is a no-op after the first successful load
-- (or if the directory is not ready yet, it simply retries on the next call).
function RealisticMarketDemand:ensureLoaded()
    if self.loaded or self.store == nil then
        return
    end
    local savePath = self:getSavePath()
    if savePath == nil then
        -- Savegame directory not ready yet (common at loadMap for existing
        -- saves); try again on the next price lookup or sale.
        return
    end
    self.store:loadFromFile(savePath)
    self.loaded = true
end

--- Absolute path of this mod's per-savegame demand file, or nil if unavailable.
-- @return string? path
function RealisticMarketDemand:getSavePath()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return nil
    end
    local dir = g_currentMission.missionInfo.savegameDirectory
    if dir == nil then
        return nil
    end
    return dir .. "/" .. RealisticMarketDemand.SAVE_FILENAME
end

--- Write demand state to the savegame. Called by the save hook.
function RealisticMarketDemand:onSave()
    if not self.isServer or self.store == nil then
        return
    end
    local savePath = self:getSavePath()
    if savePath == nil then
        RMDLogging.warn("Save requested but no savegame directory; skipping")
        return
    end
    self.store:saveToFile(savePath)
end

--- Install a hook that fires when the career/savegame is written.
-- NOTE: FSCareerMissionInfo.saveToXMLFile is the de-facto community seam used by
-- many FS22/FS25 mods, but it is NOT present in the stripped SDK game source, so
-- it must be confirmed in-game. It is isolated here so swapping the seam (e.g.
-- to a different save entry point) is a one-line change if verification fails.
function RealisticMarketDemand:installSaveHook()
    if FSCareerMissionInfo == nil or FSCareerMissionInfo.saveToXMLFile == nil then
        RMDLogging.warn("FSCareerMissionInfo.saveToXMLFile unavailable; demand will not persist (needs in-game verification)")
        return
    end

    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(
        FSCareerMissionInfo.saveToXMLFile,
        function(...)
            RealisticMarketDemand:onSave()
        end
    )
    RMDLogging.info("Installed save hook on FSCareerMissionInfo.saveToXMLFile")
end

------------------------------------------------------------
-- key / lookup helpers
------------------------------------------------------------

--- Stable string key for a selling station, preferring the owning placeable's
-- uniqueId (persistent across sessions). Falls back to the station name.
-- @param table station the SellingStation instance
-- @return string? key
function RealisticMarketDemand:getStationKey(station)
    if station == nil then
        return nil
    end

    local placeable = station.owningPlaceable
    if placeable ~= nil and placeable.getUniqueId ~= nil then
        local uniqueId = placeable:getUniqueId()
        if uniqueId ~= nil and uniqueId ~= "" then
            return uniqueId
        end
    end

    -- Fallback: station name. Less robust across sessions; warn once so the
    -- reason for any demand "reset" after reload is visible in the log.
    if station.stationName ~= nil then
        if not self.warnedMissingKey then
            RMDLogging.warn("A selling station has no placeable uniqueId; falling back to name keys")
            self.warnedMissingKey = true
        end
        return "name:" .. tostring(station.stationName)
    end

    return nil
end

--- Fill type name for a runtime index, or nil if the manager is unavailable.
-- @param number fillTypeIndex runtime fill type index
-- @return string? fillTypeName
function RealisticMarketDemand:getFillTypeName(fillTypeIndex)
    if fillTypeIndex == nil or g_fillTypeManager == nil then
        return nil
    end
    return g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
end

--- Current monthly demand period (1..12), defaulting to 1 if unavailable.
-- @return number period
function RealisticMarketDemand:getCurrentPeriod()
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    if env ~= nil and env.getPeriodAndAlphaIntoPeriod ~= nil then
        local period = env:getPeriodAndAlphaIntoPeriod()
        if period ~= nil then
            return period
        end
    end
    return 1
end

-- Register the single bootstrap instance with the mod event system. This is the
-- entry point; loadMap()/deleteMap() above are invoked by the engine.
addModEventListener(RealisticMarketDemand)
