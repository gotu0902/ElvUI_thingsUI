# ElvUI_thingsUI

![Version](https://img.shields.io/badge/version-3.0.2-green)

## General

### Vertical Buff Icons
Toggle vertical growth for Buffs, overriding BCDM's horizontal mode, used for FHT.
Pretty much all it does, and all it's supposed to do.

### Trinket to CDM
Adds BCDM TrinketBar to Essentials for NHT (Left or Right), and essentials\utility for FHT (For instance if you have 8 essentials and set limit to 9, 1 trinket will go essentials, if you have 2 the second trinket anchors to utility)

## Positioning Tweaks

### Minimap & Aura Positions
- Moves Minimap /w Datapanels and Auras top right instead of bottom right & top left.
- Also moves ElvUI Right Chat Panel to bottom right, if the anchoring function below is enabled.

### Details! Chat Backdrop
- Anchors Details! to ElvUI Right Chat.
- To make it bigger, make Details! bigger and hit the "Reapply" button.
- To move it, /emove -> Move ElvUI Right Chat and it should follow. If you recently imported the profile you *may* have to reload first.

## Fixes\QoL
- Import Private settings.
- Import CVars
    - Sets Sound_NumChannels to 32 and turns of Weather Density.
    - Toggle on "Auto-set" to set NumChannels every login, something keeps resetting it, maybe BW.
    - Supposedly it helps with FPS, not having that many sound channels ready, I guess it depends on your sound settings, the more sound that's on the more channels you need? 🤷
 - Set UI Scale
    - Just a button for those that are too lazy or can't find where you have to type in UI Scale after installation when stuff looks weird. It may say 0.53 in /ec -> General but you have to re-enter it and hit ENTER to make sure it's set. Only need to do it once.

 ## Buff Bar Skinning & Anchoring

- Skins buff bars, caches the position.
- Grow up or down, change font, texture, the uzh

## BCDM + ElvUI
- Anchor BCDM frames to ElvUI Player\Target UFs
- Frames dynamically adjust as cooldown icons appear/disappear
- Change stuff to your liking
- Dynamic CastBar: Anchor BCDM Castbar to Secondary Power Bar when present, otherwise default to Power Bar. Buff Icons move with it when it's enabled.

**"When utility icons gets longer than essential icons, the frames move!?" Yes.**
- **Utility Threshold** = How many extra utility icons trigger movement
- **Overflow Offset** = Pixels(ish) to move each frame when triggered 
Example: 6 Essential + 9 Utility = +3 extra, frames move. Figure it out

## Special Bars and Icons
### Bars
- Move a tracked buff bar to somewhere else on the screen, like go to /CDM -> put say "Shield Block" on a Tracked Bar -> Enable a Special Bar and select it from the dropdown -> do w\e tf you want.
    - Anchor to w\e frame, inherit width may be a lil buggy with some other AddOns that refresh on events like BCDM_CastBar.

### Icons
- Same thing as bars, change up the text or border if you want, add glow, anchor it, all the stuffings.

# Installation

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