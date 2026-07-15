local _, AGC = ...
AGC.StatsPane = {}

local StatsPane = AGC.StatsPane

local statInfo = {}
local initialized = false
local cachedScanResults
local cachedProfessions

local function ColorCount(have, total)
    if have >= total then
        return "|cff66ff66" .. have .. "/" .. total .. "|r"
    end
    return "|cffff3333" .. have .. "/" .. total .. "|r"
end

local function FindFirstFrame(names)
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame then
            return frame
        end
    end
    return nil
end

local function ComputeSummary()
    local scanResults = cachedScanResults or {}
    local professions = cachedProfessions or {}

    local EnchantData = AGC.EnchantData
    local EngineerData = AGC.EngineerData

    local enchTotal, enchHave = 0, 0
    for slotId in pairs(EnchantData.ENCHANTABLE_SLOTS) do
        if scanResults[slotId] then
            enchTotal = enchTotal + 1
            if scanResults[slotId].hasEnchant then
                enchHave = enchHave + 1
            end
        end
    end

    local ohItem = scanResults[EnchantData.OFFHAND_SLOT]
    if ohItem and AGC.Scanner:IsOffHandEnchantable(ohItem.itemLink) then
        enchTotal = enchTotal + 1
        if ohItem.hasEnchant then
            enchHave = enchHave + 1
        end
    end

    if professions[EnchantData.PROF_ENCHANTING] then
        for slotId in pairs(EnchantData.RING_SLOTS) do
            if scanResults[slotId] then
                enchTotal = enchTotal + 1
                if scanResults[slotId].hasEnchant then
                    enchHave = enchHave + 1
                end
            end
        end
    end

    local gemTotal, gemHave = 0, 0
    for _, item in pairs(scanResults) do
        local baseCount = AGC.Scanner:GetBaseSocketCount(item.parsed.itemId)
        if item.hasExtraSocket then
            baseCount = baseCount + 1
        end
        gemTotal = gemTotal + baseCount
        gemHave = gemHave + math.min(item.filledGems, baseCount)
    end

    local beltTotal, beltHave = 0, 0
    local beltSlot = EnchantData.BELT_SLOT
    local beltItem = beltSlot and scanResults[beltSlot]
    if beltItem then
        beltTotal = 1
        if beltItem.hasExtraSocket then
            beltHave = 1
        end
    end

    local tinkTotal, tinkHave = 0, 0
    if professions[EnchantData.PROF_ENGINEERING] then
        for slotId in pairs(EngineerData.TINKER_SLOTS) do
            if scanResults[slotId] then
                tinkTotal = tinkTotal + 1
                if scanResults[slotId].hasTinker then
                    tinkHave = tinkHave + 1
                end
            end
        end
    end

    return {
        enchanted = { label = "Enchanted", have = enchHave, total = enchTotal },
        gemmed = { label = "Gemmed", have = gemHave, total = gemTotal },
        belted = { label = "Belt Buckle", have = beltHave, total = beltTotal },
        tinkered = { label = "Tinkered", have = tinkHave, total = tinkTotal },
    }
end

local function BuildTooltip(title, summary, lines)
    return function(statFrame)
        if (MOVING_STAT_CATEGORY) then return end
        GameTooltip:SetOwner(statFrame, "ANCHOR_RIGHT")
        GameTooltip:SetText(HIGHLIGHT_FONT_COLOR_CODE .. format(PAPERDOLLFRAME_TOOLTIP_FORMAT, title) .. format(" %d/%d", summary.have, summary.total) .. FONT_COLOR_CODE_CLOSE)
        for _, line in ipairs(lines or {}) do
            GameTooltip:AddLine(line)
        end
        GameTooltip:Show()
    end
end

local function UpdateStat(statFrame, summary, tooltipTitle, tooltipLines)
    if summary.total <= 0 then
        statFrame:Hide()
        return
    end

    if statFrame.Label then
        statFrame.Label:SetText(format(STAT_FORMAT, summary.label))
    end
    statFrame.Value:SetText(ColorCount(summary.have, summary.total))
    statFrame.numericValue = summary.have
    statFrame:SetScript("OnEnter", BuildTooltip(tooltipTitle, summary, tooltipLines))
    statFrame:Show()
