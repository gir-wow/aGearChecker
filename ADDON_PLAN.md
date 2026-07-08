# HelaEnchantTips Addon Plan (WoW MoP Classic)

## Goal
Build a lightweight character-screen overlay addon that highlights missing item enhancements on equipped gear, with profession-aware rules and red warning text for missing requirements.

Target clients now:
- Interface: 50503
- Interface: 50504

Future:
- Expand logic to other WoW versions through a version-adapter layer.

## What the addon should show
On Character window open, display compact labels near each relevant equipped slot (inside toward the character model):
- Missing enchant on enchantable gear
- Missing profession sockets/enhancements (when profession conditions apply)
- Missing belt socket (always check)
- Missing ring enchants (only if player has Enchanting)

Color rules:
- Missing requirement: red text
- Present enhancement: neutral/green text (configurable)

Engineering behavior:
- If an engineering tinker is present (example: Synapse Springs), display either the effect name or a short effect text.
- Use a data-driven table for engineering enhancements so behavior can be expanded safely.

## Lightweight architecture (recommended)
Recommendation: do NOT use Ace for v1.

Why:
- Scope is small and event-driven.
- WoW base API already covers frames, events, slash commands, and saved variables.
- Avoiding Ace cuts load time, memory, and dependency maintenance.

When Ace would be worth adding later:
- If config UI grows large
- If localization/options/profiles become complex
- If modular plugin architecture is introduced

## Proposed file structure
- HelaEnchantTips.toc
- HelaEnchantTips.lua
- Core/EventBus.lua
- Core/Scanner.lua
- Core/Rules.lua
- UI/Overlay.lua
- Data/EnchantRules_MoP.lua
- Data/EngineeringEffects_MoP.lua
- Compat/VersionAdapter.lua

## TOC draft
- ## Interface: 50504 (ship this; optionally maintain a second branch/file for 50503 if required by distribution tooling)
- ## Title: HelaEnchantTips
- ## Notes: Character gear enhancement overlay for MoP Classic
- ## Author: Hela
- ## Version: 0.1.0
- ## SavedVariables: HelaEnchantTipsDB

Load order:
1. Compat/VersionAdapter.lua
2. Data/EnchantRules_MoP.lua
3. Data/EngineeringEffects_MoP.lua
4. Core/Rules.lua
5. Core/Scanner.lua
6. UI/Overlay.lua
7. Core/EventBus.lua
8. HelaEnchantTips.lua

## Rule model
Represent each check as data + evaluator, not hardcoded UI logic.

Each rule object:
- id
- slot
- requiresProfession (optional)
- appliesWhen(itemLink, playerState)
- isSatisfied(scanResult)
- missingText
- presentText (optional)
- severity (for future sorting)

### Initial rule set
1. Generic enchant missing checks
- Check enchantable slots and mark red if enchant ID is empty/zero where enchant is expected.

2. Blacksmithing sockets
- If player has Blacksmithing, require extra socket enhancement on:
  - Wrist
  - Hands
- If missing: red text per slot.

3. Belt socket
- Always check for belt buckle socket enhancement.
- Missing regardless of profession: red text.

4. Enchanting ring enchants
- If player has Enchanting, check both rings for ring enchants.
- Missing ring enchant: red text.

5. Engineering tinker display
- If engineering tinker detected on supported slots, show effect label (for example Synapse Springs).
- If absent where required by chosen rule mode, show red warning.

## Data strategy (important)
Use explicit MoP ID tables so checks are stable and fast:
- Enchant IDs by slot and expansion
- Profession-only enhancement IDs
- Engineering tinker IDs mapped to effect labels

Notes:
- Item link parsing is primary source for enchant and gem IDs.
- Keep text output independent from parser internals.

## Scanning strategy
Primary scan inputs:
- GetInventoryItemLink("player", slotId)
- Profession APIs for known primary professions
- Parsed item link fields (enchantId, gem IDs, etc.)

Socket validation approach:
- For profession-added sockets and belt socket, prefer known enhancement/enchant IDs from data tables.
- If needed for fallback, supplement with tooltip parsing behind a version adapter.

