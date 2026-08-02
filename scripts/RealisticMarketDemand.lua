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

--- Record a completed sale, consuming demand. Server-only, write path.
-- @param table station the SellingStation instance
-- @param number fillDelta liters just sold
-- @param number fillTypeIndex runtime fill type index
function RealisticMarketDemand:recordSale(station, fillDelta, fillTypeIndex)
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
end

--- Diagnostic log for a single sale (validation aid). Off unless debug enabled.
-- Logs the price the game actually paid alongside our pre-sale multiplier, so
-- the price-linkage assumption can be confirmed from the log.
-- @param table station the SellingStation instance
-- @param number fillTypeIndex runtime fill type index
-- @param number fillDelta liters sold
-- @param number pricePaid money returned by the vanilla sellFillType
-- @param number multiplier the demand multiplier that applied to this sale
function RealisticMarketDemand:logSale(station, fillTypeIndex, fillDelta, pricePaid, multiplier)
    if not RMDLogging.debugEnabled then
        return
    end
    local stationKey = self:getStationKey(station) or "?"
    local fillTypeName = self:getFillTypeName(fillTypeIndex) or "?"
    local perLiter = (fillDelta ~= nil and fillDelta > 0) and (pricePaid or 0) / fillDelta or 0
    RMDLogging.debug(
        "SALE station=%s fill=%s liters=%.0f paid=%.0f perLiterPaid=%.4f mult=%.4f consumed=%.0f",
        stationKey, fillTypeName, fillDelta or 0, pricePaid or 0, perLiter, multiplier or 1.0,
        self.store:getConsumedLiters(stationKey, fillTypeName))
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
