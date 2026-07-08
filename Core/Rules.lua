local _, AGC = ...
AGC.Rules = {}

local Rules        = AGC.Rules
local EnchantData  = AGC.EnchantData
local EngineerData = AGC.EngineerData

------------------------------------------------------------------------
-- Evaluate all rules against scanned equipment.
-- Returns a table keyed by slotId, each value a list of issues:
--   { type = string, text = string, severity = "missing"|"present" }
------------------------------------------------------------------------

function Rules:Evaluate(scanResults, professions)
    local issues = {}

    local function add(slotId, issueType, text, severity)
        issues[slotId] = issues[slotId] or {}
        issues[slotId][#issues[slotId] + 1] = {
            type     = issueType,
            text     = text,
            severity = severity,
        }
    end

    -- 1. Generic enchant check on always-enchantable slots
    for slotId in pairs(EnchantData.ENCHANTABLE_SLOTS) do
        local item = scanResults[slotId]
        if item then
            if not item.hasEnchant then
                add(slotId, "missing_enchant", "No Enchant", "missing")
            elseif item.enchantText then
                add(slotId, "enchant_present", item.enchantText, "present")
            end
        end
    end

    -- 2. Off-hand enchant (only when item is weapon / shield)
    local ohSlot = EnchantData.OFFHAND_SLOT
    local ohItem = scanResults[ohSlot]
    if ohItem and AGC.Scanner:IsOffHandEnchantable(ohItem.itemLink) then
        if not ohItem.hasEnchant then
            add(ohSlot, "missing_enchant", "No Enchant", "missing")
        elseif ohItem.enchantText then
            add(ohSlot, "enchant_present", ohItem.enchantText, "present")
        end
    end

    -- 3. Ring enchants (Enchanting profession only)
    if professions[EnchantData.PROF_ENCHANTING] then
        for slotId in pairs(EnchantData.RING_SLOTS) do
            local item = scanResults[slotId]
            if item then
                if not item.hasEnchant then
                    add(slotId, "missing_ring_enchant", "No Ring Enchant", "missing")
                elseif item.enchantText then
                    add(slotId, "enchant_present", item.enchantText, "present")
                end
            end
        end
    end

    -- 4. Belt buckle (all players)
    local beltItem = scanResults[EnchantData.BELT_SLOT]
    if beltItem and not beltItem.hasExtraSocket then
        add(EnchantData.BELT_SLOT, "missing_belt_socket", "No Belt Buckle", "missing")
    end

    -- 5. Blacksmithing extra sockets
    if professions[EnchantData.PROF_BLACKSMITHING] then
        for slotId in pairs(EnchantData.BS_SOCKET_SLOTS) do
            local item = scanResults[slotId]
            if item and not item.hasExtraSocket then
                add(slotId, "missing_bs_socket", "No BS Socket", "missing")
            end
        end
    end

    -- 6. Engineering tinker check (tooltip-based, since tinkers coexist
    --    with regular enchants and use a separate item link field)
    if professions[EnchantData.PROF_ENGINEERING] then
        for slotId in pairs(EngineerData.TINKER_SLOTS) do
            local item = scanResults[slotId]
            if item then
                if item.hasTinker then
                    add(slotId, "engineering_tinker", item.tinkerName, "present")
                else
                    add(slotId, "missing_tinker", "No Tinker", "missing")
                end
            end
        end
    end

    return issues
end
