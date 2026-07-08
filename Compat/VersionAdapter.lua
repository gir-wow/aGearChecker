local _, AGC = ...
AGC.Version = {}

local Version = AGC.Version

function Version:GetTocVersion()
    local _, _, _, tocVersion = GetBuildInfo()
    return tocVersion or 0
end

function Version:IsMoP()
    local toc = self:GetTocVersion()
    return toc >= 50500 and toc < 60000
end

-- Parse an equipped item link into a structured table.
-- MoP link field order after "item:":
--   itemId : enchantId : gem1 : gem2 : gem3 : gem4 : suffixId : uniqueId : level : upgradeId ...
function Version:ParseItemLink(itemLink)
    if not itemLink then return nil end

    local itemString = itemLink:match("item:([%-?%d:]+)")
    if not itemString then return nil end

    local fields = {}
    for field in (itemString .. ":"):gmatch("(%-?%d*):") do
        fields[#fields + 1] = tonumber(field) or 0
    end

    return {
        itemId    = fields[1] or 0,
        enchantId = fields[2] or 0,
        gem1      = fields[3] or 0,
        gem2      = fields[4] or 0,
        gem3      = fields[5] or 0,
        gem4      = fields[6] or 0,
        allFields = fields,   -- all raw fields for extended checks
    }
end
