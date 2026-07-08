local _, AGC = ...
AGC.DebugWindow = {}

local DebugWindow = AGC.DebugWindow
local frame

------------------------------------------------------------------------
-- Gather all debug info into a single string
------------------------------------------------------------------------
local function GatherDebugText()
    local lines = {}
    lines[#lines + 1] = "=== aGearCheck Debug Info ==="
    lines[#lines + 1] = "Date: " .. date("%Y-%m-%d %H:%M:%S")
    lines[#lines + 1] = ""

    -- Professions
    local p1, p2 = GetProfessions()
    local function profName(idx)
        if not idx then return "none" end
        local name = GetProfessionInfo(idx)
        return name or "?"
    end
    lines[#lines + 1] = "Professions: " .. profName(p1) .. ", " .. profName(p2)
    lines[#lines + 1] = ""

    -- Item link fields per slot
    lines[#lines + 1] = "--- Item Link Fields ---"
    for slotId = 1, 17 do
        local link = GetInventoryItemLink("player", slotId)
        if link then
            local parsed = AGC.Version:ParseItemLink(link)
            if parsed then
                local fieldStr = table.concat(parsed.allFields, ":")
                local name = GetItemInfo(link) or "?"
                lines[#lines + 1] = ("Slot %2d: %-30s  fields=[%s]"):format(slotId, name, fieldStr)
            end
        else
            lines[#lines + 1] = ("Slot %2d: (empty)"):format(slotId)
        end
    end
    lines[#lines + 1] = ""

    -- Tinker tooltip dump
    lines[#lines + 1] = "--- Tinker Tooltip Lines ---"
    local tinkerSlots = AGC.EngineerData and AGC.EngineerData.TINKER_SLOTS or {}
    local tipName = "AGCScanTooltip"
    for slotId in pairs(tinkerSlots) do
        local link = GetInventoryItemLink("player", slotId)
        if link then
            local name = GetItemInfo(link) or "?"
            lines[#lines + 1] = ("Slot %d (%s):"):format(slotId, name)
            local tip = CreateFrame("GameTooltip", tipName, nil, "GameTooltipTemplate")
            tip:SetOwner(WorldFrame, "ANCHOR_NONE")
            tip:ClearLines()
            tip:SetInventoryItem("player", slotId)
            for i = 1, tip:NumLines() do
                local left = _G[tipName .. "TextLeft" .. i]
                if left then
                    local text = left:GetText()
                    if text then
                        lines[#lines + 1] = "  L" .. i .. ": " .. text
                    end
                end
            end
        end
    end
    lines[#lines + 1] = ""

    -- Scan results
    lines[#lines + 1] = "--- Scan Results ---"
    local scanResults, professions = AGC.Scanner:ScanEquipment()
    local issues = AGC.Rules:Evaluate(scanResults, professions)
    for slotId = 1, 17 do
        local item = scanResults[slotId]
        if item then
            local parts = {}
            parts[#parts + 1] = "enchant=" .. tostring(item.enchantId)
            parts[#parts + 1] = "hasEnchant=" .. tostring(item.hasEnchant)
            parts[#parts + 1] = "hasTinker=" .. tostring(item.hasTinker)
            if item.tinkerName then
                parts[#parts + 1] = "tinker=" .. item.tinkerName
            end
            if item.enchantText then
                parts[#parts + 1] = "enchantText=" .. item.enchantText
            end
            parts[#parts + 1] = "extraSocket=" .. tostring(item.hasExtraSocket)
            parts[#parts + 1] = "gems=" .. tostring(item.filledGems)
            lines[#lines + 1] = ("Slot %2d: %s"):format(slotId, table.concat(parts, "  "))

            local slotIssues = issues[slotId]
            if slotIssues then
                for _, issue in ipairs(slotIssues) do
                    local c = issue.severity == "missing" and "!!" or "ok"
                    lines[#lines + 1] = ("         [%s] %s (%s)"):format(c, issue.text, issue.type)
                end
            end
        end
    end

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- Scrollable debug window (created on first use)
------------------------------------------------------------------------
function DebugWindow:Show()
    if not frame then
        frame = CreateFrame("Frame", "AGCDebugFrame", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(650, 450)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetFrameStrata("DIALOG")
        frame.TitleText:SetText("aGearCheck — Debug Info")

        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", frame.InsetBg or frame, "TOPLEFT", 8, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)
        frame.scrollFrame = scrollFrame

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetWidth(scrollFrame:GetWidth() - 10)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox

        local selectBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        selectBtn:SetSize(80, 22)
        selectBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
        selectBtn:SetText("Select All")
        selectBtn:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)

        local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        refreshBtn:SetSize(80, 22)
        refreshBtn:SetPoint("LEFT", selectBtn, "RIGHT", 8, 0)
        refreshBtn:SetText("Refresh")
        refreshBtn:SetScript("OnClick", function()
            DebugWindow:Refresh()
        end)
    end

    self:Refresh()
    frame:Show()
end

function DebugWindow:Refresh()
    if not frame then return end
    local text = GatherDebugText()
    frame.editBox:SetText(text)
    frame.editBox:SetCursorPosition(0)
end

function DebugWindow:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end
