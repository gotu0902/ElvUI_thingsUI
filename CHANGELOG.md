# Changelog

## 4.0.1

- Nudge guard for movers when anchored  
- Hide editmode viewer frames (ty Dan legend)  
- Shapeshifting in combat triggered a refresh that moved CDM (ty Dan x2)  
- Trinket -> Dynamic not watching CDM children (I'm stupid and lazy, Dan was busy, tasked Claude for that, seems to work okay)  

## 4.0.0

### Added
- **Installer** - one-time setup: import an NHT/FHT preset, UI scale, unitframe coloring, positions, Details! anchor, action bar layout, and ElvUI UnitFrames vs Grid2. Re-run from the Share tab.
- **Custom Groups** - icon groups for spells, special icons and items, with per-group size/position/text (cooldown, count, stacks) and smart potion/quality grouping.
- **Custom Timers** - cast-triggered static-icon timers, anchored in a Custom Group or CDM.
- **Racials to CDM** - fold racial cooldowns into the CDM viewers.
- **Share** - export/import your thingsUI config as a string, per module or w\e.
- **Grid2 Profiles** - variety of Grid2 variations with Class Colored or Dark Mode profiles (NHT, FHT Icons/Squares)
- **UnitFrame Coloring** - Class Colored or Dark Mode toggle.

### Changed
- "Positioning Tweaks" tab renamed "ElvUI QoL".
- Charge Bar and Classbar spell pickers are spec-aware, with an "Add Current Spec" button.
- Mover handling unified - live drag, lock, labels, profile-switch cleanup.

### Fixed
- CDM stack/count text no longer flickers against ElvUI's Cooldown Manager styling.
- Special bars/icons apply immediately on enable/disable.
- Custom group movers no longer linger after a profile switch.
- Grouped Special Icons fold in correctly on spell pick.

## 3.0.3

### Added
- **Charge Bar** - per-spec spell charge tracker, toggle NHT for anchor mode into the BCDM cluster, or FHT if you want it to be able to move it freely\anchor to w\e you want. It saves the option globally on the Elv profile.
- **Classbar Mode** - per-spec ElvUI classbar, placing itself where you anchor it. May be useful for non-BCDM users. Mostly made for NHT profile.
- **Trinket Blacklist** - hide specific trinkets from Trinkets to CDM layout
- Frame Strata dropdowns on Buff Bars, Charge Bar, Classbar Mode, Special Bars/Icons
- Charge Bar / Classbar Mode can stack on each other (Above Classbar / Above Charge Bar slots)
- BCDM Secondary Power Bar, Buff Icons, BCDM CastBar, Grid2 added as anchor presets
- Special Bars/Icons: Restore Defaults button, registered with `/emove`

### Changed
- Options split into per-feature files
- BCDM + ElvUI tab restructured with Trinkets sub-tab
- Inline groups instead of headers in most tabs
- Anchor points unified to Title Case ("Top Left" not "TOPLEFT")
- Charge Bar Spec Options auto-selects current spec
- 0.01 step on most sliders
- Buff bar dropdown sorting and coloring rework

### Fixed
- Anchor From/To resetting on world enter / CDM viewer toggle
- Trinkets to CDM no longer breaks cluster width calculation
- Charge Bar predicts charge state to survive combat taint
- Classbar/Charge Bar width correct when trinkets are blacklisted
