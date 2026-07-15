local _, AGC = ...
AGC.Overlay = {}

local Overlay = AGC.Overlay

------------------------------------------------------------------------
-- Slot button names in the MoP Classic default character frame
------------------------------------------------------------------------
local SLOT_BUTTONS = {
    [1]  = "CharacterHeadSlot",
    [2]  = "CharacterNeckSlot",
    [3]  = "CharacterShoulderSlot",
    [5]  = "CharacterChestSlot",
    [6]  = "CharacterWaistSlot",
    [7]  = "CharacterLegsSlot",
    [8]  = "CharacterFeetSlot",
    [9]  = "CharacterWristSlot",
    [10] = "CharacterHandsSlot",
    [11] = "CharacterFinger0Slot",
    [12] = "CharacterFinger1Slot",
    [13] = "CharacterTrinket0Slot",
    [14] = "CharacterTrinket1Slot",
    [15] = "CharacterBackSlot",
    [16] = "CharacterMainHandSlot",
    [17] = "CharacterSecondaryHandSlot",
}

-- Which side of the character model each slot sits on.
-- LEFT  → label anchors to the right of the icon (toward the model)
-- RIGHT → label anchors to the left of the icon (toward the model)
-- BOTTOM → label anchors above the icon
local SLOT_SIDE = {
    [1]  = "LEFT",
    [2]  = "LEFT",
    [3]  = "LEFT",
    [5]  = "LEFT",
    [9]  = "LEFT",
    [15] = "LEFT",
    [6]  = "RIGHT",
    [7]  = "RIGHT",
    [8]  = "RIGHT",
    [10] = "RIGHT",
    [11] = "RIGHT",
    [12] = "RIGHT",
    [13] = "RIGHT",
    [14] = "RIGHT",
    [16] = "WEAPON_L",
    [17] = "WEAPON_R",
}

------------------------------------------------------------------------
-- Label pool — one FontString per slot, created on first use
------------------------------------------------------------------------
local labels = {}
local overlayFrames = {}

-- Map slot side to its strata DB key
local STRATA_KEYS = {
    LEFT     = "leftStrata",
    RIGHT    = "rightStrata",
    WEAPON_L = "mhStrata",
    WEAPON_R = "ohStrata",
}

local function GetOrCreateLabel(slotId)
    local db      = aGearCheckDB or {}
    local btnName = SLOT_BUTTONS[slotId]
    if not btnName then return nil end
    local btn = _G[btnName]
    if not btn then return nil end

    local side      = SLOT_SIDE[slotId] or "LEFT"
    local strataKey = STRATA_KEYS[side] or "leftStrata"
    local strata    = db[strataKey] or "HIGH"

    if not labels[slotId] then
        -- Parent to UIParent so the overlay is completely independent of
        -- CharacterFrame's frame hierarchy.  This guarantees the label
        -- renders above all slot buttons and other addon overlays.
        local overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetPoint("CENTER", btn, "CENTER")
        overlay:SetSize(1, 1)
        overlay:SetFrameStrata(strata)
        overlay:SetFrameLevel(9999)
        overlayFrames[slotId] = overlay

        local fs = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetWidth(110)
        fs:SetWordWrap(true)
        fs:Hide()
        labels[slotId] = fs
    else
        local overlay = overlayFrames[slotId]
        if overlay then
            overlay:SetFrameStrata(strata)
            overlay:SetFrameLevel(9999)
        end
    end

    return labels[slotId]
end

--- Destroy all overlay frames so they are recreated with fresh strata.
function Overlay:ResetOverlayFrames()
    for _, fs in pairs(labels) do
        fs:Hide()
        fs:SetText("")
    end
    for _, frame in pairs(overlayFrames) do
        frame:Hide()
        frame:SetParent(nil)
    end
    wipe(labels)
    wipe(overlayFrames)
end

-- Anchor direction: which edge of the BUTTON the label attaches to.
-- Offset sign is adjusted so positive padding always moves AWAY from the button.
local ANCHOR_SIGN = {
    TOPLEFT     = { px =  1, labelPt = "TOPLEFT",     btnPt = "TOPRIGHT"    },
    TOPRIGHT    = { px = -1, labelPt = "TOPRIGHT",    btnPt = "TOPLEFT"     },
    BOTTOMLEFT  = { px =  1, labelPt = "BOTTOMLEFT",  btnPt = "BOTTOMRIGHT" },
    BOTTOMRIGHT = { px = -1, labelPt = "BOTTOMRIGHT", btnPt = "BOTTOMLEFT"  },
    TOP         = { px =  0, labelPt = "BOTTOM",      btnPt = "TOP"         },
    BOTTOM      = { px =  0, labelPt = "TOP",          btnPt = "BOTTOM"      },
    LEFT        = { px = -1, labelPt = "RIGHT",        btnPt = "LEFT"        },
    RIGHT       = { px =  1, labelPt = "LEFT",         btnPt = "RIGHT"       },
}

