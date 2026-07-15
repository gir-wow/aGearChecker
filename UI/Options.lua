local _, AGC = ...
AGC.Options = {}

------------------------------------------------------------------------
-- Widget helpers
------------------------------------------------------------------------

local function MakeHeader(parent, x, y, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function MakeSection(parent, x, y, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText("|cffffd100" .. text .. "|r")
    return fs
end

local function MakeCheckbox(parent, x, y, text, dbKey)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetSize(26, 26)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(text)

    cb:SetScript("OnShow", function(self)
        self:SetChecked(aGearCheckDB[dbKey])
    end)
    cb:SetScript("OnClick", function(self)
        aGearCheckDB[dbKey] = self:GetChecked()
        AGC:OnRefresh()
    end)
    return cb
end

local sliderIndex = 0
local function MakeSlider(parent, x, y, text, dbKey, lo, hi, step)
    sliderIndex = sliderIndex + 1
    local name = "AGCSlider" .. sliderIndex

    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(lo, hi)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(160)

    _G[name .. "Text"]:SetText(text)
    _G[name .. "Low"]:SetText(lo)
    _G[name .. "High"]:SetText(hi)

    local val = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOP", slider, "BOTTOM", 0, 0)

    slider:SetScript("OnShow", function(self)
        local v = aGearCheckDB[dbKey]
        self:SetValue(v)
        val:SetText(v)
    end)
    slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        aGearCheckDB[dbKey] = v
        val:SetText(v)
        AGC:OnRefresh()
    end)
    return slider
end

local STRATA_LIST  = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "TOOLTIP" }
local ANCHOR_LIST  = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM", "LEFT", "RIGHT" }
local ALIGN_LIST   = { "LEFT", "CENTER", "RIGHT" }

local dropdownIndex = 0
local function MakeDropdown(parent, x, y, text, dbKey, choices, defaultVal, onChange)
    dropdownIndex = dropdownIndex + 1
    local name = "AGCDrop" .. dropdownIndex

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)

    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", label, "RIGHT", -8, -2)

    local function OnClick(self)
        aGearCheckDB[dbKey] = self.value
        UIDropDownMenu_SetText(dd, self.value)
        if onChange then onChange() end
        AGC.Overlay:ResetOverlayFrames()
        AGC:OnRefresh()
    end

    UIDropDownMenu_SetWidth(dd, 100)
    UIDropDownMenu_Initialize(dd, function()
        local db = aGearCheckDB or {}
        for _, val in ipairs(choices) do
            local info = UIDropDownMenu_CreateInfo()
            info.text  = val
            info.value = val
            info.func  = OnClick
            info.checked = ((db[dbKey] or defaultVal) == val)
            UIDropDownMenu_AddButton(info)
        end
    end)

    dd:SetScript("OnShow", function()
        local db = aGearCheckDB or {}
        UIDropDownMenu_SetText(dd, db[dbKey] or defaultVal)
    end)

    return dd
end

------------------------------------------------------------------------
-- Build a section for one side group (strata, anchor, align, sliders)
------------------------------------------------------------------------
local function MakeSideSection(parent, y, title, prefix)
    MakeSection(parent, 16, y, title)
    MakeDropdown(parent, 20,  y - 25,  "Strata:", prefix .. "Strata", STRATA_LIST, "HIGH")
    MakeDropdown(parent, 220, y - 25,  "Anchor:", prefix .. "Anchor", ANCHOR_LIST, "TOPRIGHT")
    MakeDropdown(parent, 20,  y - 55,  "Align:",  prefix .. "Align",  ALIGN_LIST,  "LEFT")
    MakeSlider(parent,   20,  y - 105, "Padding", prefix .. "Padding", 0, 30, 1)
    MakeSlider(parent,   200, y - 105, "X Offset", prefix .. "OffsetX", -30, 30, 1)
    MakeSlider(parent,   20,  y - 150, "Y Offset", prefix .. "OffsetY", -30, 30, 1)
end

------------------------------------------------------------------------
-- Standalone floating options window
------------------------------------------------------------------------
local frame

local function CreateOptionsFrame()
    if frame then return end

    frame = CreateFrame("Frame", "AGCOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(460, 780)
    frame:SetPoint("LEFT", UIParent, "CENTER", 200, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame.TitleText:SetText("aGearCheck \226\128\148 Options")
    tinsert(UISpecialFrames, "AGCOptionsFrame")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame.InsetBg or frame, "TOPLEFT", 4, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 8)

    local content = CreateFrame("Frame")
    content:SetSize(400, 940)
    scrollFrame:SetScrollChild(content)

    -- Refresh all child widgets on show
    frame:SetScript("OnShow", function()
        for _, child in ipairs({ content:GetChildren() }) do
            if child.GetScript and child:GetScript("OnShow") then
                child:GetScript("OnShow")(child)
            end
        end
    end)

    MakeHeader(content, 16, -16, "aGearCheck Settings")

    -- Display toggles
    local labelsCB = MakeCheckbox(content, 18, -50, "Show overlay", "labelsVisible")
    -- Sync character frame toggle when this changes
    local origLabelsClick = labelsCB:GetScript("OnClick")
    labelsCB:SetScript("OnClick", function(self)
        origLabelsClick(self)
        AGC.Overlay:SyncToggle()
    end)

    -- Font size
    MakeSlider(content, 20, -110, "Font Size", "fontSize", 8, 20, 1)

    -- Side sections
    MakeSideSection(content, -160, "Left Side Gear",               "left")
    MakeSideSection(content, -340, "Right Side Gear",              "right")
    MakeSideSection(content, -520, "Main Hand (Left Weapon)",      "mh")
    MakeSideSection(content, -700, "Off Hand (Right Weapon)",      "oh")

    -- Reset to Defaults
    local yBtn = -880
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yBtn)
    resetBtn:SetSize(160, 26)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        local defaults = AGC.DEFAULTS
        if not defaults then return end
        wipe(aGearCheckDB)
        for k, v in pairs(defaults) do
            if type(v) == "table" then
                aGearCheckDB[k] = { unpack(v) }
            else
                aGearCheckDB[k] = v
            end
        end
        AGC.Overlay:ResetOverlayFrames()
        AGC:OnRefresh()
        if frame:GetScript("OnShow") then
            frame:GetScript("OnShow")(frame)
        end
        print("|cff00ccff[aGearCheck]|r Settings reset to defaults.")
    end)

    -- Debug Info
    local debugBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    debugBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yBtn - 34)
    debugBtn:SetSize(160, 26)
    debugBtn:SetText("Show Debug Info")
    debugBtn:SetScript("OnClick", function()
        AGC.DebugWindow:Show()
    end)

    frame:Hide()
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
function AGC.Options:Toggle()
    CreateOptionsFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

function AGC.Options:Show()
    CreateOptionsFrame()
    frame:Show()
end

function AGC.Options:Hide()
    if frame then frame:Hide() end
end
