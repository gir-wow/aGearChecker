local _, AGC = ...
AGC.EngineerData = {}

local D = AGC.EngineerData

------------------------------------------------------------------------
-- Engineering tinker enchant IDs mapped to short display labels.
-- NOTE: Verify these IDs on a live MoP Classic server.
--       Use  /agc debug  to dump enchant IDs for your equipped gear.
------------------------------------------------------------------------
D.TINKER_EFFECTS = {
    -- Gloves (slot 10)
    [4179] = "Synapse Springs",
    [4180] = "Phase Fingers",
    [4359] = "Synapse Springs II",
    -- Belt (slot 6)
    [4188] = "Frag Belt",
    [4223] = "Nitro Boosts",
    [4899] = "Watergliding Jets",
    -- Back (slot 15)
    [4181] = "Flexweave Underlay",
    [4897] = "Goblin Glider",
}

-- Slots that may hold an engineering tinker.
D.TINKER_SLOTS = {
    [6]  = true,  -- Belt  (Nitro Boosts, Frag Belt, Watergliding Jets)
    [10] = true,  -- Gloves (Synapse Springs)
    [15] = true,  -- Back   (Goblin Glider)
}

-- Tooltip text patterns to detect tinkers (since tinkers are stored
-- separately from the enchantId field and can coexist with enchants).
-- Includes both named references and effect descriptions.
D.TINKER_TOOLTIP_PATTERNS = {
    "Synapse Springs",
    "Phase Fingers",
    "Frag Belt",
    "Nitro Boosts",
    "Watergliding Jets",
    "Flexweave Underlay",
    "Goblin Glider",
    -- Effect descriptions (locale-dependent fallback)
    "falling speed",                        -- Goblin Glider / Flexweave
    "increase your run speed",              -- Nitro Boosts
    "highest primary stat",                 -- Synapse Springs II
    "haste rating by",                      -- Synapse Springs
    "Intellect, Agility, or Strength",      -- Synapse Springs (MoP Classic)
    "Hurls a bomb",                         -- Frag Belt
    "Throws a Frag",                        -- Frag Belt
    "Phase Shift",                          -- Phase Fingers
    "Watergliding",                         -- Watergliding Jets
}
