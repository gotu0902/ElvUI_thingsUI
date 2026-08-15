# Changelog

## 4.1.2
- Tweaked spec change refresh
- Glow shows in group previews
- Test mode preview didn't turn itself off when going directly to another elv menu
- Moved border stroke to glow options -> bordered stroke. Takes over the border size (thickness)
- Pixel glow clean fix #83 and a half
- Switched all icons over to ElvUI's CDM skin to get rid of some weird stuff I did. Will need to turn on borders for icon groups if their not, and change spacings from f.ex 1 to -1, and offset that were 1-2 px extra cause of my shitty border thing, can go back to normal offsets. (or just reimport plugin presets). 1 pixel should be 1 pixel, as long as the correct UI scale is used.
- Added delete button to groups, remove spec icons\bars from custom group is now a yellow minus, red X perma delete
- Special Bars shouldn't be able to choose a custom group when in a bar setup anymore
- Timers now reacts if the spell is part of an totem event
- Added totem timer toggle to specials

## 4.1.1
- Forgot to update alt preset export for ElvUI's new data format, woops.
- Edit Mode layouts can be assigned to other specs in /tuialt, auto-switches on spec change.
- LibCustomGlow for Essential\Utility viewers (CDM -> Glow)
- AuraContainer glow for group icons when sorted
- Fixed trinket blacklisting fucking things up, showing wrong cooldown\not showing CD at all
- Fixed error when removing a special icon
- Added a temu Pixel Glow that works on aura containers
- Fixed sliders only moving one step per drag in most panels
- Buff Icon count fighting with Elvs skinning
- Fixed inherited-width bar groups sometimes getting the wrong width after spec change

## 4.1.0
- Fixed max group icons not working
- Small rename for clarification that spells are cd, not buff (request)
- Not show style warning if bar is part of a bar setup
- Fixed bars not previewing correctly
- Style picker for groups, custom group picker
- Option pages build on demand so it doesn't lags out the whole config (mybad)
- New Aura Order / Bar Order in the Order tab for groups - manual or time-sorted (longest/shortest/newest/oldest)
- Sorted order makes Max Icons / Max Bars actually cap live auras
- Max Bars works in manual order too (cuts everything past the first N lines)
- Bar groups: Order tab matches icon groups - Global/Class/Spec blocks reorder with arrows, live order preview
- Bar groups: Layout and Position merged into one tab, Max Icons moved to Order tab
- Special bars in a bar group can be set to Buff/Debuff - target DoTs render again
- Fixed random buff icons in vehicles, mind control and loading screens - untrusted groups hide and shouuuld recover automatically
- Fixed random enemy buffs when tracking buffs with unit target/focus
- Fixed live bars/icons popping up on top of test mode previews
- Fixed newly added buffs landing mid-list after reordering
- Fixed scope-picker popup leaking frames when closed with X
- Share export/import rewritten for ElvUI's new data format (!TUI2!) - old strings and the built-in presets must be re-exported
- Mixed groups: buffs and target debuffs can live in one icon group - debuffs attach to the group's edge (new Debuff Side option: Auto/Top/Bottom/Left/Right)
- Style "Use style on" links moved to the Styles tab
- Popups don't inherit configs transparency if any
- Fixed deleted groups leaving their aura containers running in the background


## 4.1.0-beta3
- Fixed minimum width not doing shit when CDM is empty (when leveling etc)
- Custom Groups can quick add Special Icons, or add\move existing ones.
- Special Icons stack counter had a higher frame strata than the glow, woopsie.
- Class Bar got an whole class option, so it shows when leveling and cleans up the list a bit.
- Hopefully fixed buff bars sometimes inheriting special bars style when shuffling stuff in CDM
- Added a profile setup popup for alts (/tuialt), choose profiles for elv, grid, bw, br and editmode in one window. Still need to set editmode for other specs one time tho cause idontfuckingknowdude.
- Add auras to custom groups with spellID or a dropdown with the importantish ones. Multi add groups in cg -> auras.
- CGs can be anchored to buff icons, so auras can piggyback of them.
- Fixes to mini meter: death log, layout\design.
- Special icons/bars render via aura containers. Grouped special icons live in the group's lane. glow styles: pulse/proc/marching ants, not as nice as libcustomglow but we can't do that with auracontainers atm... pandemic texture for dots was luckily a thing in last build.
- New module Groups - Bars: aura-driven buff/debuff bars w/ spec/class/global lists, presets, special bars fold in, half-width bars share a line, inherit w/h from anchor
- Custom groups renamed Groups - Icons, entry counts in the scope tabs, centered growth (h/v) for icons AND the lane
- Trinkets tab moved as a module to a tab in CDM: hide cooldown and buff separately, blacklist by item, and move to a custom group.
- Add buff = externals only, special picker simplified (no icon/bar split, live = green)
- Test mode covers icons/bars/specials with stand-ins for everything, hopefully.


## 4.1.0-beta2
- Skinned minimal dmg meter thing
- Anchor support and extra layout options for MinimapButtonButton addon

## 4.1.0-beta1
- Racial reworked to fit with blizzard new cdm stuff

## 4.0.4
- Added copy special buttons more places
- Added style presets to specials
- Added text to the Essential mover (when cluster is enabled) pointing out it's the master of the movers. Hope that won't be a movie title.
- Added focus frame to cluster and anchor list.
- Swaped links out for a counter in the dropdowns for custom groups etc, got kind of messy.
- Filter added to copy specials popup. Sort list by style toggle.
- New preset string: added some prot pala and shadow specials, more preset stuff coming, prob before 12.1
- Import wizard popup when importing strings. Choose to nuke and overwrite everything exported, or just the modules and the stuff you want from them. Swap from input to popup for export as well. 
- Removed "Accept" button validation from import field.
- French referees apparently really really like englishmen, especially in quarter-finals.
- Bar Setup default Y-offset was wrong, set the default order to Power -> Class -> Charge -> Cast
- Bar Order height weren't stored per setup, woopsie.
- CG spells in Class didn't check if you actually knew it woopsie x2
- Merged cluster settings.
- Hide spec tab for global bar setup.

## 4.0.3
- Fixed Special Bars flicker caused when casting f.ex Mind Flay Insanity
- Tried integrating ElvUI's CDM skin border into the spacing\gap math (If it doesn't work, Claude did it)
- Fixed levelup refresh (DannyG the legend)
- Auto-enable Cooldown Manager on new characters (toggle in CDM menu)

## 4.0.2

- Disabled mode for Power Bar @ Bar Setup, when you don't need to see mana like for dragons etc
- Fixed Power Bar when in attached mode, causing attached height bleeding into Global height
- Added Disable Aura Overlay toggle -> in CDM menu
- Diffuse and Dampen were in the preset list woopsiedaisy
- Cannibalize added to racials (undeads gotta know when to eat)
- Castbar default at the top in bar setup
- New things strings hehhh
- Grid2 strings - tried to align opacity with ElvUI UFs

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