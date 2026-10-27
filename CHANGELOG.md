# Changelog
## 4.2.1
### Groups - Text
- New module: auras and cooldowns as lines of text. Write a line as [name] [cd], or put anything around them: [name] - [cd], NO WILD CHARGE [cd]. [stacks] shows stacks on an aura and charges on a cooldown
- Auras work like Groups - Bars: Spec / Class / Global lists, Aura Collections, Blizzard filters, order and sorting, Visibility. Every aura line can have its own text
- Cooldowns: spells in the Spec, Class and Global tabs, picked like the spell cooldowns in Groups - Icons, a line each with its own text if you want. A line shows while the spell is on cooldown (the GCD doesn't count, a charge spell only once every charge is spent) and goes away the moment its countdown ends, or keeps the line, or swaps to a Ready Text. [cd] shows on short cooldowns too (Stealth's 2 s). A hidden line leaves the stack and the rest closes up
- A character gets the lines of its spec, its class and Global, only for spells it knows, so one group can serve every class (Global lists this character's spells, Show Other Classes for the rest). Max Lines counts the cooldown lines first, the auras get what's left
- Own colors for name, time, stacks and the text around them. Left, right or center aligned (the default; lined up so it doesn't wobble as the numbers tick). Case: UPPERCASE for your text, cooldown names and one-spell auras; names the game writes itself in combat stay as they are
### Character Setup (/tui alt)
- /tui alt is a new window, like the things for EUI installer: one row per addon with Install / Reinstall / Update, what this character uses, Profile... (what your characters should use) and Load. Load for This Character and Load Without CDM at the bottom, 1440p / 1080p up top (1080p once its strings are in)
- ElvUI and BigWigs switch per spec on their own on classes with a healer spec or Augmentation: FHT there, NHT on the rest (ElvUI's own spec profiles). Warriors and co just use NHT. Profile... picks which profiles that is: Tank & DPS and Healer + Aug, each its own (BuffReminders can do the same)
- New: BigWigs (NHT + FHT profiles with their Boss Debuff auras) and Blizzard's Cooldown Manager layouts (one per spec, per character) from the things for EUI pack. In the installer's Everything! and quick setups, on their own installer page and as buttons under Import / Install (BigWigs NHT and FHT each in their own section there)
- The login check is still a small popup, now with the profile names it loads and the Cooldown Manager layouts this character is missing: Everything, Everything but CDM (keep your own layouts) or Skip (asks again when something changes). It no longer blocks your keybinds while it shows
- Setup updates: a profile set up from the NHT or FHT pack is told at login when a new version changes the pack (groups, styles, Aura Icons per spec, modules). Review opens the import picker with only what changed: new things and things you never touched are ticked, things you changed yourself are not. Not Now asks again next login, Skip This Update leaves everything as it is, /tui updates checks by hand
- Presets, Multi-Spec role profiles and the per-spec Edit Mode switching are gone with the old window
### Raid Frame Builder
- New module (Modules → Raid Frame Builder): sorts ElvUI's raid frames by your own name list. Listed names first, everyone else by name
- Open Builder (or /tui rf) shows your raid as frames laid out like your ElvUI raid frames: drag one onto another to move it, Sort by Role (pick the role order from the menu), Stack Classes keeps the same class together in a role, Save writes it to the list
- Layouts are shared by all your characters and stay out of profiles; Enable is per profile, so it follows spec profiles
- Export/Import, also between thingsUI and things for EUI
- Without ElvUI's Raid-Wide Sorting the order applies inside each group. Changes wait until combat ends (someone joining mid-fight shows up after it). Nobody is ever left out: while names load, or when nobody from your list is in the raid (an alt in a pug), ElvUI's normal group order shows everyone
### Profile Sync
- New Sync tab: tick the profiles that should stay the same, then pick modules in the list: All, or Some (single groups, Aura Icons per spec, styles, or parts like Essential and Spell Editor). Position (X/Y) and size (W/H) stay per profile unless you tick them, and only show where a module keeps them itself
- The profile you're on hands its settings on when you switch profile, log out or click Sync Now. Each module says whether the others match, and Take It From... pulls a module from another profile first
- Groups are matched by name and you're asked what to do with differences; Aura Icons and Aura Bars follow their group
- Aura Collections sync collection by collection (built-in ones with your edits and tab colors, your own by name), and groups keep their links to them
- A profile that gets reset, imported or copied from outside the sync leaves it, so nothing spreads by accident
- The Modules list shows a green S on synced modules. Exports carry your sync setup, and the installer has a Profile Sync page
- Copy between profiles: Import - Export - Install > Profiles (and a thingsUI tab in ElvUI's Module Copy) copies whole modules or single items from or to another profile
- Groups - Bars and Groups - Text are separate in exports, copies and sync; Damage Meter and Minimap are part of exports now
### Borders & Glows
- Groups - Icons border: a thin frame inside the icon, as in WeakAuras, so the icon keeps its size (Inset 0 = on the edge, a negative Inset pushes it out and the group makes room for it). Spacing shows the real gap: -1 = one shared border line, 0 = side by side, 1 = a 1 px gap. It showed 2 less than it used; your groups look the same, only the number changes
- The group's border is the border of everything in it: cooldowns, items and auras, also auras with a Style (the style still gives their glow). Only an Aura Icon with Border > Override Custom Group Border on uses its own border settings, and then Show Border off means no border at all. It's off for every icon until you turn it on, and its settings stay hidden while it's off, like the Text tab while the group's text is used. Both overrides can be set on a Style too. A sorted group gives its auras one look and says so instead of greying the style boxes out. The preview draws the same borders as live
- Stroke (a black line inside and outside the border) on Aura Icon borders, Groups - Icons borders and Aura Icons in groups. Styles carry it, unticked too, and a setting a style was saved without counts as its default, so applying or updating a style sets everything (Stroke and the pandemic's Bordered Stroke didn't follow a style before)
- Aura Icons measure like the Cooldown Manager: Size and Zoom are the icon itself and its border sits outside it, so a 37 / 8% Aura Icon matches a 37 / 8% CDM icon (it took 39 / 6% before). In a CDM row or on top of a cooldown the picture covers exactly the CDM cell. Your existing icons and styles keep their look: their Inset goes up by the border's width once (old import strings too)
- Pandemic Indicator on Aura Icons and Groups entries: Pandemic Style (Border, Pulse Ring, Pixel Glow, Proc Glow, Marching Ants), Pandemic Color and the Glow While Active settings: Thickness, Bordered Stroke, and Particles, Line Length, Offset and Speed for Pixel Glow. Styles carry them. The Border style sits where the icon's border is and grows inward over the icon. Preview Pandemic (Aura Icons, their Styles and Groups entries) plays it on the icon for 5 seconds
- Pixel Glow on Aura Icons and Groups - Icons (and the Pixel Glow pandemic style) is rebuilt: the lines travel the whole border and turn the corners smoothly instead of getting cut off at them, lined up on all four sides. Same settings
### CDM Spell Editor
- Moved out of CDM into its own Modules entry, right under CDM. It lists only this spec's spells (Dream Breath showed up on a monk; Spell ID still reaches the rest, their settings were never lost), the picked spell no longer shows twice, and spells and buffs you dragged into another category in Cooldown Settings (Incarnation into Buffs) are listed too, in the CDM spell picker as well
- Show: per spell Visibility rules (combat, solo/party/raid, zone, role, form, mounted...) take it out of the row, the rest closes up. Cooldown: Only On Cooldown / Only When Ready does the same (the GCD doesn't count, and the icon flips the moment its cooldown runs out). Both follow the spell into Groups - Icons too
- Aura Icon On Top: put an Aura Icon over a cooldown. It covers the cooldown while its aura is up (Garrote's DoT over Garrote), you see the cooldown again when it isn't. Its list works like Aura Icons': free auras in green get a new icon, ones in use show where they sit and move here. Optional Spell Cooldown On Top: the spell's own cooldown over the aura, with its own size, color and spot. Also under Aura Icons > Show In > On Top of a Cooldown, with a Cooldown dropdown of what the CDM shows (or a Spell ID / name). Its text is the text of the frame it covers, Spell Editor text included, and without a border of its own it keeps the frame's 1px border in sight. The Spell Editor list marks these (Aura On Top), the Aura Icons list keeps them under their own On Top heading
- Cooldowns: Aura Overlay per spell (Settings / Hide / Show) with the aura swipe's direction and color. Buff Icons: glow per buff (While Shown, own color) and Invert Swipe (Settings / Reversed / Normal) with its swipe color. Both pages: Pandemic Glow per spell (Settings / Blizzard / Hidden / Custom Glow) with its own color, and Own Glow Style per spell or buff (style, lines, thickness, particles, scale, speed, offset), starting from Layout > Glow
### More
- Spell lists in the options show the spell's tooltip when you hover an entry (Add Aura Icon / Buff / Aura Bar / Spell CD / Cooldown / Racial, the Aura Icon and Aura Bar spell pickers, the Spell Editor and the Charge Bar)
- Aura Icons / Aura Bars: no more three empty Icon 1-3 / Bar 1-3 on every spec. A spec can have none, empty ones stay out of the list and a new icon or bar takes their place first
- Aura Icons > Aura Type says Auto (was "Buff or Debuff"): leave it unless a spell is both a buff and a debuff, like Fiery Brand
- Aura Icons > Show: While Active, Always (idle greyed) or Only When Missing. Missing shows the icon only while the aura is down (your poison, your DoT on the target...) and also works in a group, where it gets its own slot and the rest closes up. In combat it follows Blizzard's Cooldown Manager, so the aura has to be in its Buffs (or the spell in Essential/Utility); the options say so if it isn't. Desaturate shows it grey, and in a group it keeps its own Visibility rules, in combat too
- Charge Bar: Fill Direction (Global Layout, or per spec in Layout Overrides): Left to Right, Right to Left, Toward the Middle (charges take turns from both ends) or From the Middle (outwards both ways). The recharge always shows on the charge that is coming back. A spell down to one charge (its second-charge talent not taken) no longer leaves an empty bar: Tracked Spell > With One Charge picks Single Bar or Show in Cooldown Manager. The spell list shows every spell in the spec's Cooldown Manager, charge spells first, so one can be set up before its charge talent or level. Hide Duplicates also catches the CDM copy of a talent's other form of the spell
- Aura Icons and Aura Bars: Frame Level next to Frame Strata (default 10, as before). Lower it, or pick a lower strata, to let something like Buff Icons' stack text draw over an icon sitting on top of them. Groups - Icons, Groups - Bars and Groups - Text get Frame Strata and Frame Level too (Layout & Position > Position); an Aura Icon in a group follows its group's
- Visibility: Only As Tank / Healer / DPS (your spec's role) on every Visibility tab, and standalone Timers got the Visibility tab
- Custom Icon for Aura Icons, Aura Bars and Spell Editor spells/buffs: a texture file ID or path, or Icon From Spell (ID or name). Follows them into groups, CDM rows and the previews
- Copy Group on Groups - Icons and Groups - Bars: duplicates the whole group (spells, auras, look, Visibility, position) and opens the copy. Aura Icons, Timers, trinkets and racials sent to a group stay with the original
- Tab Color for Groups - Icons, Groups - Bars, Bar Setups and Aura Collections, so your Defensives can always be red or whatever. A group's color also shows on its heading in the Aura Icons list. Aura Collections tabs are sorted by name
- New CDM → Layout → Aura Overlay: Hide Aura Overlay (moved from Settings, now says it covers all spells), Aura Swipe color and Reverse Swipe while a spell's aura runs, and Pandemic Glow as Blizzard / Hidden / Custom Glow with the same style, color and look options as Layout > Glow (Hide Pandemic Glow moved here too)
- CDM: charge spells (Swiftmend, 2 charges) show the full swipe while a charge recharges, like EUI. Blizzard only draws a thin edge until the last charge is gone. CDM > Settings turns it off, Spell Editor > Recharge Swipe per spell (Show / Edge Only), and Edge Only holds with Hide Aura Overlay too
- Close Cooldown Settings yourself on a CDM page and it stays closed (no more popping back up) until you close the options
- Options previews: Aura Icons in a row or on their own show sample duration and stacks text like Groups do, and the Groups - Icons preview uses an Aura Icon's own text when it has Override Custom Group Text ticked
- Mini Meter: your own row works in combat, like Details and EUI: its tooltip, spell list (left-click) and popout (middle-click) show your spells live, and Always Show Player keeps you in view (other players' rows still open after combat). Reset on New Instance is Ask / Always / Never and asks by default (Reset or Keep) instead of wiping silently: Blizzard's meter can only wipe everything, so asking is the way to keep a run's data. New under Windows: Swap to Current on New Instance and Swap to Overall When M+ Ends. Fixed a possible error opening a breakdown
- New commands: /tui icons (what each Aura Icon tracks and why it might not show), /tui aura <spellID> (what an Aura Icon for that spell tracks and why), /tui prof all (every loaded addon by frames over 5 ms and peak, to find what makes something stutter)
- Fixes and QoL: the old Setup things Settings button is gone. Import - Export - Install > Account Settings > ElvUI Private imports the full private settings
- Bar Setup: a spec ticked in two setups gets a red ! on the tab, in the spec picker and in Active on Specs, which also says which setup wins (the one further left)
- Aura Bars and Groups - Bars: Fill By Stacks fills the bar by the aura's stacks instead of its duration, split into one piece per stack (Max Stacks, Gap Between Stacks), like ElvUI's class bar for Tip of the Spear. In Bar Setup or over a placeholder the pieces stay marked while the aura is down. Per Aura Bar, or per buff in a Groups - Bars group (Manual order)
- Aura Bars: the list is split under Standalone, Bar Setup (in stack order) and group headings, like Aura Icons. A bar in Bar Setup gets Move Up / Move Down: it trades places with its neighbour in the stack for this spec only, so your other specs keep their order
- Aura Bars: a bar whose buff you talented out of leaves Bar Setup and the stack closes up, instead of holding an empty slot. Size > Fill In For (Not Talented) lets another Bar Setup bar take over that bar's height while it's gone, or a Specific Height of its own
### Performance
- Going in and out of stealth (and other form changes that make the Cooldown Manager rebuild its rows): icons thingsUI hides from the rows no longer flash back in for a moment, and the bar stack under the cooldowns (~18 ms with its unit frame bars, twice per swap), the Aura Bars and the Groups - Bars that follow the row width no longer rebuild. New icons get their hide check before the frame is drawn, and the stack only rebuilds when the width really changed
- Glows on Aura Icons and Groups - Icons (and the pandemic styles) only animate while their aura is actually showing: Blizzard's aura engine starts and stops them (12.1.5). Before, every pooled icon kept animating in the background, and group preview glows kept running after you closed the options
- Hidden or unused aura groups in Groups, Aura Icons/Bars and Groups - Bars are switched fully off, so they do no work when your auras change
- Aura Icon spell lookups are cached in combat too (rebuilt after combat), and the role visibility rule only reacts to your own spec changes
- A tracked cast (Ironfur with Ticks, totem timers) no longer rebuilds every Aura Bar and Aura Icon: only the bars and icons that use it update, and ticks just move
- Visibility rules only watch what your rules ask about (no work on target or zone changes when no rule uses them), and Aura Collections are built once per frame instead of once per lookup
- Removed unused code, and the old buff cache the CDM spell picker no longer reads
- Spec swaps: thingsUI no longer rebuilds Bar Setup, CDM text, Groups and racials when someone else in your group changes spec (the game sends that event for group members too)
- Spec swaps: Bar Setup restacks three times instead of five and no longer rebuilds ElvUI's player frame and cast bar on each pass. With Bar Setup off it leaves the player frame alone unless it moved bars this session
- Aura Icons and Aura Bars read the Cooldown Manager's buff list once per update instead of once per icon (a spec swap read it again for every Aura Icon and Bar)
- Profile switches (FHT / NHT per spec) rebuild thingsUI's option pages when you next open the options, not during the switch
- New /tui prof spec: type it, swap spec, and 8 s later it lists every addon's CPU time during the swap, the longest frames and, on a profile switch, thingsUI's share of it
### Fixes
- Aura Icons > Only When Missing found debuffs like Rend in the Cooldown Manager: their entry is the ability (Rend) with the debuff linked to it, and only the ability was matched, so the icon counted as not tracked in combat (and the options said so)
- Aura Icons and Aura Bars track what the Cooldown Manager tracks for that spell: the entry that lists the aura, not every entry on the same spell (a Violent Outburst icon showed Seeing Red too). A buff whose CDM entry carries another ID than the aura keeps tracking: 12.1.5 broke Lifebloom set to 1227806 (the HoT on you is 33763); the spell you know by that name, tracked CDM buffs with the same name and buffs your layout moved into Buff Icons/Bars count too
- Stack and charge numbers stay on top of glows: the CDM's proc / Spell Editor glow drew over them, and the pandemic glow did on Aura Icons and in groups
- Previews (options open) follow the role rule, so a DPS and a Tank version of a group in the same spot are no longer drawn on top of each other; the group you have open in the options always shows. Groups - Icons / Bars / Text and Aura Icons / Bars
- Dragging a thingsUI mover (/emove) keeps the element's anchor frame and points (CENTER stays CENTER) and only changes X/Y by how far you dragged, like the nudge arrows, instead of switching to whatever corner ElvUI picked. Groups, Aura Icons and Bars, Utility Cooldowns and Timers
- A new Groups - Bars group starts in the middle of the screen (0, 0) like Groups - Icons, instead of down by the bars
- Aura Icons with Border off had the plain 1px edge while idle (greyed out in a CDM row) but lost it as soon as the aura came up; they keep it now
- CDM: an icon that overflows from Essential into Utility (or the other way) now takes that row's text settings instead of keeping its old row's
- Trinkets in CDM no longer vanish for a moment after a loading screen
- Aura Bars: Ticks work in combat again. They now sit on the bar itself instead of on the aura, which the game locks in combat
- Trinkets and items (CDM, Groups, Timers) no longer turn grey on the GCD; they still show its swipe, like Blizzard's own icons
- Bar Setup: a druid's classbar now keeps the CDM width while it's hidden (bear form), so going cat mid-combat no longer shows it at an old width until you leave combat
- Hide Aura Overlay put the spell's own art back over a Spell Editor Custom Icon
- ElvUI raid frames: the first frame of a new column (the 6th with 5 per column) could sit below the last row instead of at the top of its column after a login, reload or profile change. ElvUI sets the frames up one setting at a time and Blizzard's layout keeps the old spot; thingsUI now lays them out once more when ElvUI is done
- Groups - Icons: Show Caster Name works now (Blizzard shipped it under another name than on the PTR), with a new Class Color Caster toggle
- MinimapButtonButton: Show Only On Mouseover now shows the bar the moment you hover any of its buttons and hides it when you leave; it could lag behind or stay up when you came in or left over a button

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