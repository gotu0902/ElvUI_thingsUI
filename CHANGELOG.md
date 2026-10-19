# Changelog
## 4.2.1
### Groups - Text
- New module: auras and cooldowns as lines of text. Write a line as [name] [cd], or put anything around them: [name] - [cd], NO WILD CHARGE [cd]. [stacks] shows stacks on an aura and charges on a cooldown
- Auras work like Groups - Bars: Spec / Class / Global lists, Aura Collections, Blizzard filters, order and sorting, Visibility. Every aura line can have its own text
- Cooldowns: a list of spells, a line each with its own text if you want. It shows while the spell is on cooldown (the GCD doesn't count), or keeps the line, or swaps to a Ready Text. A character only gets the spells it knows, so one group can serve every class
- Own colors for name, time, stacks and the text around them; left or right aligned
- Center align (lined up from a guess of the time and name width, so it doesn't wobble as the numbers tick) and Case: UPPERCASE for your text, cooldown names and one-spell auras. Names the game writes itself in combat stay as they are
### Character Setup (/tui alt)
- /tui alt is a new window, like the things for EUI installer: one row per addon with Install / Reinstall / Update, what this character uses, Profile... (what your characters should use) and Load. Load for This Character and Load Without CDM at the bottom, 1440p / 1080p up top (1080p once its strings are in)
- ElvUI and BigWigs switch per spec on their own on classes with a healer spec or Augmentation: FHT there, NHT on the rest (ElvUI's own spec profiles). Warriors and co just use NHT. Profile... picks which profiles that is: Tank & DPS and Healer + Aug, each its own (BuffReminders can do the same)
- New: BigWigs (NHT + FHT profiles with their Boss Debuff auras) and Blizzard's Cooldown Manager layouts (one per spec, per character) from the things for EUI pack. In the installer's Everything! and quick setups, on their own installer page and as buttons under Import / Install
- The login check is still a small popup, now with the profile names it loads and the Cooldown Manager layouts this character is missing: Everything, Everything but CDM (keep your own layouts) or Skip (asks again when something changes)
- Presets, Multi-Spec role profiles and the per-spec Edit Mode switching are gone with the old window
### Raid Frame Builder
- New module (Modules → Raid Frame Builder): sorts ElvUI's raid frames by your own name list. Listed names first, everyone else by name
- Open Builder shows your raid as frames laid out like your ElvUI raid frames: drag one onto another to move it, Sort by Role (click the role order to change it, Tank > DPS > Healer etc.), Stack Classes keeps the same class together in a role, Save writes it to the list
- Layouts are shared by all your characters and stay out of profiles; Enable is per profile, so it follows spec profiles
- Export/Import, also between thingsUI and things for EUI
- Without ElvUI's Raid-Wide Sorting the order applies inside each group. Changes wait until combat ends (someone joining mid-fight shows up after it)
### More
- Aura Icons and Aura Bars: Frame Level next to Frame Strata (default 10, as before). Lower it, or pick a lower strata, to let something like Buff Icons' stack text draw over an icon sitting on top of them
- Aura Icons > Show: While Active, Always (idle greyed) or Only When Missing. Missing shows the icon only while the aura is down (your poison, your DoT on the target...) and also works in a group, where it gets its own slot and the rest closes up. In combat it follows Blizzard's Cooldown Manager, so the aura has to be in its Buffs (or the spell in Essential/Utility); the options say so if it isn't. Desaturate shows it grey, and in a group it keeps its own Visibility rules (combat, target, zone...), in combat too
- CDM Spell Editor > Aura Icon On Top: put an Aura Icon over a cooldown (pick one or make a new one). It covers the cooldown while its aura is up (Garrote's DoT over Garrote), you see the cooldown again when it isn't. Optional Spell Cooldown On Top: that spell's own cooldown over the aura, with its own size, color and spot, and the icon's border right there too. Also under Aura Icons > Show In > On Top of a Cooldown
- CDM Spell Editor > Show: per spell Visibility rules (combat, solo/party/raid, zone, role, form, mounted...) take it out of the row, the rest closes up. Cooldown: Only On Cooldown / Only When Ready fades it instead and keeps its spot (the game hides cooldown timing in combat, so the row can't close up there)
- Stroke (a black line inside and outside the border) on Aura Icon borders, Groups - Icons borders and Aura Icons in groups. Styles carry it
- Visibility: new Only As Tank / Healer / DPS (your spec's role) on every Visibility tab: Groups, Aura Icons, Aura Bars and Timers
- Pandemic Indicator on Aura Icons and Groups entries gets the Glow While Active settings: Thickness (Border, Pulse, Pixel), Bordered Stroke (Border: black lines inside and outside the ring, Pixel: the dark band) and Particles, Line Length, Offset and Speed for Pixel Glow. Styles carry them
- Damage Meter (Mini Meter): Swap to Current on New Instance (entering a dungeon or starting a key) and Swap to Overall When M+ Ends, both under Windows
- Copy Group on Groups - Icons and Groups - Bars: duplicates the whole group (spells, auras, look, Visibility, position) and opens the copy. Aura Icons, Timers, trinkets and racials sent to a group stay with the original
- Aura Collections tabs are sorted by name (built-ins and your own together, renames follow)
- Tab Color for Groups - Icons, Groups - Bars, Bar Setups and Aura Collections, so your Defensives can always be red or whatever. A group's color also shows on its heading in the Aura Icons list
- Spell Editor → Buff Icons: glow per buff (While Shown, own color), like Cooldowns already had
- Spell Editor: Own Glow Style per spell or buff (style, lines, thickness, particles, scale, speed, offset), starting from Layout > Glow
- Pixel Glow on Aura Icons and Groups - Icons (and the Pixel Glow pandemic style) is rebuilt: the lines now travel the whole border and turn the corners smoothly instead of sliding along each edge and getting cut off at the corners. Same Lines, Line Length, Thickness, Speed and Offset settings
- Aura Icons and group auras: Pandemic Style (Border, Pulse Ring, Pixel Glow, Proc Glow, Marching Ants) and Pandemic Color for the pandemic indicator. Dropped the old "makeshift glows" note
- Damage Meter (Mini Meter): Reset on New Instance is Ask / Always / Never and asks by default (Reset or Keep) instead of wiping silently. Blizzard's meter can only wipe everything, so asking is the way to keep a run's data. A key start in the dungeon you just zoned into doesn't ask twice
- Spell Editor moved out of CDM into its own Modules entry, CDM Spell Editor (right under CDM), easier to find
- Spell Editor → Cooldowns: Aura Overlay per spell (Settings / Hide / Show), plus the aura swipe's direction and color per spell
- Spell Editor → Buff Icons: Invert Swipe per buff (Settings / Reversed / Normal) and its swipe color
- Spell Editor, both pages: Pandemic Glow per spell (Settings / Blizzard / Hidden / Custom Glow) with its own color and Own Glow Style
- New CDM → Layout → Aura Overlay: Hide Aura Overlay (moved from Settings, now says it covers all spells), Aura Swipe color and Reverse Swipe while a spell's aura runs, and Pandemic Glow as Blizzard / Hidden / Custom Glow with the same style, color and look options as Layout > Glow (Hide Pandemic Glow moved here too)
- Close Cooldown Settings yourself on a CDM page and it stays closed (no more popping back up) until you close the options
- Custom Icon for Aura Icons, Aura Bars and Spell Editor spells/buffs: a texture file ID or path, or Icon From Spell (ID or name). Follows them into groups, CDM rows and the previews
### Performance
- Glows on Aura Icons and Groups - Icons (and the pandemic styles) now only animate while their aura is actually showing: Blizzard's aura engine starts and stops them (12.1.5). Before, every pooled icon kept animating its glow in the background, even with no aura up
- Group preview icons stop their glow animations when you close the options (they kept running hidden for the rest of the session)
- Aura Icon spell lookups are cached in combat too (rebuilt after combat), and the role visibility rule only reacts to your own spec changes
- A tracked cast (Ironfur with Ticks, totem timers) no longer rebuilds every Aura Bar and Aura Icon: only the bars and icons that use it update, and ticks just move
### Fixes
- Aura Icons shown in a CDM row with their own border were 2 px too big after the border moved outside the icon
- CDM: an icon that overflows from Essential into Utility (or the other way) now takes that row's text settings instead of keeping its old row's
- CDM Spell Editor listed spells you set up on other classes and specs (Dream Breath on a monk). It only lists this spec's now; Spell ID still reaches the rest, their settings were never lost
- Aura Icons measure like the Cooldown Manager: Size and Zoom are the icon itself and its border sits outside it, the way ElvUI draws CDM icons. A 37 / 8% Aura Icon now matches a 37 / 8% CDM icon (it took 39 / 6% before). Inset still moves the border in. Your existing icons and styles keep their exact look: their Inset goes up by the border's width once (and old import strings get the same treatment)
- Trinkets in CDM no longer vanish for a moment after a loading screen
- Pixel Glow sat 1.5 px inside the right edge of icons (an old nudge from the previous glow); it now lines up on all four sides
- Aura Bars: Ticks work in combat again. They now sit on the bar itself instead of on the aura, which the game locks in combat
- Trinkets and items (CDM, Groups, Timers) no longer turn grey on the GCD; they still show its swipe, like Blizzard's own icons
- Bar Setup: a druid's classbar now keeps the CDM width while it's hidden (bear form), so going cat mid-combat no longer shows it at an old width until you leave combat
- Hide Aura Overlay put the spell's own art back over a Spell Editor Custom Icon
- Aura Icons/Bars: a buff whose CDM entry carries another ID than the aura keeps tracking. 12.1.5 broke Lifebloom set to 1227806 (the HoT on you is 33763); the spell you know by that name, tracked CDM buffs with the same name and buffs your layout moved into Buff Icons/Bars now count too
- New `/tui icons`: what each Aura Icon tracks and why it might not show
- Spell Editor (and the CDM spell picker) missed spells and buffs you dragged into Essential, Utility or Buffs from another category in Cooldown Settings, like Incarnation into Buffs. They read Blizzard's default categories; now your layout counts too
- ElvUI raid frames: the first frame of a new column (the 6th with 5 per column) could sit below the last row instead of at the top of its column after a login, reload or profile change. ElvUI sets the frames up one setting at a time and Blizzard's layout keeps the old spot; thingsUI now lays them out once more when ElvUI is done
- Groups - Icons: Show Caster Name works now (Blizzard shipped it under another name than on the PTR), with a new Class Color Caster toggle
- Hidden or unused aura groups in Groups, Aura Icons/Bars and Groups - Bars are switched fully off, so they do no work when your auras change
- Damage Meter (thingsUI): fixed a possible error opening a breakdown now that the game can hide who a row belongs to
### General
- Aura Icons in an Essential/Utility row or on their own show sample duration and stacks text in the options preview, like Groups do (row text, or their own with Override CDM Row Text)
- Groups - Icons preview uses an Aura Icon's own text when it has Override Custom Group Text ticked
- Standalone Timers got the Visibility tab, like Aura Icons and Aura Bars
- Visibility rules only watch what your rules ask about (no work on target or zone changes when no rule uses them)
- Aura Collections are built once per frame instead of once per lookup
- Removed unused code, and the old buff cache the CDM spell picker no longer reads

## 4.2.0
- Special Icons and Special Bars renamed to **Aura Icons** and **Aura Bars**, makes more sense or something maybe idno.
### CDM
- New: Aura Icons can sit inside the Essential or Utility row, like EUI's buffs in Essentials. Pick "Show In" → Essential/Utility Cooldowns and set "Position in Row", or use Add Aura Icon in CDM → Layout → Essential/Utility. They use the row's duration and stack text unless you tick Override CDM Row Text
- New: no more doubles in CDM. Spells, trinkets and racials you put in a Group, the spell your Charge Bar tracks, and auras you show as Aura Icons/Bars or group auras, are hidden from Blizzard's rows (toggle in CDM → Settings)
- New: CDM → Spell Editor, glow (on proc / always / never, own color), cooldown text and stacks/charges (hide, size, color, position) for one spell at a time. Aura Icons you put in a row show up in its list too, with a button to their settings. Two tabs: Cooldowns (Essential/Utility) and Buff Icons (duration text and stacks per buff, kept apart from the cooldown of the same spell). Buffs an Aura Icon or Aura Bar already shows are pink there, with a button to their settings. X/Y offsets work without picking a point too
- CDM options split up: Layout (Essential, Utility, Buff Icons, Glow), Spell Editor, Racials, Trinkets, Cluster Positioning, Settings
- New: on-use trinkets can go straight into Essential or Utility (CDM → Trinkets → Destination), no need to drag them in Blizzard's Cooldown Settings. Blizzard's own copy hides itself
- Trinkets: Hide Cooldown now hides the trinket everywhere, also from its Destination row or group
- Fixed CDM stack and charge text drawing bigger than the same font size elsewhere: ElvUI's skin made it skip the icon's (and the UI's) scale. It follows its icon again like the cooldown text, so those texts get smaller and you may want to raise their size
- The options preview (thingsUI CDM/Groups/Aura pages or Cooldown Settings open) shows sample cooldown and stack/charge text on CDM icons in their real style, Spell Editor tweaks included, and spells with an Always glow or an own glow color glow in it
- Racials put in a Group no longer show in CDM as well
- Auto-enable Cooldown Manager now turns the Cooldown Manager back on whenever it is off (it only did this once per character). With it unticked, thingsUI says in chat once why the CDM rows are empty
- CDM rows keep their thingsUI layout in Edit Mode instead of falling apart (while "Lock CDM viewers in /editmode" is on, the default)
- Cluster Positioning: unit frames keep the same gap whether Essential or Utility is the wider row (they moved closer going from 5 to 6 essentials)
### Aura Collections
- New module: Aura Collections, named aura lists for Groups - Icons and Groups - Bars. Edit a collection once and every group using it follows
- A collection is a spell list or Blizzard filters (Big Defensives, External Defensives, Important, HoTs and Shields, Crowd Control; tick several to show auras matching any of them), and can pull in the spells of an ElvUI filter. A Blizzard filter needs no list: the game decides what counts
- New built-in: Defensives (Blizzard's BIG_DEFENSIVE filter). The old Ready-Made Sets are collections now, and sets you already added follow them. Every collection can be renamed, built-ins too (clear the name to get the original back)
- Blizzard's Buff Icons copy of an aura a filter group shows hides too (with the duplicates toggle)
- Opening Blizzard's Cooldown Settings also previews Groups and Aura Icons/Bars, like their options pages do. Their options pages open Cooldown Settings too (and close it again if they opened it), like CDM and Buff Bars already did
### Visibility
- New Visibility tab on Aura Icons, Aura Bars and Groups - Bars, and a much bigger one on Groups - Icons: Show (Always / In Combat / Out of Combat / Never), Solo / Party / Raid, Only In (Open World, Dungeon, Raid, Delve, Scenario, Arena, Battleground, Housing), Only in Form (your class's forms, like Cat / Bear / Moonkin, or No Form) and Hide When (Mounted, No Target, No Enemy Target, Resting). Every rule you set has to match; ticked boxes in one list are alternatives
- Aura Icons and Bars inside a group follow the group's rules; the options pages keep showing everything as a preview
### Aura Icons & Bars
- New: Aura Type on Aura Icons, Buff or Debuff (both, as before) / Buff (on you) / Debuff (on target). Fixes an icon like Fiery Brand showing twice in a group: it is a debuff on the target and an aura on you
- Groups: Add Aura Icon / Add Aura Bar is one list now. A spell that already has an icon or bar moves into the group, any other spell gets a new one. The list says where each one sits today (group, Essential/Utility, standalone)
- Aura Icons: the side list has its own Essential Cooldowns / Utility Cooldowns headings
- Aura Bars: Copy Bar, like Copy Icon on Aura Icons
- Reverse Fill for Aura Bars, Groups - Bars and Buff Bars (totem ticks follow it)
- Fixed Edit Bar in Groups - Bars, and right-clicking an Aura Bar/Icon mover, opening the module page instead of that bar or icon
- Groups - Icons with a sorted Aura Order can pick one Style for all their auras (Order tab). Sorting puts every aura in one shared list, so per-entry styles can't apply there; their style selects grey out instead of silently doing nothing
- Aura Bars and Groups - Bars: color for name, duration and stacks text
- Groups - Bars: stacks got their own outline, like Aura Bars
### Groups
- Fixed Concentrated Silvermoon Health Potion and silver Alluring Nostrum getting the Fleeting border (they have no Fleeting version)
- Potion of Zealotry (and its Fleeting versions) is a known potion now: ranks group together and Common Items lists it
### Movers & frames
- Picking a new Anchor Frame anywhere (Aura Bars/Icons, Groups, Buff Bars, CDM rows, Charge Bar, Timers, Bar Setup, focus frame) resets the points to CENTER/CENTER and the offsets to 0, instead of keeping numbers meant for the old frame
- Fixed nudging thingsUI movers (mouse wheel / nudge window): Essentials jumped, locked movers could be nudged, and Aura Bars/Icons, Groups and Timers saved a weird anchor
- Fixed a new Groups - Icons group (or a standalone Timer) snapping back to the middle in /emove until a reload, after switching profiles: its mover still belonged to the other profile's group with the same number. Mover names follow group renames too
- New: Group Frame Anchor (ElvUI QoL), keeps party/raid frames on one corner of their mover so they grow away from it, also near the screen edge
- New: Action Bar 2 and 13 (ElvUI QoL). Bar 13 is the bar Blizzard and EllesmereUI call Action Bar 6, so coming from EUI your spells sit there. Preview both, copy one onto the other (the source stays), move keybinds over. Optional: keybinds follow the bar your profile shows, and the shown bar fills itself on each spec when it's empty
### Installer
- Turns on Chat → Voice Chat → Hide Voice Buttons
- Quick setups and Alt Profiles also set your healer/dps spec profiles (FHT/NHT) from the role presets
### Commands
- Everything lives under /tui now: `/tui` opens the options, `/tui install` the installer, `/tui alt` the alt profile setup, `/tui prof` the profiler.
### Performance
- Performance: Hide Aura Overlay runs one full pass per cooldown update instead of three (plus the nested ones it triggered on itself)
- Performance: Buff Bars only re-lay bars that actually changed, and stop re-setting strata and anchor on every aura update
- Performance: CDM layout passes no longer re-anchor proxies that are already in place (that woke cluster positioning every time)
- CDM modules share one Blizzard hook per viewer instead of five separate ones on Essential
- CDM text follows ElvUI's Cooldown Manager text options again on newer ElvUI versions
- New /tui prof: thingsUI load time, plus thingsUI, ElvUI and ElvUI_Libraries CPU from Blizzard's addon profiler
### Class Stuff
- DH: Charged Bars spell swap (Veng: IS -> Fracture, Havoc: IA -> Fel Rush)
- Plenty of buffs and stuff moved around
- Not halfway done with class presets, soontm.

## 4.1.8
- Fixed special icons breaking when secret auras (Lifebloom++) blocked styling
- Fixed grouped special icons staying hidden after visiting options
- Fixed Essential->Utility overflow icon vanishing after loading screens
- Installer: Everything!/quick setup errors no longer strand you on page 1
- Full Install now includes ElvUI Global + Private settings
- Quick setups import the Alt Profile preset and set it default
- New standalone Private / Global / Alt Presets import buttons
- Updated bundled ElvUI private/global and alt preset strings
- Removed Buddies presets

## 4.1.7
- Performance: Kinda substantial buff, reined in some combat and bag update stuff that were off the chainhooks
- Alt setup should load profiles automatically now, and only show one popup for platynator and private profile

## 4.1.6
- Fixed player power bar detached on FHT import
- Export moved to it's own tab
- Config layout stuff
- Totem icons should show style glow and timer preview
- Timers can also use styles
- NHT plugin update: Added more classes to groups
- Alt Setup: the preset popup now warns about deleted/renamed preset profiles and notes when Platynator nameplates are in use; popups are movable, centered and outlined
- Installer: Everything! as a quick setup - imports.. everything?
- New ElvUI profiles created from scratch offer to copy from your preset profile (or opt out)
- Special Bars: new "Show In" dropdown, Bar Setup, Standalone, Groups
- Add Special Bar/Icon and "New Special Bar/Icon (from spell)" now work when editing another spec
- Special Icons/Bars: the "Copy from..." popup got a class dropdown, no longer clips its bottom row

## 4.1.5
- Skinned mini meter: 
- - always show player
- - don't sometime stop when player die
- - custom color bars when not class colored
- - tooltips
- - class colored names option
- Added "Hide Pandemic Glow" toggle in CDM tab.
- Moved CDM toggles to its own tab.

## 4.1.4
- NB: Reworked pixels alignment and some sizing, so some things like icon groups size will be off and position to their anchor may be 1-2px off without an update\adjustment.
- Fixed export string
- Bar heights should no longer bleed from Global into other bar setups
- Alt profile presets can now be set on role so you only need one. A popup reminder show up when a characters profile differs from the preset.
- Added quick setup and elvui private & global to setup.
- Picking Details! now imports the profile as well, if missing.
- Racials respect CDM placement when assigned to be there
- Timers show in group preview/test mode if in a group
- Styled buffs now get the style's border and bordered stroke
- Fixed Match CDM Anchor Icons being weird with bordered stroke


## 4.1.3
- New profile presets with new positions

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