-- Reposition a label based on current saved settings
local function PositionLabel(slotId, fs)
    local btnName = SLOT_BUTTONS[slotId]
    if not btnName then return end
    local btn = _G[btnName]
    if not btn then return end

    local db   = aGearCheckDB or {}
    local side = SLOT_SIDE[slotId] or "LEFT"

    fs:ClearAllPoints()

    local anchorKey, alignKey, padKey, oxKey, oyKey
    if side == "LEFT" then
        anchorKey, alignKey, padKey, oxKey, oyKey = "leftAnchor", "leftAlign", "leftPadding", "leftOffsetX", "leftOffsetY"
    elseif side == "RIGHT" then
        anchorKey, alignKey, padKey, oxKey, oyKey = "rightAnchor", "rightAlign", "rightPadding", "rightOffsetX", "rightOffsetY"
    elseif side == "WEAPON_L" then
        anchorKey, alignKey, padKey, oxKey, oyKey = "mhAnchor", "mhAlign", "mhPadding", "mhOffsetX", "mhOffsetY"
    elseif side == "WEAPON_R" then
        anchorKey, alignKey, padKey, oxKey, oyKey = "ohAnchor", "ohAlign", "ohPadding", "ohOffsetX", "ohOffsetY"
    end

    local anchorDir = db[anchorKey] or "TOPRIGHT"
    local align     = db[alignKey] or "LEFT"
    local pad       = db[padKey] or 4
    local offX      = db[oxKey] or 0
    local offY      = db[oyKey] or 0

    local info = ANCHOR_SIGN[anchorDir]
    if not info then info = ANCHOR_SIGN["TOPRIGHT"] end

    local finalX = (info.px * pad) + offX
    local finalY = offY

    fs:SetPoint(info.labelPt, btn, info.btnPt, finalX, finalY)
    fs:SetJustifyH(align)
end

------------------------------------------------------------------------
-- Visibility helper (must be declared before summary and toggle code)
------------------------------------------------------------------------
local function IsLabelsVisible()
    local db = aGearCheckDB or {}
    if db.labelsVisible == nil then return true end
    return db.labelsVisible
end

------------------------------------------------------------------------
-- Enhancement summary (Enchanted X/Y, Gemmed X/Y, Tinkered X/Y)
------------------------------------------------------------------------
local summaryFrame, summaryRows
local summaryStatGroup
local summaryBaseGroupHeight

local function FindFirstFrame(names)
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame then
            return frame
        end
    end
    return nil
end

local function GetOrCreateSummary()
    if summaryFrame then return summaryRows end
    if not CharacterFrame then return nil end

    summaryStatGroup = FindFirstFrame({
        "CharacterStatsPaneCategory1",
        "CharacterStatsPane",
        "CharacterFrame",
    })

    summaryFrame = CreateFrame("Frame", nil, summaryStatGroup or CharacterFrame)
    summaryFrame:SetSize(169, 54)
    summaryFrame:SetFrameStrata("HIGH")
    summaryFrame:SetFrameLevel(100)

    -- Anchor below the right-side stat panel (General/Attributes/Melee area).
    local anchor = FindFirstFrame({
        "CharacterStatsPaneCategory1Stat4",
        "CharacterStatsPaneCategory1",
        "PlayerStatFrameRight4",        -- Movement Speed row
        "PlayerStatFrameRightDropDown", -- stat category dropdown
        "CharacterAttributesFrame",
    })
    if anchor then
        summaryFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    else
        -- Fallback: below the General section header area on the right
        summaryFrame:SetPoint("TOPLEFT", summaryStatGroup or CharacterFrame, "BOTTOMLEFT", 0, -2)
    end

    summaryRows = {}
    for i = 1, 3 do
        local row = CreateFrame("Frame", nil, summaryFrame)
        row:SetSize(169, 14)
        if i == 1 then
            row:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", summaryRows[i - 1].row, "BOTTOMLEFT", 0, -2)
        end

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetJustifyH("LEFT")

        local value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        value:SetJustifyH("RIGHT")

        summaryRows[i] = { row = row, label = label, value = value }
    end

    return summaryRows
