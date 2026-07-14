-- DemandModel.test.lua
-- Standalone unit tests for the pure demand math. No GIANTS dependency, so this
-- runs under the GIANTS TestRunner or any plain Lua 5.1+ interpreter:
--
--   lua FS25_RealisticMarketDemand/tests/DemandModel.test.lua
--
-- Exits non-zero on the first failure.

-- Load the module under test relative to this file.
local here = (arg and arg[0] or ""):gsub("[^/\\]*$", "")
dofile(here .. "../scripts/DemandModel.lua")

local failures = 0

--- Assert two numbers are equal within a small epsilon.
local function assertClose(actual, expected, message)
    local epsilon = 1e-6
    if math.abs(actual - expected) > epsilon then
        print(string.format("FAIL: %s (expected %.6f, got %.6f)", message, expected, actual))
        failures = failures + 1
    else
        print(string.format("ok:   %s (%.6f)", message, actual))
    end
end

local model = DemandModel.new({ priceFloor = 0.55, litersForFullDrop = 250000 })

-- No demand -> full price.
assertClose(model:getMultiplier(0), 1.0, "zero consumption is full price")
assertClose(model:getMultiplier(-100), 1.0, "negative consumption is full price")

-- Half of litersForFullDrop -> halfway to the floor.
-- 1 - (1 - 0.55) * 0.5 = 0.775
assertClose(model:getMultiplier(125000), 0.775, "half consumption is halfway to floor")

-- Exactly litersForFullDrop -> the floor.
assertClose(model:getMultiplier(250000), 0.55, "full consumption hits the floor")

-- Beyond litersForFullDrop -> clamped at the floor (no hard cap, just no lower).
assertClose(model:getMultiplier(1000000), 0.55, "over-consumption is clamped to the floor")

-- Degenerate config falls back to defaults instead of crashing.
local safe = DemandModel.new({ priceFloor = 0.5, litersForFullDrop = 0 })
assertClose(safe.litersForFullDrop, DemandModel.DEFAULT_LITERS_FOR_FULL_DROP,
    "zero litersForFullDrop falls back to default")

-- priceFloor is clamped into [0, 1].
local clamped = DemandModel.new({ priceFloor = 5.0 })
assertClose(clamped.priceFloor, 1.0, "priceFloor above 1 is clamped to 1")

if failures > 0 then
    print(string.format("\n%d test(s) FAILED", failures))
    os.exit(1)
end
print("\nAll DemandModel tests passed")
