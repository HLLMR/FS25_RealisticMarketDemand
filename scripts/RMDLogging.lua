-- RMDLogging.lua
-- Tiny logging helper for the Realistic Market Demand mod.
--
-- All output is prefixed with [RealisticMarketDemand] as required by the
-- project conventions. Uses the Lua global print(), which is always available
-- in the GIANTS engine, so this module has no GIANTS API dependency and stays
-- trivially correct.

RMDLogging = {}

RMDLogging.PREFIX = "[RealisticMarketDemand]"

-- Set to true to see per-sale demand math in the log. Kept off by default so a
-- normal play session is not spammed.
-- NOTE: temporarily ON during v0.1 in-game validation; set back to false before
-- release packaging.
RMDLogging.debugEnabled = true

--- Internal: format and print a single line at a given level.
-- @param string level level tag, e.g. "INFO"
-- @param string message format string (string.format style)
-- @param ... any format arguments
local function emit(level, message, ...)
    local body = message
    if select("#", ...) > 0 then
        body = string.format(message, ...)
    end
    print(string.format("%s %s: %s", RMDLogging.PREFIX, level, body))
end

--- Log an informational message (startup, hook install, save/load, reset).
-- @param string message format string
-- @param ... any format arguments
function RMDLogging.info(message, ...)
    emit("INFO", message, ...)
end

--- Log a warning (recoverable/unexpected condition).
-- @param string message format string
-- @param ... any format arguments
function RMDLogging.warn(message, ...)
    emit("WARN", message, ...)
end

--- Log an error (a hook or operation could not complete).
-- @param string message format string
-- @param ... any format arguments
function RMDLogging.error(message, ...)
    emit("ERROR", message, ...)
end

--- Log a debug message; suppressed unless RMDLogging.debugEnabled is true.
-- @param string message format string
-- @param ... any format arguments
function RMDLogging.debug(message, ...)
    if RMDLogging.debugEnabled then
        emit("DEBUG", message, ...)
    end
end
