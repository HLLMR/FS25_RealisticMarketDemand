-- MarketDemandHooks.lua
-- The thin GIANTS-integration layer: installs two overwrites on SellingStation.
-- All demand state and math lives behind the `context` object passed to
-- install(); this file only translates engine calls into context calls and
-- preserves original behavior via superFunc chaining.
--
-- Hook points (both verified in the supplied game source / a working mod):
--
--   SellingStation:getEffectiveFillTypePrice(fillTypeIndex) -> pricePerLiter
--     Verified as an overwrite target in the working mod FS25_ZYX_SeasonalPrices
--     (SeasonalPrices.lua: `SellingStation.getEffectiveFillTypePrice =
--     Utils.overwrittenFunction(...)`), and called along the sell path in
--     PlaceableSilo.lua:334 / PlaceableSiloExtension.lua:200. We scale its
--     return value by the demand multiplier, so both the money paid and the UI
--     price fall together.
--
--   SellingStation:sellFillType(farmId, fillDelta, fillTypeIndex, toolType, extraAttributes) -> price
--     Verified as the seam GIANTS' own precisionFarming mod overwrites
--     (internalMods/FS25_precisionFarming/.../EnvironmentalScore.lua:646). We do
--     NOT change the money here; we only record `fillDelta` (liters sold) so the
--     NEXT sale sees increased demand. Recording happens after superFunc so the
--     current sale is priced at the pre-consumption multiplier.
--
-- Utils.overwrittenFunction calls the replacement as (self, superFunc, ...),
-- and superFunc must be invoked as superFunc(self, ...). Verified in
-- utils/Utils.lua:750 and both reference mods above.

MarketDemandHooks = {}

MarketDemandHooks.isInstalled = false

--- Install the SellingStation overwrites.
-- @param table context object exposing:
--   context:getPriceMultiplier(station, fillTypeIndex) -> number
--   context:recordSale(station, fillDelta, fillTypeIndex) -> void
-- @return boolean success true if both hooks were installed
function MarketDemandHooks.install(context)
    if SellingStation == nil then
        RMDLogging.error("SellingStation class not found; cannot install hooks")
        return false
    end

    -- Guard against double-wrapping. The marker lives on the SellingStation class
    -- itself (not on this module), so it survives a mod-script reload (e.g. via
    -- Easy Dev Controls) that would otherwise reset a module-level flag and
    -- stack a second wrapper on top of the first.
    if SellingStation.rmdHooksInstalled then
        RMDLogging.warn("Hooks already present on SellingStation; skipping re-install")
        return false
    end

    if SellingStation.getEffectiveFillTypePrice == nil or SellingStation.sellFillType == nil then
        RMDLogging.error("Expected SellingStation methods missing; cannot install hooks")
        return false
    end

    -- 1) Price scaling. Reduce the effective per-liter price by the current
    --    demand multiplier for this (station, fillType).
    SellingStation.getEffectiveFillTypePrice = Utils.overwrittenFunction(
        SellingStation.getEffectiveFillTypePrice,
        function(station, superFunc, fillTypeIndex, ...)
            local basePrice = superFunc(station, fillTypeIndex, ...)
            if basePrice == nil then
                return basePrice
            end

            local multiplier = context:getPriceMultiplier(station, fillTypeIndex)
            return basePrice * multiplier
        end
    )
    RMDLogging.info("Installed SellingStation.getEffectiveFillTypePrice hook")

    -- 2) Demand recording. Consume demand equal to the liters just sold. The
    --    multiplier is read BEFORE superFunc so the diagnostic reflects the
    --    multiplier that actually applied to this sale (recordSale then advances
    --    demand for the next one).
    SellingStation.sellFillType = Utils.overwrittenFunction(
        SellingStation.sellFillType,
        function(station, superFunc, farmId, fillDelta, fillTypeIndex, toolType, extraAttributes)
            local preMultiplier = context:getPriceMultiplier(station, fillTypeIndex)
            local price = superFunc(station, farmId, fillDelta, fillTypeIndex, toolType, extraAttributes)
            context:onSale(station, fillDelta, fillTypeIndex, price, preMultiplier)
            return price
        end
    )
    RMDLogging.info("Installed SellingStation.sellFillType hook")

    SellingStation.rmdHooksInstalled = true
    MarketDemandHooks.isInstalled = true
    return true
end