## UI overlay plan
Anchor model:
- Parent to CharacterFrame (or paper doll subframe if more stable in testing).
- One font string per tracked slot.
- Position labels inside slot columns toward the character model.

Behavior:
- Hide all labels when CharacterFrame is closed.
- On open or refresh trigger, recompute status and update visible labels.
- Red text for missing items; neutral/green for present effects.

Optional QoL:
- Small legend line at bottom: "Red = missing enhancement"
- Slash toggle to show/hide present statuses and show only missing

## Refresh/event strategy
Refresh when:
- Character frame opens (OnShow hook)
- Equipped item changes
- Relevant profession state or item enhancement changes

Event set (v1):
- PLAYER_LOGIN (init)
- PLAYER_ENTERING_WORLD (safety refresh)
- PLAYER_EQUIPMENT_CHANGED
- UNIT_INVENTORY_CHANGED (unit == "player")
- SKILL_LINES_CHANGED (profession updates)
- BAG_UPDATE_DELAYED (materials/consumable use aftermath)

Character frame integration:
- Hook CharacterFrame OnShow -> ForceRefresh
- Hook CharacterFrame OnHide -> HideOverlay

Performance:
- Debounce repeated events (0.05 to 0.2 sec)
- Reuse font strings; do not recreate widgets per refresh
- Single scan pass producing a normalized status table

## Suggested internal API
- Scanner.ScanPlayerEquipment() -> scanState
- Rules.Evaluate(scanState, playerState) -> issues
- Overlay.Render(issues)
- Overlay.Hide()
- EventBus.RequestRefresh(reason)

## Config (minimal)
SavedVariables defaults:
- showPresent = true
- showOnlyMissing = false
- fontSize = 12
- missingColor = {1, 0.2, 0.2}
- presentColor = {0.6, 1, 0.6}

Slash commands:
- /hetips missing (toggle showOnlyMissing)
- /hetips present (toggle showPresent)
- /hetips test (prints current evaluated issues)

## Expansion-ready design for future versions
Create a version adapter contract:
- GetClientFlavor()
- GetSupportedInterface()
- GetRuleDataForVersion()
- ParseItemLinkForVersion(itemLink)

Then keep expansion differences in Data + Compat only, while UI and event plumbing remain mostly unchanged.

## Development phases
Phase 1: Overlay + generic enchant checks
- Build frame, slot anchors, red missing text
- Refresh on frame open + equipment change

Phase 2: Profession-aware checks
- Add Blacksmithing gloves/wrist socket rules
- Add belt socket rule
- Add Enchanting ring checks

Phase 3: Engineering effect display
- Add tinker mapping table
- Show effect labels for detected tinkers

Phase 4: Hardening and compatibility
- Validate 50503 and 50504 behavior
- Add adapter seams for future expansion support

## Acceptance checklist
- Opening character screen shows overlay statuses immediately
- Changing gear updates statuses without reload
- Missing enhancements are red
- Blacksmithing socket checks only appear when Blacksmithing known
- Belt socket check appears regardless of profession
- Ring enchant checks only appear when Enchanting known
- Engineering enhancement labels appear when detected
- Addon remains lightweight (single addon, no external libs)

## Risks and mitigations
- Risk: exact enhancement IDs differ from assumptions
  - Mitigation: isolate IDs in data files and verify on live test characters
- Risk: tooltip/string-based checks break with localization
  - Mitigation: prefer ID-based checks first; fallback parser behind adapter
- Risk: event storms while equipping sets
  - Mitigation: debounce refresh and render once per burst

## Testing notes
Manual test matrix:
- No profession character
- Blacksmithing only
- Enchanting only
- Engineering only
- Multi-profession combinations
- Fully enchanted vs partially enchanted gear sets

Verify:
- Correct red warnings
- No stale labels after swapping items
- No noticeable frame-rate impact when opening CharacterFrame

## Phase 5: Inspect frame support (planned)

