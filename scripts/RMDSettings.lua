-- RMDSettings.lua
-- Injects a single "Market demand saturation" control (Easy / Normal / Hard) into
-- the in-game General Settings menu.
--
-- IMPORTANT: FS25 ships the settings-menu frames STRIPPED in the SDK, so the exact
-- frame/element structure can't be verified from sources. This module is written
-- defensively — every step is nil-guarded and logged, and any failure here leaves
-- the demand mechanic completely unaffected. On first open it also dumps the
-- settings frame's element tree to the log (debug) so the exact ids can be pinned
-- down and the clone target refined if needed.
--
-- API used (verified): MultiTextOptionElement:setState/getState/setTexts
-- (gui/elements/MultiTextOptionElement.lua), GuiElement.elements (children),
-- Utils.appendedFunction (utils/Utils.lua). The in-game menu instance is
-- g_currentMission.inGameMenu with a persistent `pageSettings` frame (referenced
-- in gui/InGameMenu.lua).

RMDSettings = {}

RMDSettings.context = nil        -- the RealisticMarketDemand bootstrap
RMDSettings.PRESET_ORDER = { "easy", "normal", "hard" }
RMDSettings.hooked = false

--- Install: hook the settings frame's open so we can inject/refresh our control.
-- @param table context the RealisticMarketDemand bootstrap (getPreset/setPreset)
function RMDSettings.install(context)
    RMDSettings.context = context

    if RMDSettings.hooked then
        return
    end

    local menu = g_currentMission ~= nil and g_currentMission.inGameMenu or nil
    local frame = menu ~= nil and menu.pageSettings or nil
    if frame == nil then
        RMDLogging.warn("Settings: in-game menu / pageSettings not available; skipping menu control")
        return
    end
    if frame.onFrameOpen == nil then
        RMDLogging.warn("Settings: pageSettings has no onFrameOpen; skipping menu control")
        return
    end

    frame.onFrameOpen = Utils.appendedFunction(frame.onFrameOpen, function(f)
        RMDSettings.onSettingsOpen(f)
    end)
    RMDSettings.hooked = true
    RMDLogging.info("Settings: hooked pageSettings.onFrameOpen")
end

--- Called each time the settings page opens. Injects once, then refreshes state.
-- @param table frame the settings frame instance
function RMDSettings.onSettingsOpen(frame)
    if frame == nil then
        return
    end

    if not frame.rmdDumped then
        frame.rmdDumped = true
        RMDSettings.dumpTree(frame, 0, { count = 0 })
    end

    if frame.rmdControl ~= nil then
        RMDSettings.refresh(frame)
        return
    end

    local ok = RMDSettings.inject(frame)
    if ok then
        RMDLogging.info("Settings: injected 'Market demand saturation' control")
    else
        RMDLogging.warn("Settings: could not inject control (see element dump above)")
    end
end

--- Recursively find the first MultiTextOptionElement in a subtree.
-- @param table element root
-- @return table? the first multi-text option element
function RMDSettings.findMultiOption(element)
    if element == nil or element.elements == nil then
        return nil
    end
    for _, child in ipairs(element.elements) do
        local tn = child.typeName
        if (MultiTextOptionElement ~= nil and child.isa ~= nil and child:isa(MultiTextOptionElement))
            or tn == "multiTextOption" or tn == "multiTextOptionElement" then
            return child
        end
        local found = RMDSettings.findMultiOption(child)
        if found ~= nil then
            return found
        end
    end
    return nil
end

--- Best-effort injection: clone an existing option row, relabel it Easy/Normal/
-- Hard, wire the callback, and add it to the same container. Fully guarded.
-- @param table frame the settings frame instance
-- @return boolean success
function RMDSettings.inject(frame)
    local template = RMDSettings.findMultiOption(frame)
    if template == nil then
        RMDLogging.warn("Settings: no MultiTextOptionElement template found in frame")
        return false
    end

    local row = template.parent
    if row == nil or row.parent == nil then
        RMDLogging.warn("Settings: option template has no usable parent row")
        return false
    end
    local container = row.parent

    local clonedRow = row:clone(container)
    if clonedRow == nil then
        RMDLogging.warn("Settings: row clone failed")
        return false
    end

    local option = RMDSettings.findMultiOption(clonedRow)
    if option == nil then
        RMDLogging.warn("Settings: cloned row has no option element")
        return false
    end

    -- Label texts for the three presets.
    local texts = {
        RMDSettings.l10n("rmd_presetEasy", "Easy"),
        RMDSettings.l10n("rmd_presetNormal", "Normal"),
        RMDSettings.l10n("rmd_presetHard", "Hard"),
    }
    if option.setTexts ~= nil then
        option:setTexts(texts)
    else
        option.texts = texts
    end

    -- Wire the change callback to us.
    option.target = RMDSettings
    if option.setCallback ~= nil then
        option:setCallback("onClickCallback", "onPresetChanged")
    else
        option.onClickCallback = function(_, state, element) RMDSettings.onPresetChanged(RMDSettings, state, element) end
    end

    -- Set the row's title/label text if we can find a text element in the row.
    RMDSettings.setRowTitle(clonedRow, option, RMDSettings.l10n("rmd_settingTitle", "Market demand saturation"))

    frame.rmdControl = option
    frame.rmdRow = clonedRow

    if container.invalidateLayout ~= nil then
        container:invalidateLayout()
    end

    RMDSettings.refresh(frame)
    return true
end

--- Set the descriptive label on the cloned row (first text element that isn't the
-- option's own value text).
function RMDSettings.setRowTitle(row, option, title)
    if row == nil or row.elements == nil then
        return
    end
    for _, child in ipairs(row.elements) do
        if child ~= option and child.setText ~= nil and child.typeName ~= nil
            and (child.typeName == "text" or child.typeName == "textElement") then
            child:setText(title)
            return
        end
    end
end

--- Push the current preset into the control's state.
function RMDSettings.refresh(frame)
    local option = frame.rmdControl
    if option == nil or option.setState == nil or RMDSettings.context == nil then
        return
    end
    local key = RMDSettings.context:getPreset()
    for i, presetKey in ipairs(RMDSettings.PRESET_ORDER) do
        if presetKey == key then
            option:setState(i, false)
            return
        end
    end
    option:setState(2, false) -- default to normal
end

--- Control callback: map the selected state to a preset key.
function RMDSettings:onPresetChanged(state, element)
    local key = RMDSettings.PRESET_ORDER[state]
    if key == nil or RMDSettings.context == nil then
        return
    end
    RMDSettings.context:setPreset(key)
end

--- l10n helper with an English fallback.
function RMDSettings.l10n(key, fallback)
    if g_i18n ~= nil and g_i18n.hasText ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    return fallback
end

--- Debug: dump a GUI element subtree (id/name/type) to help pin down the frame.
function RMDSettings.dumpTree(element, depth, state)
    if not RMDLogging.debugEnabled or element == nil or depth > 6 or state.count > 250 then
        return
    end
    state.count = state.count + 1
    local id = element.id or element.name or "?"
    RMDLogging.debug("  frametree[%d] type=%s id=%s", depth, tostring(element.typeName), tostring(id))
    if element.elements ~= nil then
        for _, child in ipairs(element.elements) do
            RMDSettings.dumpTree(child, depth + 1, state)
        end
    end
end
