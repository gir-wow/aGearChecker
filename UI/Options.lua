local _, AGC = ...

------------------------------------------------------------------------
-- Widget helpers (template-free so they work on every Classic client)
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

local STRATA_LIST = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "TOOLTIP" }

local dropdownIndex = 0
local function MakeStrataDropdown(parent, x, y, text, dbKey)
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
        AGC.Overlay:ResetOverlayFrames()
        AGC:OnRefresh()
    end

    UIDropDownMenu_SetWidth(dd, 100)
    UIDropDownMenu_Initialize(dd, function()
        local db = aGearCheckDB or {}
        for _, strata in ipairs(STRATA_LIST) do
            local info = UIDropDownMenu_CreateInfo()
            info.text  = strata
            info.value = strata
            info.func  = OnClick
            info.checked = ((db[dbKey] or "HIGH") == strata)
            UIDropDownMenu_AddButton(info)
        end
    end)

    dd:SetScript("OnShow", function()
        local db = aGearCheckDB or {}
        UIDropDownMenu_SetText(dd, db[dbKey] or "HIGH")
    end)

    return dd
end

------------------------------------------------------------------------
-- Build options panel (scrollable)
------------------------------------------------------------------------

local panel = CreateFrame("Frame")
panel.name = "aGearCheck"

local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 4, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)

local content = CreateFrame("Frame")
content:SetSize(400, 880)
scrollFrame:SetScrollChild(content)

panel:SetScript("OnShow", function()
    for _, child in ipairs({ content:GetChildren() }) do
        if child.GetScript and child:GetScript("OnShow") then
            child:GetScript("OnShow")(child)
        end
    end
end)

MakeHeader(content, 16, -16, "aGearCheck Settings")

-- Display toggles
MakeCheckbox(content, 18, -50, "Show enchant effects on enchanted gear", "showPresent")

-- Font size
MakeSlider(content, 20, -110, "Font Size", "fontSize", 8, 20, 1)

-- Left side gear
local yOff = -160
MakeSection(content, 16, yOff, "Left Side Gear")
MakeStrataDropdown(content, 20, yOff - 25, "Strata:", "leftStrata")
MakeSlider(content, 20,  yOff - 65, "Padding", "leftPadding", 0, 30, 1)
MakeSlider(content, 200, yOff - 65, "X Offset", "leftOffsetX",  -30, 30, 1)
MakeSlider(content, 20,  yOff - 110, "Y Offset", "leftOffsetY",  -30, 30, 1)

-- Right side gear
yOff = -310
MakeSection(content, 16, yOff, "Right Side Gear")
MakeStrataDropdown(content, 20, yOff - 25, "Strata:", "rightStrata")
MakeSlider(content, 20,  yOff - 65, "Padding", "rightPadding", 0, 30, 1)
MakeSlider(content, 200, yOff - 65, "X Offset", "rightOffsetX", -30, 30, 1)
MakeSlider(content, 20,  yOff - 110, "Y Offset", "rightOffsetY", -30, 30, 1)

-- Main hand
yOff = -460
MakeSection(content, 16, yOff, "Main Hand (Left Weapon)")
MakeStrataDropdown(content, 20, yOff - 25, "Strata:", "mhStrata")
MakeSlider(content, 20,  yOff - 65, "Padding", "mhPadding", 0, 30, 1)
MakeSlider(content, 200, yOff - 65, "X Offset", "mhOffsetX", -30, 30, 1)
MakeSlider(content, 20,  yOff - 110, "Y Offset", "mhOffsetY", -30, 30, 1)

-- Off hand
yOff = -610
MakeSection(content, 16, yOff, "Off Hand (Right Weapon)")
MakeStrataDropdown(content, 20, yOff - 25, "Strata:", "ohStrata")
MakeSlider(content, 20,  yOff - 65, "Padding", "ohPadding", 0, 30, 1)
MakeSlider(content, 200, yOff - 65, "X Offset", "ohOffsetX", -30, 30, 1)
MakeSlider(content, 20,  yOff - 110, "Y Offset", "ohOffsetY", -30, 30, 1)

-- Reset to Default button
yOff = -760
local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOff)
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
    if panel:GetScript("OnShow") then
        panel:GetScript("OnShow")(panel)
    end
    print("|cff00ccff[aGearCheck]|r Settings reset to defaults.")
end)

-- Debug Info button
yOff = yOff - 40
local debugBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
debugBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOff)
debugBtn:SetSize(160, 26)
debugBtn:SetText("Show Debug Info")
debugBtn:SetScript("OnClick", function()
    AGC.DebugWindow:Show()
end)

------------------------------------------------------------------------
-- Register with the game options UI
------------------------------------------------------------------------
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end
