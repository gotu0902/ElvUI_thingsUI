# Changelog

## 3.0.3

### Added
- **Charge Bar** — per-spec spell charge tracker, toggle NHT for anchor mode into the BCDM cluster, or FHT if you want it to be able to move it freely\anchor to w\e you want. It saves the option globally on the Elv profile.
- **Classbar Mode** — per-spec ElvUI classbar, placing itself where you anchor it. May be useful for non-BCDM users. Mostly made for NHT profile.
- **Trinket Blacklist** — hide specific trinkets from Trinkets to CDM layout
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
