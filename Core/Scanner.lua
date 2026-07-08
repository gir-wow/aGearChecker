local _, AGC = ...
AGC.Scanner = {}

local Scanner = AGC.Scanner
local Version = AGC.Version

------------------------------------------------------------------------
-- Stat name abbreviations for compact display
------------------------------------------------------------------------
local STAT_SHORT = {
    { "Critical Strike",       "Crit" },
    { "Minor Speed Increase",  "Speed" },
    { "Minor Speed",           "Speed" },
    { "Intellect",             "Int" },
    { "Strength",              "Str" },
    { "Agility",               "Agi" },
    { "Stamina",               "Sta" },
    { "Spirit",                "Spi" },
    { "Expertise",             "Exp" },
    { " and ",                 " & " },
}

local function ShortenText(text)
    if not text then return text end
    for _, pair in ipairs(STAT_SHORT) do
        text = text:gsub(pair[1], pair[2])
    end
    return text
end

------------------------------------------------------------------------
-- Hidden tooltip used exclusively for socket scanning
------------------------------------------------------------------------
local SCAN_TIP_NAME = "AGCScanTooltip"
local scanTip

local function GetScanTooltip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", SCAN_TIP_NAME, nil, "GameTooltipTemplate")
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTip
end

-- Tooltip text patterns that represent an empty socket
local SOCKET_PATTERNS = {
    "Red Socket",
    "Blue Socket",
    "Yellow Socket",
    "Prismatic Socket",
    "Meta Socket",
    "Cogwheel Socket",
    "Sha%-Touched",
}

------------------------------------------------------------------------
-- Socket helpers
------------------------------------------------------------------------

--- Count empty sockets visible in the tooltip for an equipped slot.
function Scanner:CountEmptySockets(slotId)
    local tip = GetScanTooltip()
    tip:ClearLines()
    tip:SetInventoryItem("player", slotId)

    local count = 0
    for i = 1, tip:NumLines() do
        local region = _G[SCAN_TIP_NAME .. "TextLeft" .. i]
        if region then
            local text = region:GetText()
            if text then
                for _, pat in ipairs(SOCKET_PATTERNS) do
                    if text:find(pat) then
                        count = count + 1
                        break
                    end
                end
            end
        end
    end
    return count
end

--- Count filled gem IDs in the parsed item link.
function Scanner:CountFilledGems(parsed)
    if not parsed then return 0 end
    local n = 0
    if (parsed.gem1 or 0) > 0 then n = n + 1 end
    if (parsed.gem2 or 0) > 0 then n = n + 1 end
    if (parsed.gem3 or 0) > 0 then n = n + 1 end
    if (parsed.gem4 or 0) > 0 then n = n + 1 end
    return n
end

--- Get the base (unmodified) socket count for an item template.
function Scanner:GetBaseSocketCount(itemId)
    if not itemId or itemId == 0 then return 0 end

    -- Construct a "clean" item link with only the base item ID
    local baseLink = "item:" .. itemId .. ":0:0:0:0:0:0:0:0:0"
    local stats = GetItemStats(baseLink)
    if not stats then return 0 end

    local count = 0
    count = count + (stats["EMPTY_SOCKET_RED"]       or 0)
    count = count + (stats["EMPTY_SOCKET_BLUE"]      or 0)
    count = count + (stats["EMPTY_SOCKET_YELLOW"]    or 0)
    count = count + (stats["EMPTY_SOCKET_PRISMATIC"] or 0)
    count = count + (stats["EMPTY_SOCKET_META"]      or 0)
    count = count + (stats["EMPTY_SOCKET_COGWHEEL"]  or 0)
    return count
end

--- Determine whether an extra socket (belt buckle / BS) has been applied.
--- Compares total visible sockets (filled gems + empty slots) against the
--- item template's base socket count.
function Scanner:HasExtraSocket(slotId, parsed)
    local empty  = self:CountEmptySockets(slotId)
    local filled = self:CountFilledGems(parsed)
    local total  = empty + filled
    local base   = self:GetBaseSocketCount(parsed.itemId)
    return total > base
end

