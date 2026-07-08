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

-- Reposition a label based on current saved settings
local function PositionLabel(slotId, fs)
    local btnName = SLOT_BUTTONS[slotId]
    if not btnName then return end
    local btn = _G[btnName]
    if not btn then return end

    local db   = aGearCheckDB or {}
    local side = SLOT_SIDE[slotId] or "LEFT"

    fs:ClearAllPoints()

    if side == "LEFT" then
        local pad = db.leftPadding or 4
        fs:SetPoint("TOPLEFT", btn, "TOPRIGHT", pad + (db.leftOffsetX or 0), db.leftOffsetY or 0)
        fs:SetJustifyH("LEFT")
    elseif side == "RIGHT" then
        local pad = db.rightPadding or 4
        fs:SetPoint("TOPRIGHT", btn, "TOPLEFT", -pad + (db.rightOffsetX or 0), db.rightOffsetY or 0)
        fs:SetJustifyH("RIGHT")
    elseif side == "WEAPON_L" then
        local pad = db.mhPadding or 4
        fs:SetPoint("TOPRIGHT", btn, "TOPLEFT", -pad + (db.mhOffsetX or 0), db.mhOffsetY or 0)
        fs:SetJustifyH("RIGHT")
    elseif side == "WEAPON_R" then
        local pad = db.ohPadding or 4
        fs:SetPoint("TOPLEFT", btn, "TOPRIGHT", pad + (db.ohOffsetX or 0), db.ohOffsetY or 0)
        fs:SetJustifyH("LEFT")
    end
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- Toggle checkbox on the character frame (top-left corner)
local toggleCB

local function IsLabelsVisible()
    local db = aGearCheckDB or {}
    if db.labelsVisible == nil then return true end
    return db.labelsVisible
end

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
--- @param issues  table  slotId → list of { text, severity }
--- @param cfg     table  aGearCheckDB (or defaults)
function Overlay:Render(issues, cfg)
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

--- Hide all overlay labels.
function Overlay:Hide()
    for _, fs in pairs(labels) do
        fs:Hide()
        fs:SetText("")
    end
end
