# ElvUI_thingsUI

An ElvUI plugin that provides additional customization options for the [Blizzard Cooldown Manager (BCDM)](https://www.curseforge.com/wow/addons/bettercooldownmanager) addon.

![Version](https://img.shields.io/badge/version-1.10.0-blue)
![WoW Version](https://img.shields.io/badge/WoW-The%20War%20Within-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 📊 Buff Bar Skinning
Skin BCDM's BuffBarCooldownViewer with ElvUI's visual style:
- Custom status bar textures (uses ElvUI's shared media)
- Class color or custom color options
- Configurable dimensions, spacing, and fonts
- Icon visibility toggle
- Growth direction (up/down)
- **Anchor to any frame** - Attach buff bars to ElvUF_Player, EssentialCooldownViewer, or any named frame

### 🎯 Dynamic Cluster Positioning
Automatically position ElvUI unit frames around BCDM's Essential Cooldown Viewer:
- **ElvUF_Player** anchors to the left of Essential icons
- **ElvUF_Target** anchors to the right of Essential icons
- **ElvUF_TargetTarget** anchors to Target frame
- **ElvUF_Target_CastBar** anchors below Target frame with X/Y offset
- Frames dynamically adjust as cooldown icons appear/disappear
- Utility overflow support - frames move when utility icons exceed essential count
- **Profile-aware** - Properly restores frames when switching to profiles with cluster disabled

### 🔗 BCDM Frame Anchoring
Anchor BCDM's custom bars to ElvUI frames:
- Supports: CustomCooldownViewer, AdditionalCustomCooldownViewer, CustomItemBar, TrinketBar, CustomItemSpellBar
- Anchor targets: ElvUF_Player, ElvUF_Target, EssentialCooldownViewer, UtilityCooldownViewer, UIParent
- Full anchor point configuration (TOP, BOTTOM, LEFT, RIGHT, CENTER, corners)
- X/Y offset fine-tuning

### 🔄 Vertical Buff Icons
Toggle vertical growth for BCDM's BuffIconCooldownViewer.

## Installation

1. Download the latest release
2. Extract `ElvUI_thingsUI` folder to your `Interface/AddOns` directory
3. Ensure you have both **ElvUI** and **BetterCooldownManager** installed
4. Restart WoW or `/reload`

## Configuration

Access settings via:
- **ElvUI Config** → **Plugins** → **thingsUI**

Or type `/elvui` and navigate to the thingsUI section.

### Tabs

| Tab | Description |
|-----|-------------|
| **Buff Icons** | Toggle vertical buff icon growth |
| **Buff Bars** | Skin and anchor BCDM buff bars |
| **Cluster Positioning** | Dynamic unit frame positioning around Essential cooldowns |
| **Anchor BCDM Stuff** | Anchor BCDM bars to ElvUI frames |

## Example Setup: Cluster Positioning

For a centered cooldown cluster with unit frames on either side:

1. Position BCDM's **EssentialCooldownViewer** in the center of your screen
2. Enable **Cluster Positioning** in thingsUI
3. Enable positioning for Player, Target, and TargetTarget frames
4. Adjust gaps to your preference
5. Unit frames will now dynamically reposition based on visible cooldown icons!

## Example Setup: Buff Bar Anchoring

To have buff bars grow upward from your player frame:

1. Enable **Buff Bar Skinning**
2. Set **Growth Direction** to "Up"
3. Enable **Anchoring**
4. Set **Anchor Frame** to `ElvUF_Player`
5. Set **Point** to `BOTTOM`
6. Set **Relative Point** to `TOP`
7. Adjust **Y Offset** as needed (e.g., 5)

## Requirements

- [ElvUI](https://www.tukui.org/download.php?ui=elvui)
- [BetterCooldownManager](https://www.curseforge.com/wow/addons/bettercooldownmanager)

## Troubleshooting

**Profile switching issues?**
- The addon automatically restores frames when switching to profiles with cluster disabled
- If issues persist, `/reload` will reset everything

**Buff bars not skinning?**
- Make sure there are auras to skin in CDM.
- Check that "Enable Buff Bar Skinning" is checked in thingsUI

## Support

Found a bug or have a feature request? Open an issue on GitHub!

## License

MIT License - Feel free to modify and distribute.

## Credits

- **useless_human** - Wrote things into ai website
- **Claude** - Did all the work
- **ElvUI Team** - For continuing the biggest QoL in WoW UI history imo. Try to do things, search and read the fucking pins. Give them money.
- **BetterCooldownManager - Unhaulted** - For saving our asses. Should also give him money.