--- Extract the enchant effect text by comparing the equipped item tooltip
--- with a clean (unenchanted) version.  There is no direct WoW API to map
--- an enchant ID to a display name, so tooltip diffing is the standard
--- lightweight approach used across the addon ecosystem.
function Scanner:GetEnchantText(slotId, parsed)
    if not parsed or (parsed.enchantId or 0) == 0 then return nil end

    local itemLink = GetInventoryItemLink("player", slotId)
    if not itemLink then return nil end

    -- Extract the item string and build a clean version with enchant zeroed
    local itemString = itemLink:match("item:[%-?%d:]+")
    if not itemString then return nil end
    local cleanString = itemString:gsub("^(item:%d+:)%d+", "%10", 1)

    local tip = GetScanTooltip()

    -- Use SetHyperlink for BOTH tooltips so they are generated the same
    -- way.  SetInventoryItem adds context lines (upgrade level, currently
    -- equipped, etc.) that SetHyperlink does not, which causes false diffs.
    tip:ClearLines()
    tip:SetHyperlink(itemString)
    local realLines = {}
    for i = 1, tip:NumLines() do
        local left = _G[SCAN_TIP_NAME .. "TextLeft" .. i]
        if left then
            local text = left:GetText()
            if text then realLines[#realLines + 1] = text end
        end
    end

    -- Collect lines from the clean (unenchanted) tooltip
    tip:ClearLines()
    tip:SetHyperlink(cleanString)
    local cleanSet = {}
    for i = 1, tip:NumLines() do
        local left = _G[SCAN_TIP_NAME .. "TextLeft" .. i]
        if left then
            local text = left:GetText()
            if text then cleanSet[text] = true end
        end
    end

    -- The line present in the real tooltip but absent from the clean one
    -- is the enchant effect text
    for _, line in ipairs(realLines) do
        if not cleanSet[line] then
            return ShortenText(line)
        end
    end

    return nil
end

------------------------------------------------------------------------
-- Profession detection
------------------------------------------------------------------------

function Scanner:GetPlayerProfessions()
    local profs = {}
    local p1, p2 = GetProfessions()

    local function add(idx)
        if not idx then return end
        local name = GetProfessionInfo(idx)
        if name then profs[name] = true end
    end

    add(p1)
    add(p2)
    return profs
end

------------------------------------------------------------------------
-- Off-hand type check
------------------------------------------------------------------------

function Scanner:IsOffHandEnchantable(itemLink)
    if not itemLink then return false end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc then return false end
    return AGC.EnchantData.ENCHANTABLE_EQUIP_LOCS[equipLoc] or false
end

------------------------------------------------------------------------
-- Full equipment scan
------------------------------------------------------------------------

--- Detect an engineering tinker on an equipped item.
--- First checks all item link fields for known tinker enchant IDs
--- (locale-independent). Falls back to tooltip text scanning.
function Scanner:DetectTinker(slotId, parsed)
    local EngineerData = AGC.EngineerData
    if not EngineerData then return nil end

    -- 1) ID-based check: scan ALL item link fields for known tinker IDs
    local tinkerEffects = EngineerData.TINKER_EFFECTS
    if parsed and parsed.allFields and tinkerEffects then
        for _, fieldVal in ipairs(parsed.allFields) do
            if fieldVal > 0 and tinkerEffects[fieldVal] then
                return tinkerEffects[fieldVal]
            end
        end
    end

    -- 2) Fallback: tooltip text scan (for cases where the ID isn't
    --    in a standard field, or the ID table is incomplete)
    local patterns = EngineerData.TINKER_TOOLTIP_PATTERNS
    if patterns then
        local tip = GetScanTooltip()
        tip:SetOwner(WorldFrame, "ANCHOR_NONE")
        tip:ClearLines()
        tip:SetInventoryItem("player", slotId)

        for i = 1, tip:NumLines() do
            local left = _G[SCAN_TIP_NAME .. "TextLeft" .. i]
            if left then
                local text = left:GetText()
                if text then
                    for _, pattern in ipairs(patterns) do
                        if text:lower():find(pattern:lower(), 1, true) then
                            return pattern
                        end
                    end
                end
            end
        end
    end

    return nil
end

function Scanner:ScanEquipment()
    local results = {}

    for slotId = 1, 17 do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            local parsed = Version:ParseItemLink(itemLink)
            if parsed then
                local hasExtra = self:HasExtraSocket(slotId, parsed)
                local enchText = self:GetEnchantText(slotId, parsed)
                local tinkerName = self:DetectTinker(slotId, parsed)

                results[slotId] = {
                    itemLink       = itemLink,
                    parsed         = parsed,
                    hasEnchant     = (parsed.enchantId or 0) > 0,
                    enchantId      = parsed.enchantId or 0,
                    filledGems     = self:CountFilledGems(parsed),
                    hasExtraSocket = hasExtra,
                    enchantText    = enchText,
                    hasTinker      = (tinkerName ~= nil),
                    tinkerName     = tinkerName,
                }
            end
        end
    end

    local professions = self:GetPlayerProfessions()
    return results, professions
end
