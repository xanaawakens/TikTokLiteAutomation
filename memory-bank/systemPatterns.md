# System Patterns

## Architecture Overview

The TikTok Lite Automation system follows a modular architecture with clear separation of concerns:

```
main.lua
 ├── change_account.lua (Account Management)
 ├── auto_tiktok.lua (Core Automation)
 │    └── rewards_live.lua (Live Stream Rewards)
 │         └── utils.lua (Utility Functions)
 └── config.lua (Configuration)
```

This architecture enables:
- Separation of functionality into discrete modules
- Easier maintenance and updates
- Clear dependency chain
- Focused modules with specific responsibilities

## Key Architectural Patterns

### Module Pattern
The system uses Lua's module pattern, where each file exports a table of functions:

```lua
local module = {}
function module.someFunction() ... end
return module
```

This enables clean imports and function access across modules:

```lua
local utils = require("utils")
utils.someFunction()
```

### Configuration Centralization
All configurable parameters are centralized in `config.lua` and referenced by modules:

```lua
local config = require("config")
local delayTime = config.timing.tap_delay or 1
```

### Error Handling Pattern
The system follows a consistent error handling pattern:

```lua
local success, error = someFunction()
if not success then
    return false, error or "Default error message"
end
```

Functions typically return `(success, result_or_error)` tuples for consistent error propagation.

### Safe Execution Pattern
The `safeExecute` pattern wraps function calls to catch errors:

```lua
local function safeExecute(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        return false, "Error: " .. tostring(result)
    end
    return true, result
end
```

## Core System Components

### Account Management (change_account.lua)
- Handles loading account credentials
- Implements account switching logic
- Tracks current account status
- Updates account progress

### Automation Core (auto_tiktok.lua)
- Implements the main automation workflow
- Controls navigation through TikTok Lite
- Manages error recovery
- Logs execution results

### Reward Processing (rewards_live.lua)
- Detects and interacts with reward UI elements
- Implements reward claim workflow
- Handles state transitions in the reward process

### Utilities (utils.lua)
- Provides common utility functions
- Implements UI element detection
- Handles popup management
- Provides timing and retry mechanisms

### Configuration (config.lua)
- Stores all configurable parameters
- Defines color patterns for UI detection
- Specifies search regions for UI elements
- Contains timing configurations

## Data Flow Patterns

### Main Execution Flow
1. **Start** (`main.lua`)
2. **Account Selection** (`change_account.lua`)
3. **App Navigation** (`auto_tiktok.lua`)
4. **Task Completion** (`rewards_live.lua`)
5. **Result Logging** (`auto_tiktok.logResult`)
6. **Next Account** (back to step 2)

### UI Interaction Pattern
1. **Check** - Detect UI element with color pattern or image
2. **Act** - Perform tap or swipe action
3. **Verify** - Verify action succeeded
4. **Recover** - Handle errors or retry if needed

## Error Handling and Recovery

The system implements multi-level error handling:

1. **Function Level** - Functions return success/error flags
2. **Module Level** - Modules catch and propagate errors
3. **Workflow Level** - The main flow handles critical errors
4. **System Level** - Account switching continues even if one account fails

## Logging and Monitoring

A comprehensive logging strategy is implemented:
- Real-time feedback via `toast` messages
- Debug logging via `nLog`
- Persistent logs in `analysis.txt`
- Error screenshots in the TouchSprite screenshots directory 