-- DemandStore.test.lua
-- Tests the demand state logic: period retention/reset, the annual-wrap
-- regression (demand keyed on an absolute period id must NOT come back a year
-- later), and station/fillType isolation. Runs under plain Lua 5.1+ or the
-- GIANTS TestRunner:
--
--   lua FS25_RealisticMarketDemand/tests/DemandStore.test.lua
--
-- recordSale/getMultiplier/getConsumedLiters are pure (no GIANTS/XML calls), so
-- no engine stubs are needed. Exits non-zero on the first failure.

local here = (arg and arg[0] or ""):gsub("[^/\\]*$", "")
dofile(here .. "../scripts/DemandModel.lua")
dofile(here .. "../scripts/DemandStore.lua")

local failures = 0

local function assertClose(actual, expected, message)
    if math.abs(actual - expected) > 1e-6 then
        print(string.format("FAIL: %s (expected %.6f, got %.6f)", message, expected, actual))
        failures = failures + 1
    else
        print(string.format("ok:   %s (%.6f)", message, actual))
    end
end

local function newStore()
    -- floor 0.5 at 100k L: consumed 100k -> 0.5, 50k -> 0.75, 20k -> 0.90.
    return DemandStore.new(DemandModel.new({ priceFloor = 0.5, litersForFullDrop = 100000 }))
end

-- 1) Same period retains accumulated consumption.
local s = newStore()
s:recordSale("station-A", "WHEAT", 100000, 42)
assertClose(s:getMultiplier("station-A", "WHEAT", 42), 0.5, "same period retains consumption")
assertClose(s:getConsumedLiters("station-A", "WHEAT"), 100000, "consumption accumulated")

-- 2) A new period resets consumption (fresh market).
s:recordSale("station-A", "WHEAT", 20000, 43)
assertClose(s:getConsumedLiters("station-A", "WHEAT"), 20000, "new period resets accumulation")
assertClose(s:getMultiplier("station-A", "WHEAT", 43), 0.9, "new period multiplier reflects only new sales")

-- 3) ANNUAL-WRAP REGRESSION: saturate at one period id, query at a later id.
--    With an absolute period id, "period 8 next year" is a different id, so the
--    old demand must NOT be treated as current -> full price.
local wrap = newStore()
wrap:recordSale("station-A", "WHEAT", 100000, 8)   -- saturated during period id 8
assertClose(wrap:getMultiplier("station-A", "WHEAT", 8), 0.5, "retained within the same period id")
assertClose(wrap:getMultiplier("station-A", "WHEAT", 20), 1.0, "stale period id yields full price (no annual comeback)")

-- 4) Stations are independent.
local iso = newStore()
iso:recordSale("station-A", "WHEAT", 100000, 42)
assertClose(iso:getMultiplier("station-B", "WHEAT", 42), 1.0, "different station is unaffected")

-- 5) Fill types are independent.
assertClose(iso:getMultiplier("station-A", "BARLEY", 42), 1.0, "different fill type is unaffected")

-- 6) Untracked pair is full price.
assertClose(iso:getMultiplier("station-Z", "OAT", 1), 1.0, "untracked pair is full price")

if failures > 0 then
    print(string.format("\n%d test(s) FAILED", failures))
    os.exit(1)
end
print("\nAll DemandStore tests passed")
