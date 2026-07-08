local addonName, AGC = ...

------------------------------------------------------------------------
-- Saved-variable defaults
------------------------------------------------------------------------
local DEFAULTS = {
    showPresent    = true,
    fontSize       = 12,
    missingColor   = { 1, 0.2, 0.2 },
    presentColor   = { 0.6, 1, 0.6 },
    leftOffsetX    = 0,
    leftOffsetY    = 0,
    leftPadding    = 15,
    leftStrata     = "HIGH",
    rightOffsetX   = 0,
    rightOffsetY   = 0,
    rightPadding   = 15,
    rightStrata    = "HIGH",
    mhOffsetX      = 0,
    mhOffsetY      = 0,
    mhPadding      = 6,
    mhStrata       = "HIGH",
    ohOffsetX      = 0,
    ohOffsetY      = 0,
    ohPadding      = 6,
    ohStrata       = "HIGH",
    labelsVisible  = true,
}

-- Expose defaults so Options panel can use them for Reset
AGC.DEFAULTS = DEFAULTS

local function InitDB()
    if not aGearCheckDB then
        aGearCheckDB = {}
    end
    for k, v in pairs(DEFAULTS) do
        if aGearCheckDB[k] == nil then
            aGearCheckDB[k] = v
        end
    end
end

------------------------------------------------------------------------
-- Core refresh (called by EventBus on every debounced trigger)
------------------------------------------------------------------------
function AGC:OnRefresh()
    if not CharacterFrame or not CharacterFrame:IsShown() then return end

    local scanResults, professions = self.Scanner:ScanEquipment()
    local issues = self.Rules:Evaluate(scanResults, professions)
    self.Overlay:Render(issues, aGearCheckDB)
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function HandleSlash(msg)
    local cmd = (msg or ""):lower():trim()

    if cmd == "missing" or cmd == "present" then
        aGearCheckDB.showPresent = not aGearCheckDB.showPresent
        local state = aGearCheckDB.showPresent and "shown" or "hidden"
        print("|cff00ccff[aGearCheck]|r Present enhancements now " .. state)
        AGC:OnRefresh()

    elseif cmd == "test" then
        local scanResults, professions = AGC.Scanner:ScanEquipment()
        local issues = AGC.Rules:Evaluate(scanResults, professions)
        print("|cff00ccff[aGearCheck]|r --- Test scan ---")
        local found = false
        for slotId, slotIssues in pairs(issues) do
            for _, issue in ipairs(slotIssues) do
                local c = issue.severity == "missing" and "|cffff3333" or "|cff66ff66"
                print(("  Slot %d: %s%s|r (%s)"):format(slotId, c, issue.text, issue.type))
                found = true
            end
        end
        if not found then
            print("  No issues found.")
        end

    elseif cmd == "debug" then
        print("|cff00ccff[aGearCheck]|r --- Debug dump ---")
        for slotId = 1, 17 do
            local link = GetInventoryItemLink("player", slotId)
            if link then
                local parsed = AGC.Version:ParseItemLink(link)
                if parsed then
                    local fieldStr = table.concat(parsed.allFields, ":")
                    print(("  Slot %d: %s"):format(slotId, fieldStr))
                end
            end
        end

    elseif cmd == "tinker" then
        AGC.DebugWindow:Show()

    else
        print("|cff00ccff[aGearCheck]|r Commands:")
        print("  /agc missing  - toggle show/hide present enhancements")
        print("  /agc present  - toggle show/hide present enhancements")
        print("  /agc test     - print current issues to chat")
        print("  /agc debug    - dump item link fields to chat")
        print("  /agc tinker   - open debug info window")
    end
end

SLASH_AGEARCHECK1 = "/agc"
SLASH_AGEARCHECK2 = "/agearcheck"
SlashCmdList["AGEARCHECK"] = HandleSlash

------------------------------------------------------------------------
-- Bootstrap
------------------------------------------------------------------------
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:SetScript("OnEvent", function()
    InitDB()
    AGC.EventBus:Init()
    print("|cff00ccff[aGearCheck]|r v0.1.0 loaded. Use /agc for help.")
end)
