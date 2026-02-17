# Mythic Plus Whisperer (MPW)

A World of Warcraft addon for The War Within (11.0+) that helps you send friendly thank-you messages to party members after Mythic+ keys and LFG dungeons.

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

1. Download the latest release
2. Extract the `MythicPlusWhisperer` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart WoW or reload UI with `/reload`

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

## Version

- **Current Version**: 2.0.4
- **Interface**: 120001 (The War Within)
- **Author**: TuoNome

## License

This addon is provided as-is for World of Warcraft players. Feel free to modify for personal use.
