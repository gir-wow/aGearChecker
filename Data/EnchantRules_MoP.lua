local _, AGC = ...
AGC.EnchantData = {}

local D = AGC.EnchantData

-- Slots that should always have an enchant (all players)
D.ENCHANTABLE_SLOTS = {
    [3]  = "Shoulder",
    [5]  = "Chest",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [15] = "Back",
    [16] = "Main Hand",
}

-- Off-hand (17): enchantable only when the item is a weapon or shield
D.OFFHAND_SLOT = 17

-- Ring slots: enchantable only by Enchanters
D.RING_SLOTS = {
    [11] = "Ring 1",
    [12] = "Ring 2",
}

-- Belt slot for Living Steel Belt Buckle check
D.BELT_SLOT = 6

-- Blacksmithing extra-socket slots (Socket Bracer / Socket Gloves)
D.BS_SOCKET_SLOTS = {
    [9]  = "Wrist",
    [10] = "Hands",
}

-- Profession name constants (English locale; may need localization layer later)
D.PROF_ENCHANTING    = "Enchanting"
D.PROF_BLACKSMITHING = "Blacksmithing"
D.PROF_ENGINEERING   = "Engineering"

-- Off-hand equip locations that are enchantable
D.ENCHANTABLE_EQUIP_LOCS = {
    INVTYPE_SHIELD        = true,
    INVTYPE_WEAPON        = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_2HWEAPON      = true,
    INVTYPE_RANGEDRIGHT   = true,
    INVTYPE_HOLDABLE      = true,
}
