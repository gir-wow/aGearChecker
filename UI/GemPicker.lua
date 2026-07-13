local addonName, AGC = ...

------------------------------------------------------------------------
-- GemPicker — gem browser overlay for the ItemSocketingFrame
--
-- Socket frame structure (from Blizzard_ItemSocketingUI source):
--   ItemSocketingFrame.SocketingContainer.SocketFrames[i]  — socket buttons
--   ItemSocketingFrame.SocketingContainer.Socket1/2/3      — same buttons
--
-- Real socket APIs (C_ItemSocketInfo):
--   GetNumSockets()          → number of sockets on the item
--   GetSocketTypes(i)        → "Red" / "Blue" / "Yellow" / "Meta" / etc.
--   ClickSocketButton(i)     → places cursor gem into socket i
--
-- Flow when user picks a gem from our list:
--   PickupContainerItem(bag, slot) → gem goes on cursor
--   C_ItemSocketInfo.ClickSocketButton(socketIdx) → drops it in
--
-- Gem subtype (GetItemInfo) → socket type mapping (MoP):
--   Red     ← Red, Orange, Purple, Prismatic Gems
--   Yellow  ← Yellow, Orange, Green, Prismatic Gems
--   Blue    ← Blue, Green, Purple, Prismatic Gems
--   Meta    ← Meta Gems only
--   Cogwheel← Cogwheel Gems only
------------------------------------------------------------------------

local GemPicker = {}
AGC.GemPicker = GemPicker

------------------------------------------------------------------------
-- API wrappers with MoP Classic fallbacks
------------------------------------------------------------------------
local function GetNumSockets()
    return (C_ItemSocketInfo and C_ItemSocketInfo.GetNumSockets())
        or (_G.GetNumSockets and _G.GetNumSockets()) or 0
end

local function GetSocketType(i)
    return (C_ItemSocketInfo and C_ItemSocketInfo.GetSocketTypes(i))
        or (_G.GetSocketTypes and _G.GetSocketTypes(i)) or "Prismatic"
end

local function ClickSocket(i)
    if C_ItemSocketInfo and C_ItemSocketInfo.ClickSocketButton then
        C_ItemSocketInfo.ClickSocketButton(i)
    end
end

local function GetSocketContainer()
    -- Modern: ItemSocketingFrame.SocketingContainer (GenericItemSocketingFrameTemplate)
    -- The SocketFrames parentArray holds Socket1/Socket2/Socket3
    if ItemSocketingFrame then
        local c = ItemSocketingFrame.SocketingContainer
        if c then return c end
        -- Fallback: SocketingContainer might be the scroll child
        local sc = ItemSocketingFrame.ScrollFrame
        if sc then
            local child = sc:GetScrollChild()
            if child and child.SocketFrames then return child end
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Gem subtype (GetItemInfo) → socket types the gem can fill (MoP)
------------------------------------------------------------------------
local GEM_FITS_SOCKET = {
    -- GetItemInfo returns "Meta" in MoP Classic (GEM_TYPE_INFO key),
    -- but older data files may store "Meta Gems" — handle both.
    ["Red"]            = { Red=true, Prismatic=true },
    ["Yellow"]         = { Yellow=true, Prismatic=true },
    ["Blue"]           = { Blue=true, Prismatic=true },
    ["Orange"]         = { Red=true, Yellow=true, Prismatic=true },
    ["Green"]          = { Yellow=true, Blue=true, Prismatic=true },
    ["Purple"]         = { Red=true, Blue=true, Prismatic=true },
    ["Meta"]           = { Meta=true },
    ["Meta Gems"]      = { Meta=true },
    ["Cogwheel"]       = { Cogwheel=true },
    ["Cogwheel Gems"]  = { Cogwheel=true },
    ["Hydraulic"]      = { Hydraulic=true },
    ["Hydraulic Gems"] = { Hydraulic=true },
    ["Prismatic"]      = { Red=true, Yellow=true, Blue=true, Orange=true,
                           Green=true, Purple=true, Prismatic=true },
    ["Prismatic Gems"] = { Red=true, Yellow=true, Blue=true, Orange=true,
                           Green=true, Purple=true, Prismatic=true },
}

-- Subtypes that must NEVER appear outside their own socket type
local LOCKED_GEM_SUBTYPE = {
    ["Meta"]           = true,
    ["Meta Gems"]      = true,
    ["Cogwheel"]       = true,
    ["Cogwheel Gems"]  = true,
    ["Hydraulic"]      = true,
    ["Hydraulic Gems"] = true,
}