### Goal
Show the same enchant/socket overlay on the Inspect frame when inspecting
another player, so you can quickly spot missing enhancements on their gear.

### Key differences from the character screen
- **Frame**: Hook `InspectFrame` (loaded on demand via `Blizzard_InspectUI`)
  instead of `CharacterFrame`.
- **Slot buttons**: Use `InspectHeadSlot`, `InspectNeckSlot`, etc. instead of
  `CharacterHeadSlot`, etc.
- **Item data**: Use `GetInventoryItemLink(unit, slotId)` where `unit` is the
  inspected target. Data is only available after `INSPECT_READY` fires.
- **No profession detection**: There is no API to query another player's
  professions, so profession-gated rules (BS extra sockets, ring enchants for
  Enchanters, engineering tinkers) cannot apply. Only generic enchant checks
  and belt buckle detection will work.

### Implementation plan
1. **Data**: Add an `InspectSlotButtons` mapping table in `UI/Overlay.lua`
   (or a new `UI/InspectOverlay.lua` file).
2. **Scanner**: Add `Scanner:ScanUnit(unit)` that accepts any unit ID.
   Reuse `ParseItemLink`, `CountEmptySockets`, `HasExtraSocket`, and
   `GetEnchantText` with unit-aware tooltip calls
   (`tip:SetInventoryItem(unit, slotId)`).
3. **Rules**: Add a flag to `Rules:Evaluate` that disables profession-gated
   rules when inspecting (professions table will be empty).
4. **Overlay**: Create a second label pool anchored to the inspect slot
   buttons. Reuse `PositionLabel` logic with the inspect button names.
5. **EventBus**: Register `INSPECT_READY` event. On fire, scan the inspected
   unit and render on the inspect frame. Hook `InspectFrame:OnHide` to clean
   up labels.
6. **Load-on-demand**: Since `Blizzard_InspectUI` is loaded on demand, use
   `LoadAddOn("Blizzard_InspectUI")` or hook via `ADDON_LOADED` to defer
   inspect frame setup until it exists.

### Events
- `INSPECT_READY` — inspected unit data is available, trigger scan
- `ADDON_LOADED` (arg == "Blizzard_InspectUI") — hook InspectFrame

### Limitations to document
- Cannot detect inspected player's professions
- Socket detection via tooltip may behave differently for remote items
- Inspect data can be stale if the player moves out of range
- Rapid re-inspects should be debounced

### Estimated scope
Low-medium. Most core logic (Scanner, Rules, Overlay positioning) reuses
directly. New code is primarily the inspect-specific event handling, a second
label pool, and the unit-aware scanner variant.

## Debugging and local install
Use a local copy step so every test run uses the latest addon files in the WoW client.

Target folder:
- C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns

Expected addon layout in AddOns:
- C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\HelaEnchantTips\HelaEnchantTips.toc

Manual copy workflow:
1. Close the game client (or at least log out to character select).
2. Copy the project folder into AddOns as HelaEnchantTips.
3. Start the game and run /reload after changes while testing.

PowerShell copy command (run from project root):
```powershell
$src = "C:\git\HelaEnchantTips"
$dst = "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\HelaEnchantTips"
New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
```

Notes:
- This path may require PowerShell started as Administrator.
- If using OneDrive/Custom install path, update $dst accordingly.
- Keep this copy step as the primary debug deploy path until packaging automation is added.

### Resetting saved variables
When defaults change (new keys added, old keys renamed), the existing saved variables
file may hold stale values. Reset to clean defaults in-game:

```
/run HelaEnchantTipsDB = nil; ReloadUI()
```

This wipes the per-character settings and lets `InitDB()` repopulate them from the
current `DEFAULTS` table on the next load.

### Useful slash commands during development
| Command | Purpose |
|---|---|
| `/hetips test` | Print all detected issues to chat |
| `/hetips debug` | Dump raw enchant/gem IDs for every equipped slot |
| `/hetips missing` | Toggle showing present enchant effects |
| `/hgc` | Alias for `/hetips` |
