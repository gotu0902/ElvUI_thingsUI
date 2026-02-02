# ElvUI_thingsUI

An ElvUI plugin that provides additional customization options for the [Blizzard Cooldown Manager (BCDM)](https://www.curseforge.com/wow/addons/bettercooldownmanager) addon.

![Version](https://img.shields.io/badge/version-1.11.3-blue)

### Dynamic Cluster Positioning
Automatically position ElvUI unit frames around BCDM's Essential Cooldown Viewer:
- **ElvUF_Player** anchors to the left of Essential icons
- **ElvUF_Target** anchors to the right of Essential icons
- **ElvUF_TargetTarget** anchors to Target frame
- **ElvUF_Target_CastBar** anchors below Target frame with X/Y offset
- Frames dynamically adjust as cooldown icons appear/disappear
- **Profile-aware** - Properly restores frames when switching to profiles with cluster disabled

### Utility Overflow Support
When utility icons exceed essential icons, frames automatically move outward:
- **Utility Threshold** - How many extra utility icons trigger movement (default: 3)
- **Overflow Offset** - Pixels to move each frame when triggered (default: 25)

Example: 6 Essential + 9 Utility = +3 extra, frames move outward

### Buff Bar Skinning & Anchoring
Skin BCDM's BuffBarCooldownViewer with ElvUI's visual style:
- Custom status bar textures (uses ElvUI's shared media)
- Class color or custom color options
- Configurable dimensions, spacing, and fonts
- Icon visibility toggle
- Growth direction (up/down)
- **Anchor to any frame** - Attach buff bars to ElvUF_Player, EssentialCooldownViewer, or any named frame. Go /framestack to find it o7

If your Edit Mode width is vastly different than this width it'll sometimes look bigger for like a second.
Try to get Edit Mode width of the bars as close as you can to make this less noticeable.

### BCDM Frame Anchoring
Anchor BCDM's custom bars to ElvUI frames:
- Supports: CustomCooldownViewer, AdditionalCustomCooldownViewer, CustomItemBar, TrinketBar, CustomItemSpellBar
- Anchor targets: ElvUF_Player, ElvUF_Target, UIParent, or **Custom Frame** (type any frame name)
- Full anchor point configuration (TOP, BOTTOM, LEFT, RIGHT, CENTER, corners)
- X/Y offset fine-tuning

### Vertical Buff Icons
Toggle vertical growth for BCDM's BuffIconCooldownViewer.

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

- **human** - made prompts, did 1%
- **Anthropic Claude** - vibe coded this stuff, did 99%
- **ElvUI Team** - #1, big w
- **Unhalted** - For being the goat 🐐
