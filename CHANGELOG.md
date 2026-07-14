# aGearCheck Changelog

## v1.2.3

### Bug Fixes
- Fixed game crash when using GemPicker on items in inventory (not equipped)
- Now uses safe C_ItemSocketInfo API instead of calling Blizzard frame mixin methods directly

## v1.2.2

- Updated changelog format

## v1.2.1

### Bug Fixes
- Replaced 3-second polling timer with event-based tab detection
- Gear overlay labels no longer linger when switching CharacterFrame tabs
- Uses PanelTemplates_SetTab hook for reliable tab change detection

## v1.1.0

- GemPicker: per-socket gem browser with dropdown, filtering, and favourites
- Socket debug info in debug window

## v1.0.0

- Character gear enhancement overlay
- Highlights missing enchants, sockets, and profession-specific enhancements
