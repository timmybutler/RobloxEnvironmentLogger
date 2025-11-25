# Settings System Documentation

## Overview

The Discord bot now includes a comprehensive settings system that allows each user to customize how scripts are analyzed and reconstructed.

## Usage

### View and Toggle Settings

```
!settings
```

This command displays an interactive settings panel with buttons to toggle each feature on/off.

### Features

#### 1. **hookOp** (Default: OFF)
**Description:** Enables hooking operations such as 'repeat', 'while', 'if', >, <, >=, <=, ==, ~=, etc.

**When enabled:**
- Captures conditional checks and loop operations
- Shows comparison operators and their values
- Tracks control flow operations

**Use case:** Deep analysis of script logic and conditional behavior


#### 2. **explore_funcs** (Default: ON)
**Description:** Show full function bodies instead of placeholders

**When enabled:**
- Function definitions are fully visible
- You can see the complete implementation

**When disabled:**
- Functions appear as: `function()--[[enable explore funcs to view]]end`
- Reduces output clutter for scripts with many functions

**Use case:** Toggle off for high-level structure view


#### 3. **spyexeconly** (Default: OFF)
**Description:** Only spy variables an executor would have (hookfunction, hookmetamethod, etc.)

**When enabled:**
- Focuses only on executor-specific APIs
- Filters out standard Roblox APIs
- Highlights exploit-related functions

**Use case:** Security analysis and exploit detection


#### 4. **no_string_limit** (Default: OFF)
**Description:** Turns off string truncation

**When enabled:**
- All strings are shown in full, regardless of length
- No "...(256 bytes left)" messages

**When disabled:**
- Strings longer than 256 characters are truncated
- Shows remaining byte count

**Use case:** Enable for complete data extraction


#### 5. **minifier** (Default: OFF)
**Description:** Minifies (inlines) the generated output

**When enabled:**
- Makes files smaller and more compact
- Removes unnecessary whitespace
- Inlines simple expressions
- More readable for experienced users

**Benefits:**
- Smaller file sizes
- Faster to scan
- Better overall readability

**Note:** Can be slower on large files


#### 6. **comments** (Default: ON)
**Description:** Displays helpful comments

**When enabled:**
- Shows `if` check conditions (did it run or not)
- pcall success/failure indicators
- Other contextual information

**Examples:**
```lua
-- Condition evaluated to true
if condition then
    -- ...
end

-- pcall succeeded
local success, result = pcall(...)
```

**Use case:** Better understanding of execution flow


#### 7. **ui_detection** (Default: OFF)
**Description:** Tries to detect UI libraries in the script

**Status:** [EXPERIMENTAL - MAY NOT FULLY WORK]

**When enabled:**
- Attempts to identify UI library usage
- Halts execution when UI is detected
- Continues with the rest of the code

**Use case:** Separate UI code from logic


#### 8. **notify_scamblox** (Default: OFF)
**Description:** Notifies when a webhook/scam script is detected

**Requirements:** Premium only

**When enabled:**
- Sends notification to scam-blox channel
- Alerts when malicious patterns are detected
- Helps community safety

**Use case:** Community protection and security monitoring


#### 9. **constant_collection** (Default: OFF)
**Description:** Collects all strings detected in a script

**Requirements:**
- hookOp must be enabled
- Does not currently support Luraph obfuscation

**When enabled:**
- Extracts all string constants
- Creates a collection of detected strings
- Useful for data extraction

**Use case:** String analysis and data mining


#### 10. **duplicate_searcher** (Default: OFF)
**Description:** Searches for files with the same hash before running

**When enabled:**
- Calculates script hash
- Searches database for duplicates
- Shows results from previous analyses
- Saves processing time

**Use case:** Avoid re-analyzing known scripts


#### 11. **neverNester** (Default: OFF)
**Description:** Prevents nested if checks by converting them to early-exit patterns

**When enabled:**
```lua
-- Before (nested):
if a then
    print('Hi')
end

-- After (early-exit):
if not (a) then return end
print('Hi')
```

**Benefits:**
- Reduces indentation
- Improves readability
- Handles spammy if checks better

**Use case:** Cleaner output for deeply nested code

---

## Technical Implementation

### Settings Storage

- Settings are stored per-user in `bot_settings.json`
- Each user has their own independent settings
- Default settings are applied for new users
- Settings persist across bot restarts

### Settings Integration

1. **Environment Variables:** Settings are passed to the Lua script via environment variables
2. **Format:** `SETTING_SETTINGNAME=1` (enabled) or `SETTING_SETTINGNAME=0` (disabled)
3. **Lua Side:** The reconstructor reads these variables and adjusts behavior accordingly

### Button Interface

- Interactive Discord buttons for easy toggling
- Real-time updates (no need to re-run command)
- Visual indicators: ✅ (enabled) / ❌ (disabled)
- 5-minute timeout for button interaction

---

## Examples

### Example 1: Security Analysis
```
!settings
```
Enable: `spyexeconly`, `hookOp`, `comments`

Then:
```
!log <paste suspicious script>
```

Result: Focused analysis on executor functions with detailed comments

### Example 2: Clean Code Reconstruction
```
!settings
```
Enable: `explore_funcs`, `minifier`, `neverNester`
Disable: `comments`

Then:
```
!log <paste complex script>
```

Result: Clean, minified output with flat control flow

### Example 3: Data Extraction
```
!settings
```
Enable: `no_string_limit`, `constant_collection`, `hookOp`

Then:
```
!log <paste data script>
```

Result: All strings extracted with no truncation

---

## FAQ

**Q: Do settings affect other users?**
A: No, each user has their own settings that don't affect anyone else.

**Q: Can I reset to defaults?**
A: Yes, toggle all settings back to match the defaults listed above.

**Q: Which settings should I enable for best results?**
A: It depends on your goal:
- **General analysis:** `explore_funcs`, `comments`
- **Security analysis:** `spyexeconly`, `hookOp`, `comments`
- **Clean output:** `minifier`, `neverNester`, disable `comments`
- **Data extraction:** `no_string_limit`, `constant_collection`

**Q: Can settings slow down processing?**
A: Yes, `minifier` can be slower on large files. Other settings have minimal performance impact.

**Q: What are premium features?**
A: Currently only `notify_scamblox` requires premium status.

---

## Support

For issues or questions about settings, please contact the bot administrator or submit an issue on the GitHub repository:
https://github.com/timmybutler/RobloxEnvironmentLogger
