# ElvUI_thingsUI

![Version](https://img.shields.io/badge/version-2.2.3-green)

### BCDM + ElvUI
- Anchor BCDM frames to ElvUI Player\Target UFs
- Frames dynamically adjust as cooldown icons appear/disappear
- Change stuff to your liking
- Anchor BCDM Castbar to Secondary Power Bar when present, otherwise default to Power Bar

**"When utility icons gets longer than essential icons, the frames move!?" Yes.**
- **Utility Threshold** = How many extra utility icons trigger movement
- **Overflow Offset** = Pixels(ish) to move each frame when triggered 
Example: 6 Essential + 9 Utility = +3 extra, frames move. Figure it out

### Buff Bar Skinning & Anchoring

- Skins buff bars, caches the position.
- Grow up or down, change font, texture, the uzh

### Special Bars
- Move a tracked buff bar to somewhere else on the screen, like go to /CDM -> put say "Shield Block" on a Tracked Bar -> Enable a Special Bar and type in the same spell -> do w\e tf you want.

Anchor to w\e frame, inherit width may be a lil buggy with some other AddOns that refresh on events like BCDM_CastBar.

### Vertical Buff Icons
Toggle vertical growth for BCDM's BuffIconCooldownViewer, used for FHT.
Pretty much all it does, and all it's supposed to do.

## Installation

1. Download. Use the wago app preferably..
2. Extract `ElvUI_thingsUI` folder to your `Interface/AddOns` directory
3. Ensure you have both **ElvUI** and **BetterCooldownManager** installed
4. /rl

Access settings via:
- **/ec** → **Plugins** → **thingsUI**

## License

MIT License - Feel free to modify and distribute.
Though if you make it better, I'd like to know and learn from it.

## Credits

- **human** - did the basics
- **Anthropic Claude** - vibe coded the base that got it started
- **Dan G** - big help and tutoring - optimized and fixed alot of vibes
- **ElvUI Team** - #1, big w
- **Unhalted** - For being the goat 🐐