end

local function ResizeSummaryGroup(lineCount)
    if not summaryStatGroup then return end

    if not summaryBaseGroupHeight then
        summaryBaseGroupHeight = summaryStatGroup:GetHeight()
    end

    if lineCount > 0 then
        local summaryHeight = (lineCount * 14) + math.max(0, lineCount - 1) * 2
        summaryStatGroup:SetHeight(summaryBaseGroupHeight + summaryHeight + 2)
    else
        summaryStatGroup:SetHeight(summaryBaseGroupHeight)
    end
end

local function UpdateSummary(scanResults, professions)
    local rows = GetOrCreateSummary()
    if not rows then return end
    if not IsLabelsVisible() then
        ResizeSummaryGroup(0)
        summaryFrame:Hide()
        return
    end

    local EnchantData  = AGC.EnchantData
    local EngineerData = AGC.EngineerData

    -- Count enchants
    local enchTotal, enchHave = 0, 0
    for slotId in pairs(EnchantData.ENCHANTABLE_SLOTS) do
        if scanResults[slotId] then
            enchTotal = enchTotal + 1
            if scanResults[slotId].hasEnchant then enchHave = enchHave + 1 end
        end
    end
    -- Off-hand (if enchantable)
    local ohItem = scanResults[EnchantData.OFFHAND_SLOT]
    if ohItem and AGC.Scanner:IsOffHandEnchantable(ohItem.itemLink) then
        enchTotal = enchTotal + 1
        if ohItem.hasEnchant then enchHave = enchHave + 1 end
    end
    -- Ring enchants (enchanting profession)
    if professions and professions[EnchantData.PROF_ENCHANTING] then
        for slotId in pairs(EnchantData.RING_SLOTS) do
            if scanResults[slotId] then
                enchTotal = enchTotal + 1
                if scanResults[slotId].hasEnchant then enchHave = enchHave + 1 end
            end
        end
    end

    -- Count gems (filled vs total sockets across all equipped items)
    local gemTotal, gemHave = 0, 0
    for slotId, item in pairs(scanResults) do
        local baseCount = AGC.Scanner:GetBaseSocketCount(item.parsed.itemId)
        if item.hasExtraSocket then baseCount = baseCount + 1 end
        gemTotal = gemTotal + baseCount
        gemHave  = gemHave + math.min(item.filledGems, baseCount)
    end

    -- Count tinkers (engineering only)
    local tinkTotal, tinkHave = 0, 0
    if professions and professions[EnchantData.PROF_ENGINEERING] then
        for slotId in pairs(EngineerData.TINKER_SLOTS) do
            if scanResults[slotId] then
                tinkTotal = tinkTotal + 1
                if scanResults[slotId].hasTinker then tinkHave = tinkHave + 1 end
            end
        end
    end

    -- Build display lines
    local function ColorCount(have, total)
        if have >= total then
            return "|cff66ff66" .. have .. "/" .. total .. "|r"
        else
            return "|cffff3333" .. have .. "/" .. total .. "|r"
        end
    end

    local lineIndex = 0
    local function AddLine(labelText, valueText)
        lineIndex = lineIndex + 1
        local row = rows[lineIndex]
        if row then
            row.label:SetText(labelText)
            row.value:SetText(valueText)
            row.row:Show()
        end
    end

    if enchTotal > 0 then
        AddLine("Enchanted", ColorCount(enchHave, enchTotal))
    end
    if gemTotal > 0 then
        AddLine("Gemmed", ColorCount(gemHave, gemTotal))
    end
    if tinkTotal > 0 then
        AddLine("Tinkered", ColorCount(tinkHave, tinkTotal))
    end

    for i = lineIndex + 1, #rows do
        rows[i].row:Hide()
        rows[i].label:SetText("")
        rows[i].value:SetText("")
    end

    if lineIndex > 0 then
        summaryFrame:SetHeight((lineIndex * 14) + math.max(0, lineIndex - 1) * 2)
        ResizeSummaryGroup(lineIndex)
        summaryFrame:Show()
    else
        ResizeSummaryGroup(0)
        summaryFrame:Hide()
    end
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- Toggle checkbox on the character frame (top-left corner)
local toggleCB

