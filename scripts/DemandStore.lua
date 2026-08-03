-- DemandStore.lua
-- Holds the per-(station, fillType) demand state and persists it to XML.
--
-- Keys:
--   stationKey   - a stable string identifying a selling station (the owning
--                  placeable's uniqueId when available; see RealisticMarketDemand:getStationKey).
--   fillTypeName - the fill type NAME (e.g. "WHEAT"), NOT its runtime index.
--                  Names are stable across sessions and mod-list changes;
--                  indices are not.
--
-- Each entry records liters consumed this period and the period tag it belongs
-- to. On a read (getMultiplier) a stale period yields a full-price multiplier
-- without mutating state; the actual reset happens on the next recorded sale so
-- that reads stay side-effect free (they run on displays, possibly every frame).
--
-- Persistence uses the engine's handle-based XML functions, all verified against
-- sdk/debugger/scriptBinding.xml:
--   createXMLFile / loadXMLFile / saveXMLFile / delete
--   setXMLString / getXMLString / setXMLFloat / getXMLFloat / setXMLInt /
--   getXMLInt / hasXMLProperty

DemandStore = {}
local DemandStore_mt = { __index = DemandStore }

DemandStore.ROOT_NODE = "realisticMarketDemand"
DemandStore.XML_OBJECT_NAME = "RealisticMarketDemand"

--- Create a demand store backed by the given pure model.
-- @param DemandModel model the price-multiplier model to consult
-- @return DemandStore store a new, empty store
function DemandStore.new(model)
    local self = setmetatable({}, DemandStore_mt)
    self.model = model
    -- self.entries[stationKey][fillTypeName] = { consumedLiters=number, period=number }
    self.entries = {}
    -- Chosen difficulty preset key ("easy"|"normal"|"hard"), persisted with the
    -- savegame so the setting survives reloads.
    self.presetKey = nil
    return self
end

--- Remove all tracked demand. Logged by the caller.
function DemandStore:reset()
    self.entries = {}
end

--- Internal: fetch (optionally creating) the record for a station/fillType.
-- @param string stationKey stable station key
-- @param string fillTypeName fill type name
-- @param boolean create create the record if missing
-- @return table? record { consumedLiters, period } or nil
local function getRecord(self, stationKey, fillTypeName, create)
    local stationEntries = self.entries[stationKey]
    if stationEntries == nil then
        if not create then
            return nil
        end
        stationEntries = {}
        self.entries[stationKey] = stationEntries
    end

    local record = stationEntries[fillTypeName]
    if record == nil and create then
        record = { consumedLiters = 0, period = 0 }
        stationEntries[fillTypeName] = record
    end
    return record
end

--- Record a completed sale, advancing demand for this station/fillType.
-- Resets accumulated demand first if the stored period differs from the current
-- one (i.e. a new month has started).
-- @param string stationKey stable station key
-- @param string fillTypeName fill type name
-- @param number liters liters just sold (> 0)
-- @param number currentPeriod current monthly period tag
function DemandStore:recordSale(stationKey, fillTypeName, liters, currentPeriod)
    if stationKey == nil or fillTypeName == nil or liters == nil or liters <= 0 then
        return
    end

    local record = getRecord(self, stationKey, fillTypeName, true)
    if record.period ~= currentPeriod then
        record.consumedLiters = 0
        record.period = currentPeriod
    end
    record.consumedLiters = record.consumedLiters + liters
end

--- Get the current price multiplier for a station/fillType. Read-only.
-- @param string stationKey stable station key
-- @param string fillTypeName fill type name
-- @param number currentPeriod current monthly period tag
-- @return number multiplier price multiplier in [priceFloor, 1.0]
function DemandStore:getMultiplier(stationKey, fillTypeName, currentPeriod)
    local record = getRecord(self, stationKey, fillTypeName, false)
    if record == nil or record.period ~= currentPeriod then
        -- No demand tracked yet, or demand belongs to a past period -> full price.
        return 1.0
    end
    return self.model:getMultiplier(record.consumedLiters)
end

--- Get the accumulated consumption for diagnostics.
-- @param string stationKey stable station key
-- @param string fillTypeName fill type name
-- @return number consumedLiters liters consumed for the stored period (0 if none)
function DemandStore:getConsumedLiters(stationKey, fillTypeName)
    local record = getRecord(self, stationKey, fillTypeName, false)
    if record == nil then
        return 0
    end
    return record.consumedLiters
end

--- Persist all demand state to an XML file at the given path.
-- @param string path absolute file path to write
-- @return boolean success true if the file was created and saved
function DemandStore:saveToFile(path)
    local xmlId = createXMLFile(DemandStore.XML_OBJECT_NAME, path, DemandStore.ROOT_NODE)
    if xmlId == nil or xmlId == 0 then
        RMDLogging.error("Could not create save file at %s", tostring(path))
        return false
    end

    if self.presetKey ~= nil then
        setXMLString(xmlId, DemandStore.ROOT_NODE .. "#preset", self.presetKey)
    end

    local stationIndex = 0
    for stationKey, fillTypes in pairs(self.entries) do
        local stationPath = string.format("%s.station(%d)", DemandStore.ROOT_NODE, stationIndex)
        setXMLString(xmlId, stationPath .. "#key", stationKey)

        local demandIndex = 0
        for fillTypeName, record in pairs(fillTypes) do
            local demandPath = string.format("%s.demand(%d)", stationPath, demandIndex)
            setXMLString(xmlId, demandPath .. "#fillType", fillTypeName)
            setXMLFloat(xmlId, demandPath .. "#consumedLiters", record.consumedLiters)
            setXMLInt(xmlId, demandPath .. "#period", record.period)
            demandIndex = demandIndex + 1
        end
        stationIndex = stationIndex + 1
    end

    saveXMLFile(xmlId)
    delete(xmlId)
    RMDLogging.info("Saved demand for %d station(s) to %s", stationIndex, tostring(path))
    return true
end

--- Load demand state from an XML file, replacing any current state.
-- Missing file is not an error (fresh savegame) and returns false quietly.
-- @param string path absolute file path to read
-- @return boolean success true if a file was found and parsed
function DemandStore:loadFromFile(path)
    local xmlId = loadXMLFile(DemandStore.XML_OBJECT_NAME, path)
    if xmlId == nil or xmlId == 0 then
        RMDLogging.info("No existing demand file at %s (fresh start)", tostring(path))
        return false
    end

    self:reset()
    self.presetKey = getXMLString(xmlId, DemandStore.ROOT_NODE .. "#preset")

    local stationIndex = 0
    while true do
        local stationPath = string.format("%s.station(%d)", DemandStore.ROOT_NODE, stationIndex)
        if not hasXMLProperty(xmlId, stationPath) then
            break
        end

        local stationKey = getXMLString(xmlId, stationPath .. "#key")
        if stationKey ~= nil then
            local demandIndex = 0
            while true do
                local demandPath = string.format("%s.demand(%d)", stationPath, demandIndex)
                if not hasXMLProperty(xmlId, demandPath) then
                    break
                end

                local fillTypeName = getXMLString(xmlId, demandPath .. "#fillType")
                local consumedLiters = getXMLFloat(xmlId, demandPath .. "#consumedLiters") or 0
                local period = getXMLInt(xmlId, demandPath .. "#period") or 0

                if fillTypeName ~= nil then
                    local record = getRecord(self, stationKey, fillTypeName, true)
                    record.consumedLiters = consumedLiters
                    record.period = period
                end
                demandIndex = demandIndex + 1
            end
        end
        stationIndex = stationIndex + 1
    end

    delete(xmlId)
    RMDLogging.info("Loaded demand for %d station(s) from %s", stationIndex, tostring(path))
    return true
end
