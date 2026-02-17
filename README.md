# Mythic Plus Whisperer (MPW)

A World of Warcraft addon for The War Within (11.0+) that helps you send friendly thank-you messages to party members after Mythic+ keys and LFG dungeons.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Settings](#settings)
- [How It Works](#how-it-works)
- [Customization & Lua Modifications](#customization--lua-modifications)
- [File Structure](#file-structure)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Version](#version)
- [License](#license)

## Features

- **Automatic Detection**: Automatically opens after Mythic+ completions and LFG dungeon rewards
- **Smart Roster Tracking**: Tracks all party members, even those who leave early
- **Customizable Messages**: Choose from friendly presets or use random variations
- **Safety Modes**: 
  - SAFE mode (preview only, no messages sent)
  - LIVE mode (actually sends whispers)
  - TEST mode (for testing with dummy data)
- **Accessibility Features**:
  - One-Tap mode for quick "thanks all" with a single button
  - Visual countdown before sending
  - Auto-greeting when joining groups
- **Anti-Spam Protection**: Prevents duplicate messages and respects cooldowns
- **Minimap Button**: Easy access with left-click (open), right-click (settings), Shift+click (toggle mode)

## Installation

### Standard Installation

1. Download the latest release from the repository
2. Extract the archive to your WoW addons directory:
   - **Windows**: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\`
   - **Mac**: `/Applications/World of Warcraft/_retail_/Interface/AddOns/`
3. You should see a `MythicPlusWhisperer` folder inside the `AddOns` directory
4. Launch World of Warcraft or reload the UI with `/reload` if already in-game
5. Verify installation by typing `/mpw` in chat

### Verify Installation

After installation, you should see:
- A minimap button (cyan/red icon depending on mode)
- The addon listed in the AddOns menu at character select
- Response to `/mpw` command in chat

## Usage

### Commands
- `/mpw` - Open settings
- `/mpw show` - Open the whisper window manually
- `/mpw test` - Test mode with dummy party data
- `/mpw arm` - Toggle between SAFE and LIVE modes

### Minimap Button
- **Left Click**: Open whisper window
- **Right Click**: Open settings
- **Shift + Left Click**: Toggle SAFE/LIVE mode
- **Drag**: Reposition the button around the minimap

### Modes

**SAFE Mode** (Cyan icon): Preview messages without sending. Great for testing.

**LIVE Mode** (Red icon): Actually sends whispers to selected players. Includes a countdown delay before sending.

**TEST Mode**: Opens the UI with dummy test data for configuration testing.

## Settings

- **Message 1**: Primary thank-you message (always sent)
- **Message 2**: Optional Battle.net tag invitation (M+ only, disabled in LFG)
- **Delay**: Countdown time before sending in LIVE mode
- **Auto Party Thanks**: Automatically say "ty all!" in party chat after LFG rewards
- **Auto Greeting**: Automatically greet party members when joining a group

### Message Placeholders

Use these in your custom messages:
- `{name}` - Player name (without realm)
- `{praise}` - Random friendly phrase
- `{role}` - Tank/Healer/DPS
- `{spec}` - Player's specialization
- `{btag}` - Your Battle.net tag

## How It Works

### Mythic+
1. Starts tracking when a keystone begins
2. Takes a snapshot of all party members at completion
3. Locks the roster (so late leavers don't affect the list)
4. Opens the UI automatically

### LFG Dungeons
1. Tracks all party members throughout the dungeon (sticky tracking)
2. Never removes anyone from the list (even if they leave)
3. Opens UI after reward or when leaving the dungeon
4. Message 2 is disabled for safety

---

## Customization & Lua Modifications

The addon is highly customizable through Lua file modifications. All Lua files are located in:
```
World of Warcraft\_retail_\Interface\AddOns\MythicPlusWhisperer\
```

**Important**: Always make a backup of the original file before modifying!

### 📝 Presets.lua - Customize Messages

This file contains all message templates and presets.

#### Modify Message 1 Presets (Thank You Messages)

**Location**: `Presets.lua`, lines 14-22

```lua
MPW.MSG1_PRESETS = {
    "gg {name}, {praise}",
    "ty {name}!",
    "thanks for the run {name}!",
    "Random",
    "{praise} {name}",
    "gg {name} :)",
    "ty again!",
}
```

**How to customize**:
```lua
-- Add your own messages to the list
MPW.MSG1_PRESETS = {
    "gg {name}, {praise}",
    "ty {name}!",
    "thanks for the run {name}!",
    "Random",
    "{praise} {name}",
    "gg {name} :)",
    "ty again!",
    "great job {name}!",              -- NEW
    "awesome run with you {name}",    -- NEW
    "had fun running with you!",      -- NEW
}
```

#### Modify Message 2 Presets (Battle.net Tag Invites)

**Location**: `Presets.lua`, lines 25-31

```lua
MPW.MSG2_PRESETS = {
    "if you wanna run again sometime: {btag}",
    "feel free to add me: {btag}",
    "up for more keys later? {btag}",
    "Random",
    "if you ever need a +1: {btag}",
}
```

**How to customize**:
```lua
-- Customize BTag invitation messages
MPW.MSG2_PRESETS = {
    "if you wanna run again sometime: {btag}",
    "feel free to add me: {btag}",
    "up for more keys later? {btag}",
    "Random",
    "if you ever need a +1: {btag}",
    "let's push keys together: {btag}",        -- NEW
    "add me for future runs: {btag}",          -- NEW
}
```

#### Customize Praise Phrases

**Location**: `Presets.lua`, lines 167-173

```lua
local function PraiseForRole(role)
    local pool = {
        "thanks!",
        "ty!",
        "cheers!",
        "appreciate it!",
        "thanks again!",
    }
    if type(math.random) == "function" then
        return pool[math.random(1, #pool)]
    end
    return pool[1]
end
```

**How to customize**:
```lua
-- Add more praise variations
local pool = {
    "thanks!",
    "ty!",
    "cheers!",
    "appreciate it!",
    "thanks again!",
    "well played!",       -- NEW
    "great work!",        -- NEW
    "awesome!",           -- NEW
}
```

#### Available Placeholders

You can use these placeholders in your custom messages:
- `{name}` - Player name (without realm)
- `{praise}` - Random friendly phrase from the praise pool
- `{role}` - Tank/Healer/DPS
- `{spec}` - Player's specialization (e.g., "Holy", "Protection")
- `{btag}` - Your Battle.net tag (Message 2 only)

**Example Custom Message**:
```lua
"great healing {name}! {btag}"  -- Only use if Message 2
"{spec} {role} crushed it!"      -- Uses spec and role
```

### ⚙️ Core.lua - Adjust Core Settings

This file contains core addon constants and utilities.

#### Change Maximum Message Length

**Location**: `Core.lua`, line 11

```lua
MPW.MAX_LEN = 140
```

**How to customize**:
```lua
MPW.MAX_LEN = 200  -- Allow longer messages (max 255)
```

#### Adjust Send Delay Between Messages

**Location**: `Core.lua`, line 9

```lua
MPW.SEND_DELAY = 0.35
```

**How to customize**:
```lua
MPW.SEND_DELAY = 0.5  -- Slower, safer (0.5 seconds between messages)
MPW.SEND_DELAY = 0.2  -- Faster (may trigger spam protection)
```

#### Change Default Pre-Send Countdown

**Location**: `Core.lua`, line 10

```lua
MPW.DEFAULT_PRE_SEND_DELAY = 3.5
```

**How to customize**:
```lua
MPW.DEFAULT_PRE_SEND_DELAY = 5.0  -- Longer countdown (5 seconds)
MPW.DEFAULT_PRE_SEND_DELAY = 2.0  -- Shorter countdown (2 seconds)
```

#### Adjust Maximum Player Rows Displayed

**Location**: `Core.lua`, line 8

```lua
MPW.MAX_ROWS = 5
```

**How to customize**:
```lua
MPW.MAX_ROWS = 10  -- Show more players at once (for raids/larger groups)
```

#### Change Maximum Custom Lines

**Location**: `Core.lua`, line 12

```lua
MPW.MAX_CUSTOM_LINES = 10
```

**How to customize**:
```lua
MPW.MAX_CUSTOM_LINES = 20  -- Allow more custom message slots
```

### 🎯 Triggers.lua - Modify Auto-Open Behavior

Control when the addon window automatically opens.

#### Disable Auto-Open for Mythic+

**Location**: `Triggers.lua`, search for `CHALLENGE_MODE_COMPLETED` event

**How to customize**:
```lua
-- Comment out or remove the auto-open line
-- MPW.UI.ShowWhisperWindow()
```

#### Disable Auto-Open for LFG

**Location**: `Triggers.lua`, search for `LFG_COMPLETION_REWARD` event

**How to customize**:
```lua
-- Comment out the auto-open line
-- MPW.UI.ShowWhisperWindow()
```

### 🔘 MinimapButton.lua - Customize Minimap Button

#### Change Button Position

**Location**: `MinimapButton.lua`, search for default position settings

```lua
-- The button position is saved in SavedVariables
-- To change default position, modify:
local angle = MPW_Config.minimapPos or 220  -- Degrees around minimap
```

**How to customize**:
```lua
local angle = MPW_Config.minimapPos or 180  -- Different starting position
```

#### Hide Minimap Button

**Location**: `MinimapButton.lua`

**How to customize**:
```lua
-- Add at the end of CreateMinimapButton function:
button:Hide()  -- Completely hide minimap button
```

### 🤝 AutoGreet.lua - Customize Auto-Greeting

Modify the automatic greeting sent when joining groups.

**Location**: `AutoGreet.lua`, search for greeting message

**How to customize**:
```lua
-- Find the greeting message string and modify it
SendChatMessage("Hello everyone!", "PARTY")  -- Change greeting text
```

### 📊 AntiSpam.lua - Adjust Anti-Spam Settings

Control spam protection and cooldowns.

#### Modify Cooldown Timers

**Location**: `AntiSpam.lua`, search for cooldown values

**How to customize**:
```lua
-- Typical pattern:
local COOLDOWN = 300  -- Change from 5 minutes to your preferred value
```

### Complete Example: Adding Custom Messages

Here's a complete example of adding highly personalized messages:

**File**: `Presets.lua`

```lua
-- Original MSG1_PRESETS
MPW.MSG1_PRESETS = {
    "gg {name}, {praise}",
    "ty {name}!",
    "thanks for the run {name}!",
    "Random",
    "{praise} {name}",
    "gg {name} :)",
    "ty again!",
}

-- Modified with custom messages
MPW.MSG1_PRESETS = {
    "gg {name}, {praise}",
    "ty {name}!",
    "thanks for the run {name}!",
    "Random",
    "{praise} {name}",
    "gg {name} :)",
    "ty again!",
    -- Your custom additions:
    "amazing {spec} plays {name}!",
    "loved running with a skilled {role} like you {name}!",
    "you rocked that dungeon {name}, {praise}",
    "stellar performance {name}!",
}
```

### Testing Your Changes

After modifying any Lua files:

1. **Save the file**
2. **Reload the UI** in WoW with `/reload`
3. **Test in SAFE mode first**: Use `/mpw test` to see preview with dummy data
4. **Verify messages**: Check that your changes appear in the dropdown menus
5. **Test actual sending**: Switch to LIVE mode only after confirming everything looks correct

### Troubleshooting Lua Modifications

**Problem**: UI errors or addon doesn't load after modification

**Solution**:
1. Check for Lua syntax errors (missing commas, quotes, brackets)
2. Restore from your backup
3. Use `/console scriptErrors 1` to see detailed error messages
4. Common mistakes:
   - Missing comma between list items
   - Unmatched quotes: `"message` (missing closing quote)
   - Unmatched brackets: `{ item1, item2` (missing closing `}`)

**Problem**: Changes don't appear

**Solution**:
1. Ensure you saved the file
2. Completely exit WoW and restart (not just `/reload`)
3. Clear WoW cache if needed: Delete `WoW/_retail_/Cache` folder

---

## File Structure

Overview of all addon files and their purposes:

| File | Purpose | Common Modifications |
|------|---------|---------------------|
| **Core.lua** | Core utilities, constants, SavedVariables initialization | Delays, limits, max length |
| **Presets.lua** | Message templates and preset lists | Add/edit message presets, praise phrases |
| **Snapshot.lua** | Party roster tracking and snapshots | Modify tracking behavior |
| **Send.lua** | Message sending logic and queue management | Sending behavior, delays |
| **UI.lua** | Main UI window, settings panel, player rows | UI layout, button behavior |
| **Accessibility.lua** | One-tap mode and accessibility features | Quick-send behavior |
| **AutoGreet.lua** | Automatic greeting when joining groups | Greeting message, timing |
| **MinimapButton.lua** | Minimap button creation and behavior | Button position, tooltips |
| **AntiSpam.lua** | Spam protection and cooldown tracking | Cooldown times, limits |
| **Triggers.lua** | Event handlers for M+ and LFG completion | Auto-open behavior |
| **MythicPlusWhisperer.toc** | Addon metadata and file load order | Version, dependencies |

---

## Troubleshooting

### Addon Not Loading

**Symptoms**: No minimap button, `/mpw` command doesn't work

**Solutions**:
1. Verify the folder structure:
   ```
   AddOns/
   └── MythicPlusWhisperer/
       ├── MythicPlusWhisperer.toc
       ├── Core.lua
       ├── Presets.lua
       └── ... (other .lua files)
   ```
2. Enable the addon in the AddOns menu at character selection
3. Check for Lua errors: `/console scriptErrors 1`
4. Disable conflicting addons temporarily

### Window Not Opening Automatically

**Symptoms**: Window doesn't open after completing M+ or LFG

**Solutions**:
1. Check if you're in TEST mode (`/mpw test` - exit test mode)
2. Verify trigger events in `Triggers.lua` are enabled
3. Manually open with `/mpw show`
4. Check that the key actually completed (M+) or reward was received (LFG)

### Messages Not Sending (LIVE Mode)

**Symptoms**: Countdown completes but no whispers sent

**Solutions**:
1. Verify you're in LIVE mode (red icon), not SAFE mode (cyan icon)
2. Check anti-spam cooldowns (wait a few minutes between runs)
3. Verify player names are correct (not offline/cross-realm issues)
4. Check that Battle.net is connected for BTag messages

### Error Messages After Modifying Lua

**Symptoms**: Red error text, addon breaks after editing

**Solutions**:
1. Restore from backup immediately
2. Common syntax errors to check:
   - Missing commas: `{"item1" "item2"}` → `{"item1", "item2"}`
   - Unclosed strings: `"message` → `"message"`
   - Unclosed brackets: `{item1, item2` → `{item1, item2}`
3. Use a Lua-aware text editor with syntax checking (VS Code, Sublime Text, Notepad++)
4. Validate Lua syntax with your editor's built-in linter or online at https://www.tutorialspoint.com/execute_lua_online.php

### Minimap Button Missing

**Symptoms**: Can't find the minimap button

**Solutions**:
1. Check if button is hidden behind other addons
2. Reset button position: `/run MPW_Config.minimapPos = nil` then `/reload`
3. Look around the entire minimap edge (it might have drifted)
4. Verify `MinimapButton.lua` didn't get corrupted

### Custom Messages Not Appearing

**Symptoms**: Custom messages don't show in dropdown

**Solutions**:
1. Ensure you saved the Lua file after editing
2. Completely restart WoW (not just `/reload`)
3. Check Lua syntax - errors prevent the file from loading
4. Verify you edited the correct file in the correct AddOns folder

---

## FAQ

### Q: Is this addon safe to use?

**A**: Yes! The addon includes SAFE mode (default) that only previews messages without sending them. You control when messages are actually sent, and built-in anti-spam protection prevents abuse.

### Q: Will I get banned for using this?

**A**: No. This addon uses standard Blizzard APIs and doesn't automate gameplay or violate ToS. It's a convenience tool that still requires your input to send messages.

### Q: Can I use this in raids?

**A**: The addon is designed for 5-player content (M+ and LFG dungeons). While it may work in raids, it's not optimized for larger groups.

### Q: How do I add my Battle.net tag?

**A**: The addon automatically detects your BattleTag from your Battle.net connection. Just ensure you're logged into Battle.net when playing WoW.

### Q: Can I change messages in-game?

**A**: Yes! The settings panel allows you to select from presets and use the in-game custom message editor. For adding new presets, you need to edit `Presets.lua`.

### Q: Does this work with other languages?

**A**: Yes, you can customize all messages in `Presets.lua` to any language. The addon code is in English, but all player-facing messages are customizable.

### Q: How do I disable auto-greeting?

**A**: Open settings with `/mpw` and uncheck "Auto Greeting" option, or modify `AutoGreet.lua` to disable it entirely.

### Q: Can I use this for role-specific messages?

**A**: Yes! Use placeholders like `{role}` and `{spec}` in your messages. Example: `"great {role} work {name}!"` or `"amazing {spec} plays!"`

### Q: What's the difference between Message 1 and Message 2?

**A**: 
- **Message 1**: Primary thank-you message (always available)
- **Message 2**: Optional BattleTag invitation (only for M+, disabled in LFG for safety)

### Q: How does "Random" work in presets?

**A**: When you select "Random", the addon randomly picks from all non-custom presets in the list (excluding other "Random" entries and custom messages).

### Q: Can I schedule messages to send later?

**A**: No, messages are sent immediately after the countdown in LIVE mode. This is by design to keep the addon simple and prevent automation concerns.

---

## Version

- **Current Version**: 2.0.4
- **Interface**: 120001 (The War Within)
- **Author**: TuoNome
- **Repository**: https://github.com/ThePipSpi/MPW

### Changelog

For detailed version history and changes, see the [Changelog](_changelog.txt) file.

---

## Contributing

### Reporting Issues

If you encounter bugs or have feature requests:
1. Check existing issues on GitHub
2. Provide detailed information:
   - WoW version
   - Addon version
   - Steps to reproduce
   - Error messages (enable with `/console scriptErrors 1`)
3. Include your Lua modifications if you've made any

### Submitting Custom Presets

Have great message presets to share?
1. Fork the repository
2. Add your presets to `Presets.lua`
3. Submit a pull request with a description
4. Keep messages friendly and drama-free!

### Development Setup

To modify and test the addon:
1. Clone the repository
2. Create a symbolic link from your AddOns folder to the `MythicPlusWhisperer` directory
3. Make your changes
4. Test with `/reload` and `/mpw test`
5. Submit pull requests with clear descriptions

---

## License

This addon is provided as-is for World of Warcraft players. Feel free to modify for personal use.

### Permissions

✅ **Allowed**:
- Personal modifications
- Sharing with friends
- Creating custom presets
- Using in-game and sharing experiences

⚠️ **Please Don't**:
- Redistribute modified versions without credit
- Use for commercial purposes
- Remove author attribution
- Bundle with malware or unauthorized software

---

## Credits

**Author**: TuoNome
**Contributors**: Community feedback and suggestions welcome!

### Special Thanks

- World of Warcraft community for feedback
- Mythic+ runners for inspiration
- All players who use this addon to spread positivity in the game

---

## Support

- **Issues**: https://github.com/ThePipSpi/MPW/issues
- **Discussions**: https://github.com/ThePipSpi/MPW/discussions

### Quick Help

- Need help? Type `/mpw` in game for settings
- Want to test? Use `/mpw test` for dummy data
- Toggle modes? Shift + click minimap button
- Stuck? Use `/reload` to restart the UI

---

**Happy Running! May your keys be timed and your groups be friendly! 🔑✨**