local function GetOrCreateToggle()
    if toggleCB then return toggleCB end
    if not CharacterFrame then return nil end

    toggleCB = CreateFrame("CheckButton", nil, CharacterFrame)
    toggleCB:SetSize(22, 22)
    toggleCB:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 8, -8)
    toggleCB:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    toggleCB:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    toggleCB:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    toggleCB:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    toggleCB:SetChecked(IsLabelsVisible())
    toggleCB:SetFrameStrata("HIGH")
    toggleCB:SetFrameLevel(100)

    toggleCB.label = toggleCB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toggleCB.label:SetPoint("LEFT", toggleCB, "RIGHT", 2, 0)
    toggleCB.label:SetText("GearCheck")

    -- Settings cogwheel button
    local cogBtn = CreateFrame("Button", nil, CharacterFrame)
    cogBtn:SetSize(16, 16)
    cogBtn:SetPoint("LEFT", toggleCB.label, "RIGHT", 4, 0)
    cogBtn:SetFrameStrata("HIGH")
    cogBtn:SetFrameLevel(100)
    cogBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    cogBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    cogBtn:SetScript("OnClick", function() AGC.Options:Toggle() end)
    cogBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("aGearCheck Options", 1, 1, 1)
        GameTooltip:Show()
    end)
    cogBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    toggleCB:SetScript("OnClick", function(self)
        aGearCheckDB.labelsVisible = self:GetChecked()
        if aGearCheckDB.labelsVisible then
            AGC:OnRefresh()
        else
            AGC.Overlay:Hide()
        end
    end)

    return toggleCB
end

--- Sync the character frame toggle checkbox to match the current DB value.
function Overlay:SyncToggle()
    if toggleCB then
        toggleCB:SetChecked(IsLabelsVisible())
        if IsLabelsVisible() then
            AGC:OnRefresh()
        else
            Overlay:Hide()
        end
    end
end

--- Update the toggle checkbox color based on whether any issues are missing.
function Overlay:UpdateToggle(hasMissing)
    local cb = GetOrCreateToggle()
    if not cb then return end
    if hasMissing then
        cb.label:SetTextColor(1, 0.2, 0.2)
    else
        cb.label:SetTextColor(0.6, 1, 0.6)
    end
end

--- Render issues on the character frame.
--- @param issues      table  slotId → list of { text, severity }
--- @param cfg         table  aGearCheckDB (or defaults)
--- @param scanResults table  slotId → scan data (optional, for summary)
--- @param professions table  profession flags (optional, for summary)
function Overlay:Render(issues, cfg, scanResults, professions)
    cfg = cfg or {}
    local missingColor = cfg.missingColor or { 1, 0.2, 0.2 }
    local presentColor = cfg.presentColor or { 0.6, 1, 0.6 }
    local showPresent  = cfg.showPresent
    local fontSize     = cfg.fontSize or 12

    -- Determine overall status for the toggle checkbox
    local hasMissing = false
    for _, slotIssues in pairs(issues) do
        for _, issue in ipairs(slotIssues) do
            if issue.severity == "missing" then
                hasMissing = true
                break
            end
        end
        if hasMissing then break end
    end
    self:UpdateToggle(hasMissing)

    -- If the user unchecked the toggle, keep labels hidden
    if not IsLabelsVisible() then return end

    -- Reset all labels first
    self:Hide()

    for slotId, slotIssues in pairs(issues) do
        local parts = {}
        local worstSeverity = "present"

        for _, issue in ipairs(slotIssues) do
            if issue.severity == "missing" then
                parts[#parts + 1] = issue.text
                worstSeverity = "missing"
            elseif showPresent and issue.severity == "present" then
                parts[#parts + 1] = issue.text
            end
        end

        if #parts > 0 then
            local btnFrame = _G[SLOT_BUTTONS[slotId]]
            if btnFrame and btnFrame:IsVisible() then
                local label = GetOrCreateLabel(slotId)
                if label then
                    PositionLabel(slotId, label)

                    local font, _, flags = label:GetFont()
                    if font then
                        label:SetFont(font, fontSize, flags)
                    end

                    if worstSeverity == "missing" then
                        label:SetTextColor(unpack(missingColor))
                    else
                        label:SetTextColor(unpack(presentColor))
                    end

                    label:SetText(table.concat(parts, "\n"))
                    label:Show()
                end
            end
        end
    end

end
function Overlay:Hide()
    for _, fs in pairs(labels) do
        fs:Hide()
        fs:SetText("")
    end
    if summaryFrame then summaryFrame:Hide() end
end