-- Socket types that are hard-locked ("Any" filter cannot override)
local TYPE_LOCKED = { Meta=true, Cogwheel=true, Hydraulic=true }

------------------------------------------------------------------------
-- Gem quality colours for the list rows.
------------------------------------------------------------------------
local QUALITY_COLOR = {
    [0] = "|cff9d9d9d",   -- Poor
    [1] = "|cffffffff",   -- Common
    [2] = "|cff1eff00",   -- Uncommon
    [3] = "|cff0070dd",   -- Rare
    [4] = "|cffa335ee",   -- Epic
}

------------------------------------------------------------------------
-- Scan all bags for gems. Returns array of gem tables:
--   { bag, slot, link, name, quality, gemType, itemID }
------------------------------------------------------------------------
local function ScanBagsForGems()
    local gems = {}
    local getNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local getLink     = (C_Container and C_Container.GetContainerItemLink)  or GetContainerItemLink

    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (getNumSlots(bag) or 0) do
            local link = getLink(bag, slot)
            if link then
                local itemID = tonumber(link:match("item:(%d+)"))
                local name, _, quality, _, _, itemType, subType = GetItemInfo(link)
                if itemType == "Gem" and name then
                    gems[#gems + 1] = {
                        bag     = bag,
                        slot    = slot,
                        link    = link,
                        name    = name,
                        quality = quality or 0,
                        gemType = subType or "",
                        itemID  = itemID,
                    }
                end
            end
        end
    end
    -- Sort by quality desc, then name asc
    table.sort(gems, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return (a.name or "") < (b.name or "")
    end)
    return gems
end

