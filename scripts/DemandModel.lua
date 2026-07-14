-- DemandModel.lua
-- PURE market-demand math. No GIANTS Engine calls of any kind, so this file can
-- be unit-tested in plain Lua (e.g. with the GIANTS TestRunner) and reasoned
-- about in isolation. All game integration lives in DemandStore / the hooks.
--
-- Model (version 0.1)
-- ------------------
-- Within a single monthly demand period, each (station, fillType) pair
-- accumulates the number of liters sold. The effective price multiplier drops
-- linearly from 1.0 toward a configurable floor as consumption approaches
-- `litersForFullDrop`:
--
--   fraction   = clamp(consumedLiters / litersForFullDrop, 0, 1)
--   multiplier = 1 - (1 - priceFloor) * fraction
--
-- The multiplier is continuous and never produces a hard cap: selling is always
-- allowed, it just pays progressively less. When a new period begins the caller
-- resets consumedLiters (handled in DemandStore), so prices recover.

DemandModel = {}
local DemandModel_mt = { __index = DemandModel }

-- Default tuning. Deliberately conservative for a first pass; expose/adjust
-- later. litersForFullDrop is "how many liters of one fill type sold at one
-- station, within one month, drives the price to the floor".
DemandModel.DEFAULT_PRICE_FLOOR = 0.55
DemandModel.DEFAULT_LITERS_FOR_FULL_DROP = 250000

--- Clamp a value to an inclusive range.
-- @param number value value to clamp
-- @param number lower lower bound
-- @param number upper upper bound
-- @return number clamped value in [lower, upper]
function DemandModel.clamp(value, lower, upper)
    if value < lower then
        return lower
    elseif value > upper then
        return upper
    end
    return value
end

--- Create a demand model with the given tuning.
-- @param table? config optional { priceFloor=number, litersForFullDrop=number }
-- @return DemandModel model a new model instance
function DemandModel.new(config)
    config = config or {}
    local self = setmetatable({}, DemandModel_mt)
    self.priceFloor = config.priceFloor or DemandModel.DEFAULT_PRICE_FLOOR
    self.litersForFullDrop = config.litersForFullDrop or DemandModel.DEFAULT_LITERS_FOR_FULL_DROP

    -- Guard against a nonsensical config that would divide by zero or invert
    -- the curve. Fall back to defaults rather than crash.
    if self.litersForFullDrop == nil or self.litersForFullDrop <= 0 then
        self.litersForFullDrop = DemandModel.DEFAULT_LITERS_FOR_FULL_DROP
    end
    self.priceFloor = DemandModel.clamp(self.priceFloor, 0, 1)

    return self
end

--- Compute the price multiplier for a given amount of consumed demand.
-- @param number consumedLiters liters already sold this period (>= 0)
-- @return number multiplier price multiplier in [priceFloor, 1.0]
function DemandModel:getMultiplier(consumedLiters)
    if consumedLiters == nil or consumedLiters <= 0 then
        return 1.0
    end

    local fraction = DemandModel.clamp(consumedLiters / self.litersForFullDrop, 0, 1)
    local multiplier = 1.0 - (1.0 - self.priceFloor) * fraction

    return DemandModel.clamp(multiplier, self.priceFloor, 1.0)
end