end

local function PaperDollFrame_SetGearCheckEnchant(statFrame, unit)
    if unit ~= "player" then
        statFrame:Hide()
        return
    end
    local summary = ComputeSummary().enchanted
    UpdateStat(statFrame, summary, "Enchanted", {
        "Counts equipped slots that should have an enchant.",
    })
end

local function PaperDollFrame_SetGearCheckGem(statFrame, unit)
    if unit ~= "player" then
        statFrame:Hide()
        return
    end
    local summary = ComputeSummary().gemmed
    UpdateStat(statFrame, summary, "Gemmed", {
        "Counts all available sockets and filled gems.",
    })
end

local function PaperDollFrame_SetGearCheckBelt(statFrame, unit)
    if unit ~= "player" then
        statFrame:Hide()
        return
    end
    local summary = ComputeSummary().belted
    UpdateStat(statFrame, summary, "Belt Buckle", {
        "Counts whether the belt has an extra socket from a buckle.",
    })
end

local function PaperDollFrame_SetGearCheckTinker(statFrame, unit)
    if unit ~= "player" then
        statFrame:Hide()
        return
    end
    local summary = ComputeSummary().tinkered
    UpdateStat(statFrame, summary, "Tinkered", {
        "Counts engineering tinker slots and active tinkers.",
    })
end

statInfo.GEARCHECK_ENCHANT = {
    updateFunc = function(statFrame, unit)
        PaperDollFrame_SetGearCheckEnchant(statFrame, unit)
    end,
}

statInfo.GEARCHECK_GEM = {
    updateFunc = function(statFrame, unit)
        PaperDollFrame_SetGearCheckGem(statFrame, unit)
    end,
}

statInfo.GEARCHECK_BELT = {
    updateFunc = function(statFrame, unit)
        PaperDollFrame_SetGearCheckBelt(statFrame, unit)
    end,
}

statInfo.GEARCHECK_TINKER = {
    updateFunc = function(statFrame, unit)
        PaperDollFrame_SetGearCheckTinker(statFrame, unit)
    end,
}

local function AddStat(categoryNameOrId, newStat)
    if not statInfo[newStat] then return end

    local categoryName = categoryNameOrId
    if type(categoryNameOrId) == "number" and PaperDoll_FindCategoryById then
        categoryName = PaperDoll_FindCategoryById(categoryNameOrId)
    end

    local category = categoryName and PAPERDOLL_STATCATEGORIES and PAPERDOLL_STATCATEGORIES[categoryName]
    if not category or not category.stats then return end

    if not tContains(category.stats, newStat) then
        table.insert(category.stats, newStat)
        if PaperDollFrame_UpdateStats then
            PaperDollFrame_UpdateStats()
        end
    end
end

local function InjectStats()
    if not PAPERDOLL_STATINFO then return end
    if not getmetatable(PAPERDOLL_STATINFO) then
        setmetatable(PAPERDOLL_STATINFO, { __index = statInfo })
    end

    AddStat("GENERAL", "GEARCHECK_ENCHANT")
    AddStat("GENERAL", "GEARCHECK_GEM")
    AddStat("GENERAL", "GEARCHECK_BELT")
    AddStat("GENERAL", "GEARCHECK_TINKER")
end

function StatsPane:Init()
    if initialized then return end
    initialized = true

    if hooksecurefunc then
        hooksecurefunc("PaperDoll_InitStatCategories", InjectStats)
    end

    InjectStats()
end

function StatsPane:SetData(scanResults, professions)
    cachedScanResults = scanResults
    cachedProfessions = professions

    if CharacterFrame and CharacterFrame:IsShown() and PaperDollFrame_UpdateStats then
        PaperDollFrame_UpdateStats()
    end
end