------------------------------------------------------------------------
-- Filter a gem list for the given socket type and current filter mode.
-- filterMode: "color" | "any" | "favorites"
------------------------------------------------------------------------
local function FilterGems(gems, socketType, filterMode)
    local out = {}
    local locked = TYPE_LOCKED[socketType]
    local favorites = (aGearCheckDB.gemFavorites or {})[socketType] or {}

    for _, gem in ipairs(gems) do
        local fits = GEM_FITS_SOCKET[gem.gemType]

        if filterMode == "favorites" then
            -- Favourites: must be in favourites AND fit the socket
            if favorites[gem.itemID] and fits and fits[socketType] then
                out[#out + 1] = gem
            end
        elseif locked then
            -- Type-locked sockets: always enforce the type restriction
            if fits and fits[socketType] then
                out[#out + 1] = gem
            end
        elseif filterMode == "color" then
            -- Colour-match: gem must fit this socket
            if fits and fits[socketType] then
                out[#out + 1] = gem
            end
        else
            -- Any: show everything except type-locked gem subtypes
            -- (meta/cogwheel/hydraulic must never appear outside their own socket)
            if not LOCKED_GEM_SUBTYPE[gem.gemType] then
                out[#out + 1] = gem
            end
        end
    end
    return out
end

------------------------------------------------------------------------
-- Frame pool for gem list rows
------------------------------------------------------------------------
local ROW_HEIGHT = 24
local ICON_SIZE  = 20
local POPUP_W    = 280
local POPUP_ROWS = 10

-- Socket type colour labels (module-level so OpenPicker and RefreshTrigger can both use it)
local SOCKET_COLOR_TEXT = {
    Red       = "|cffff4444Red|r",
    Yellow    = "|cffffff44Yellow|r",
    Blue      = "|cff6699ffBlue|r",
    Orange    = "|cffff8800Orange|r",
    Green     = "|cff44ff44Green|r",
    Purple    = "|cffcc44ccPurple|r",
    Meta      = "|cffccccccMeta|r",
    Cogwheel  = "|cffbbbbbbCog|r",
    Prismatic = "|cffffffffAny|r",
}

------------------------------------------------------------------------
-- Build the popup frame (created once, reused).
------------------------------------------------------------------------
local popup          -- the main picker window
local rowFrames      = {}
local currentSocket  = 1           -- socket index (1-3)
local currentType    = "Prismatic" -- socket type string
local filterMode     = "color"     -- "color" | "any" | "favorites"
local allGems        = {}
local filteredGems   = {}
local scrollOffset   = 0

local function RefreshRows()
    for i, row in ipairs(rowFrames) do
        local gem = filteredGems[i + scrollOffset]
        if gem then
            local favs   = (aGearCheckDB.gemFavorites or {})[currentType] or {}
            local qColor = QUALITY_COLOR[gem.quality] or QUALITY_COLOR[1]
            row.icon:SetTexture(select(10, GetItemInfo(gem.link)) or
                                "Interface\\Icons\\INV_Misc_QuestionMark")
            row.label:SetText(qColor .. gem.name .. "|r")
            row.favBtn:SetText(favs[gem.itemID] and "|cffFFD700★|r" or "|cff888888☆|r")
            row.gem = gem
            row:Show()
        else
            row:Hide()
            row.gem = nil
        end
    end
    popup.scrollUp:SetEnabled(scrollOffset > 0)
    popup.scrollDown:SetEnabled(scrollOffset + POPUP_ROWS < #filteredGems)
    popup.countLabel:SetText(#filteredGems .. " gem" .. (#filteredGems ~= 1 and "s" or ""))
end

local function Refilter()
    scrollOffset = 0
    filteredGems = FilterGems(allGems, currentType, filterMode)
    RefreshRows()
end

local function BuildPopup()
    if popup then return end

    -- Invisible full-screen click-away frame (sits behind the popup)
    local dismiss = CreateFrame("Frame", nil, UIParent)
    dismiss:SetAllPoints(UIParent)
    dismiss:SetFrameStrata("DIALOG")
    dismiss:SetFrameLevel(1)
    dismiss:EnableMouse(true)
    dismiss:Hide()
    dismiss:SetScript("OnMouseDown", function() popup:Hide() end)

    popup = CreateFrame("Frame", "AGCGemPickerPopup", UIParent, "BackdropTemplate")
    popup:SetSize(POPUP_W, POPUP_ROWS * ROW_HEIGHT + 72)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(2)
    popup:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=14,
        insets={left=3, right=3, top=3, bottom=3},
    })
    popup:SetBackdropColor(0.08, 0.08, 0.12, 0.97)
    popup:EnableMouse(true)
    popup:Hide()

    -- Show/hide the dismiss layer in sync with popup
    popup:SetScript("OnShow", function() dismiss:Show() end)
    popup:SetScript("OnHide", function() dismiss:Hide() end)

    local y = -6

    -- Header label (no title bar, just a small text label)
    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.title:SetPoint("TOPLEFT", popup, 8, y)
    y = y - 16

    -- Filter radio buttons
    local function MakeRadio(label, mode, xOff)
        local rb = CreateFrame("CheckButton", nil, popup, "UIRadioButtonTemplate")
        rb:SetPoint("TOPLEFT", popup, "TOPLEFT", xOff, y)
        rb.text = rb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rb.text:SetPoint("LEFT", rb, "RIGHT", 2, 0)
        rb.text:SetText(label)
        rb:SetScript("OnClick", function()
            filterMode = mode
            popup.rbColor:SetChecked(mode == "color")
            popup.rbAny:SetChecked(mode == "any")
            popup.rbFav:SetChecked(mode == "favorites")
            Refilter()
        end)
        return rb
    end

    popup.rbColor = MakeRadio("Match",     "color",     8)
    popup.rbAny   = MakeRadio("Any",       "any",       80)
    popup.rbFav   = MakeRadio("Favorites", "favorites", 140)
    popup.rbColor:SetChecked(true)

    y = y - 22

    -- Divider
    local div = popup:CreateTexture(nil, "ARTWORK")
    div:SetHeight(2)
    div:SetPoint("TOPLEFT",  popup, "TOPLEFT",  8,          y)
    div:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -8,         y)
    div:SetColorTexture(0.3, 0.3, 0.3, 1)
    y = y - 6

    -- Gem rows
    local listTop = y
    for i = 1, POPUP_ROWS do
        local row = CreateFrame("Button", nil, popup)
        row:SetSize(POPUP_W - 16, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, listTop - (i - 1) * ROW_HEIGHT)

        -- Hover highlight
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.1)

        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = icon

        -- Favourite star button
        local favBtn = CreateFrame("Button", nil, row)
        favBtn:SetSize(20, 20)
        favBtn:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        local favText = favBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        favText:SetAllPoints()
        favText:SetJustifyH("CENTER")
        favBtn:SetFontString(favText)
        row.favBtn = favBtn

        -- Gem name
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", favBtn, "RIGHT", 4, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        row.label = label

        -- Tooltip on hover
        row:SetScript("OnEnter", function(self)
            if self.gem then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.gem.link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click: pick up gem then socket it
        -- Use the socket button's own ClickSocketButton mixin (most reliable)
        row:SetScript("OnClick", function(self)
            local gem = self.gem
            if not gem then return end
            local idx = currentSocket
            popup:Hide()
            local pickupFn = (C_Container and C_Container.PickupContainerItem)
                           or PickupContainerItem
            if not pickupFn then return end
            pickupFn(gem.bag, gem.slot)
            -- Give the cursor state one frame to update, then click the socket
            C_Timer.After(0.1, function()
                local container = GetSocketContainer()
                if not container then ClickSocket(idx); return end
                local socketBtn = (container.SocketFrames and container.SocketFrames[idx])
                               or container["Socket" .. idx]
                if socketBtn and socketBtn.ClickSocketButton then
                    socketBtn:ClickSocketButton()   -- uses the Blizzard mixin directly
                elseif socketBtn and socketBtn.OnReceiveDrag then
                    socketBtn:OnReceiveDrag()
                else
                    ClickSocket(idx)                -- C_ItemSocketInfo fallback
                end
            end)
        end)

        -- Favourite star toggle
        favBtn:SetScript("OnClick", function()
            local gem = row.gem
            if not gem then return end
            if not aGearCheckDB.gemFavorites then aGearCheckDB.gemFavorites = {} end
            if not aGearCheckDB.gemFavorites[currentType] then
                aGearCheckDB.gemFavorites[currentType] = {}
            end
            local t = aGearCheckDB.gemFavorites[currentType]
            t[gem.itemID] = t[gem.itemID] and nil or true
            RefreshRows()
        end)

        row:Hide()
        rowFrames[i] = row
    end

    y = listTop - POPUP_ROWS * ROW_HEIGHT - 4

    -- Scroll buttons
    local scrollUp = CreateFrame("Button", nil, popup, "UIPanelScrollUpButtonTemplate")
    scrollUp:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -8, y + ROW_HEIGHT + 8)
    scrollUp:SetScript("OnClick", function()
        if scrollOffset > 0 then
            scrollOffset = scrollOffset - 1
            RefreshRows()
        end
    end)
    popup.scrollUp = scrollUp

    local scrollDown = CreateFrame("Button", nil, popup, "UIPanelScrollDownButtonTemplate")
    scrollDown:SetPoint("TOP", scrollUp, "BOTTOM", 0, -4)
    scrollDown:SetScript("OnClick", function()
        if scrollOffset + POPUP_ROWS < #filteredGems then
            scrollOffset = scrollOffset + 1
            RefreshRows()
        end
    end)
    popup.scrollDown = scrollDown

    -- Mouse wheel scroll
    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 and scrollOffset > 0 then
            scrollOffset = scrollOffset - 1
            RefreshRows()
        elseif delta < 0 and scrollOffset + POPUP_ROWS < #filteredGems then
            scrollOffset = scrollOffset + 1
            RefreshRows()
        end
    end)

    -- Item count label
    local countLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countLabel:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 10, 8)
    popup.countLabel = countLabel
