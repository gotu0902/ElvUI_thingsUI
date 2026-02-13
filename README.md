# ElvUI_thingsUI

![Version](https://img.shields.io/badge/version-2.1.0-blue)

### Dynamic Cluster Positioning
Automatically position ElvUI unit frames around BCDM's Essential Cooldown Viewer:
- **ElvUF_Player** anchors to the left of Essential icons
- **ElvUF_Target** anchors to the right of Essential icons
- **ElvUF_TargetTarget** anchors to Target frame
- **ElvUF_Target_CastBar** anchors below Target frame with X/Y offset
- Frames dynamically adjust as cooldown icons appear/disappear
- **Profile-aware** - Properly restores frames when switching to profiles with cluster disabled

**When utility icons exceed essential icons, frames automatically move outward:**
- **Utility Threshold** - How many extra utility icons trigger movement (default: 3)
- **Overflow Offset** - Pixels to move each frame when triggered (default: 25)

Example: 6 Essential + 9 Utility = +3 extra, frames move outward

### Buff Bar Skinning & Anchoring

- Custom status bar textures (uses ElvUI's shared media)
- Class color or custom color options
- Configurable dimensions, spacing, and fonts
- Icon visibility toggle
- Growth direction (up/down)

### Special Bars
- Move a tracked buff bar to somewhere else on the screen

Attach buff bars or special bars to ElvUF_Player, EssentialCooldownViewer +++, or any named frame. Go /framestack to find it o7

### Vertical Buff Icons
Toggle vertical growth for BCDM's BuffIconCooldownViewer, used for FHT.

## Installation

1. Download the latest release
2. Extract `ElvUI_thingsUI` folder to your `Interface/AddOns` directory
3. Ensure you have both **ElvUI** and **BetterCooldownManager** installed
4. Restart WoW or `/reload`

Access settings via:
- **/ec** → **Plugins** → **thingsUI**

## Requirements

- [ElvUI](https://www.tukui.org/download.php?ui=elvui)
- [BetterCooldownManager](https://www.curseforge.com/wow/addons/bettercooldownmanager)

## License

MIT License - Feel free to modify and distribute.

## Credits

- **human** - did the basics
- **Anthropic Claude** - vibe coded the base that got it started
- **D.G** - big help and tutoring - optimized and fixed alot of vibes
- **ElvUI Team** - #1, big w
- **Unhalted** - For being the goat 🐐
