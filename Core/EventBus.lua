local _, AGC = ...
AGC.EventBus = {}

local EventBus = AGC.EventBus

------------------------------------------------------------------------
-- Internal state
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local pendingRefresh = false

local REFRESH_EVENTS = {
    "PLAYER_EQUIPMENT_CHANGED",
    "UNIT_INVENTORY_CHANGED",
    "SKILL_LINES_CHANGED",
    "BAG_UPDATE_DELAYED",
    "CHAT_MSG_LOOT",
}

------------------------------------------------------------------------
-- Debounced refresh (collapses rapid event bursts into one scan)
------------------------------------------------------------------------

local function ScheduleRefresh()
    if pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0.1, function()
        pendingRefresh = false
        if AGC.OnRefresh then
            AGC:OnRefresh()
        end
    end)
end

------------------------------------------------------------------------
-- Event handler
------------------------------------------------------------------------

local function OnEvent(_, event, arg1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ScheduleRefresh()
        return
    end
    -- Only react to the player's own inventory changes
    if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
        return
    end
    ScheduleRefresh()
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

function EventBus:Init()
    frame:SetScript("OnEvent", OnEvent)
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    for _, ev in ipairs(REFRESH_EVENTS) do
        frame:RegisterEvent(ev)
    end

    -- Hook the character frame to trigger refresh on open / hide overlay on close
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function()
            ScheduleRefresh()
        end)
        CharacterFrame:HookScript("OnHide", function()
            AGC.Overlay:Hide()
        end)
    end

    -- Hook PanelTemplates tab switching so labels show/hide instantly
    -- when switching between Character, Reputation, Currency, etc.
    -- The Character/Equipment tab is always tab index 1.
    if CharacterFrame then
        -- Hook each tab button's OnClick
        local numTabs = CharacterFrame.numTabs or 4
        for i = 1, numTabs do
            local tab = _G["CharacterFrameTab" .. i]
            if tab then
                tab:HookScript("OnClick", function()
                    if i == 1 then
                        ScheduleRefresh()
                    else
                        AGC.Overlay:Hide()
                    end
                end)
            end
        end

        -- Also hook PanelTemplates_SetTab if available (catches programmatic tab switches)
        if PanelTemplates_SetTab then
            hooksecurefunc("PanelTemplates_SetTab", function(frame, id)
                if frame == CharacterFrame then
                    if id == 1 then
                        ScheduleRefresh()
                    else
                        AGC.Overlay:Hide()
                    end
                end
            end)
        end
    end
end

function EventBus:ForceRefresh()
    ScheduleRefresh()
end