end

------------------------------------------------------------------------
-- Open the picker for socket index idx; anchor to triggerBtn
------------------------------------------------------------------------
local function OpenPicker(idx, triggerBtn)
    BuildPopup()

    local socketType = GetSocketType(idx) or "Prismatic"

    -- Toggle off if already showing the same socket
    if popup:IsShown() and currentSocket == idx and currentType == socketType then
        popup:Hide()
        return
    end

    currentSocket = idx
    currentType   = socketType

    if TYPE_LOCKED[socketType] then filterMode = "color" end
    popup.rbColor:SetChecked(filterMode == "color")
    popup.rbAny:SetChecked(filterMode == "any")
    popup.rbFav:SetChecked(filterMode == "favorites")
    popup.rbAny:SetEnabled(not TYPE_LOCKED[socketType])
    popup.title:SetText((SOCKET_COLOR_TEXT[socketType] or socketType) .. " socket gems")

    allGems = ScanBagsForGems()
    Refilter()

    -- Anchor popup: open upward from the trigger button so it doesn't
    -- cover the socket icons or go below the frame edge
    popup:ClearAllPoints()
    if triggerBtn then
        popup:SetPoint("BOTTOM", triggerBtn, "TOP", 0, 4)
    elseif ItemSocketingFrame then
        popup:SetPoint("BOTTOM", ItemSocketingFrame, "TOP", 0, 4)
    else
        popup:SetPoint("CENTER")
    end
    popup:Show()
end

------------------------------------------------------------------------
-- Trigger buttons — one small "▼" button directly below each socket icon
------------------------------------------------------------------------
local triggerBtns = {}

local function RefreshTriggerButtons()
    for _, b in ipairs(triggerBtns) do b:Hide() end

    if not ItemSocketingFrame or not ItemSocketingFrame:IsShown() then return end

    local container = GetSocketContainer()
    local n = GetNumSockets()
    for i = 1, n do
        local socketType = GetSocketType(i) or "Prismatic"
        -- Get the actual socket button frame so we can anchor to it
        local socketBtn = container and (
            (container.SocketFrames and container.SocketFrames[i])
            or container["Socket" .. i]
        )

        if not triggerBtns[i] then
            -- Texture-only button — no UIPanelButton chrome, just Blizzard's arrowdown atlas
            local tb = CreateFrame("Button", nil, ItemSocketingFrame)
            tb:SetSize(28, 40)
            tb:EnableMouse(true)

            local norm = tb:CreateTexture(nil, "ARTWORK")
            norm:SetAllPoints()
            norm:SetAtlas("hud-MainMenuBar-arrowdown-up", false)
            tb:SetNormalTexture(norm)

            local pushed = tb:CreateTexture(nil, "ARTWORK")
            pushed:SetAllPoints()
            pushed:SetAtlas("hud-MainMenuBar-arrowdown-down", false)
            tb:SetPushedTexture(pushed)

            local hlTex = tb:CreateTexture(nil, "HIGHLIGHT")
            hlTex:SetAllPoints()
            hlTex:SetAtlas("hud-MainMenuBar-arrowdown-highlight", false)
            hlTex:SetAlpha(0.6)
            tb:SetHighlightTexture(hlTex)

            tb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine((SOCKET_COLOR_TEXT[GetSocketType(i)] or "Socket " .. i)
                                    .. " — browse gems in bags", 1, 1, 1)
                GameTooltip:Show()
            end)
            tb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            triggerBtns[i] = tb
        end

        local tb  = triggerBtns[i]
        local idx = i
        tb:ClearAllPoints()
        if socketBtn then
            tb:SetPoint("LEFT", socketBtn, "RIGHT", 2, 0)
        else
            tb:SetPoint("BOTTOMLEFT", ItemSocketingFrame, "BOTTOMLEFT",
                        40 + (i - 1) * 56, 28)
        end
        tb:SetScript("OnClick", function() OpenPicker(idx, triggerBtns[idx]) end)
        tb:Show()
    end
end

local hooked = false
local function HookSocketingFrame()
    if hooked or not ItemSocketingFrame then return end
    hooked = true
    ItemSocketingFrame:HookScript("OnShow", RefreshTriggerButtons)
    ItemSocketingFrame:HookScript("OnHide", function()
        for _, b in ipairs(triggerBtns) do b:Hide() end
        if popup then popup:Hide() end
    end)
end

------------------------------------------------------------------------
-- Initialise
------------------------------------------------------------------------
function GemPicker:Init()
    if not aGearCheckDB.gemFavorites then
        aGearCheckDB.gemFavorites = {}
    end

    -- Blizzard_ItemSocketingUI is LoadOnDemand — it only exists after the
    -- player first opens the socketing UI (Shift+Right-Click at a socket NPC).
    -- We wait for its ADDON_LOADED, then hook the frame.
    -- SOCKET_INFO_UPDATE fires whenever socket state changes (frame open/update)
    -- and serves as a belt-and-suspenders refresh trigger.
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("SOCKET_INFO_UPDATE")
    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_ItemSocketingUI" then
            HookSocketingFrame()
            f:UnregisterEvent("ADDON_LOADED")
        elseif event == "SOCKET_INFO_UPDATE" then
            -- Frame is definitely visible now; hook if we haven't yet
            HookSocketingFrame()
            RefreshTriggerButtons()
        end
    end)

    -- In case Blizzard_ItemSocketingUI already loaded (e.g. /reload after first use)
    HookSocketingFrame()
end
