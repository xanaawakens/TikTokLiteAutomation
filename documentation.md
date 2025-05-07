# TikTok Lite Automation - Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Module Documentation](#module-documentation)
4. [Configuration Reference](#configuration-reference)
5. [Workflow Documentation](#workflow-documentation)
6. [Extension Guide](#extension-guide)
7. [Troubleshooting](#troubleshooting)

## Project Overview

TikTok Lite Automation is a system designed to automate interactions with the TikTok Lite application for earning reward points. The automation handles opening the app, navigating to live streams, detecting and claiming rewards, and managing multiple accounts.

### Key Features
- Multi-account automation with account switching
- Live stream navigation and viewing
- Reward button detection and interaction
- Automatic claim button tapping
- Popup handling
- Error recovery mechanisms
- Detailed logging

### System Requirements
- iOS device with TouchSprite framework
- TikTok Lite application installed
- ADManager for account switching

## System Architecture

The system follows a modular architecture with clear separation of concerns:

```
main.lua (Entry point)
 ├── change_account.lua (Account Management)
 ├── auto_tiktok.lua (Core Automation)
 │    └── rewards_live.lua (Live Stream Rewards)
 │         └── utils.lua (Utility Functions)
 ├── file_manager.lua (File Operations)
 ├── error_handler.lua (Error Handling)
 ├── logger.lua (Logging)
 └── config.lua (Configuration)
```

### Module Dependency Graph

```
                  ┌───────────┐
                  │ config.lua│
                  └─────┬─────┘
                        │
                        ▼
┌──────────────┐     ┌─────────┐     ┌───────────────┐
│change_account│◄────┤main.lua ├────►│ file_manager  │
└──────┬───────┘     └────┬────┘     └───────┬───────┘
       │                  │                  │
       │                  ▼                  │
       │           ┌────────────┐            │
       └──────────►│auto_tiktok │◄───────────┘
                   └─────┬──────┘
                         │
                   ┌─────▼──────┐
                   │rewards_live│
                   └─────┬──────┘
                         │
                    ┌────▼────┐    ┌──────────────┐
                    │utils.lua├───►│error_handler │
                    └────┬────┘    └──────────────┘
                         │
                         ▼
                    ┌─────────┐
                    │logger.lua│
                    └─────────┘
```

## Module Documentation

### main.lua
Entry point for the automation system. Manages the main flow and coordinates between modules.

**Main Responsibilities:**
- Initialize global screen dimensions
- Orchestrate account switching
- Call automation functions
- Handle errors at the highest level
- Manage the overall flow across accounts

**Key Functions:**
- `main()` - Main execution flow
- `startApplication()` - Initialize and start the automation

### auto_tiktok.lua
Core automation logic for interacting with TikTok Lite.

**Main Responsibilities:**
- Open TikTok Lite application
- Navigate to live stream screens
- Handle reward button detection
- Process claim buttons
- Manage popup interactions
- Track progress and success/failure

**Key Functions:**
- `runTikTokLiteAutomation()` - Main automation function
- `initializeApp()` - Opens TikTok Lite
- `navigateToLiveStream()` - Navigates to live stream section
- `handlePopupsAfterClaim()` - Processes popups after claiming rewards

### rewards_live.lua
Handles live stream specific functions and reward claim detection.

**Main Responsibilities:**
- Detect live stream UI elements
- Tap live stream buttons
- Check and claim rewards
- Navigate between streams
- Verify UI state transitions

**Key Functions:**
- `checkButtonLive()` - Detects live button
- `tapLiveButton()` - Taps the live button
- `waitForLiveScreen()` - Waits for live screen to load
- `checkRewardButton()` - Detects reward button
- `tapRewardButton()` - Taps the reward button
- `checkClaimButton()` - Detects claim button
- `tapClaimButton()` - Taps the claim button
- `checkCompleteButton()` - Detects complete button
- `switchToNextStream()` - Changes to next live stream

### utils.lua
Utility functions used throughout the application.

**Main Responsibilities:**
- Color pattern detection
- Basic UI interactions (tap, swipe)
- Popup detection and handling
- App opening and verification
- Safe execution wrappers
- File operations
- Parameter validation

**Key Functions:**
- `findColorPattern()` - Find color patterns on screen
- `tapWithConfig()` - Tap with configurable delay
- `swipeWithConfig()` - Swipe with configurable parameters
- `checkAndClosePopup()` - Find and close popups
- `openTikTokLite()` - Open the TikTok Lite app
- `retryOperation()` - Retry functions with error handling
- `writeFileAtomic()` - Safe file writing
- `readFileSafely()` - Safe file reading

### change_account.lua
Manages account switching operations using ADManager.

**Main Responsibilities:**
- Open ADManager application
- Navigate ADManager UI
- Find and select TikTok Lite
- Switch between accounts
- Track current account

**Key Functions:**
- `switchTikTokAccount()` - Main account switching function
- `openADManager()` - Opens ADManager app
- `findAndClickTikTokIcon()` - Finds and clicks TikTok in ADManager
- `restoreAccount()` - Restores an account backup
- `getAllFilesInFolder()` - Lists all account backups
- `getCurrentAccount()` - Gets current account info

### file_manager.lua
Handles file operations for the automation system.

**Main Responsibilities:**
- Read and write account information
- Update the current account tracker
- Log automation results
- Manage account lists

**Key Functions:**
- `updateAccountList()` - Updates the list of accounts
- `getCurrentAccount()` - Gets current account and total
- `getAccountName()` - Gets the name of the current account
- `updateAccountName()` - Updates account name in configuration
- `updateCurrentAccount()` - Updates the current account tracker
- `logResult()` - Logs results of automation for an account

### error_handler.lua
Handles error creation, logging and recovery.

**Main Responsibilities:**
- Standardize error objects
- Log errors consistently
- Provide error codes and categories
- Support error recovery

**Key Functions:**
- `createError()` - Creates standardized error objects
- `logError()` - Logs errors with standard format
- `handleError()` - Handles errors with appropriate recovery

### logger.lua
Logging system for the automation.

**Main Responsibilities:**
- Log events at various levels
- Output to console and files
- Timestamp and format logs
- Manage log files

**Key Functions:**
- `debug()` - Log debug messages
- `info()` - Log info messages
- `warning()` - Log warning messages
- `error()` - Log error messages
- `close()` - Close logging resources

### config.lua
Contains all configuration parameters for the automation.

**Main Responsibilities:**
- Store app information
- Define timing parameters
- Set color patterns for detection
- Configure search regions
- Set paths and other constants

**Key Sections:**
- `app` - Application information
- `timing` - All timing parameters
- `color_patterns` - Color matrices for detection
- `search_regions` - Screen regions for searches
- `ui` - UI coordinates and parameters
- `admanager` - ADManager app settings
- `limits` - Runtime limits and constraints

## Configuration Reference

### Timing Configuration
The `config.timing` table contains all timing parameters used for the automation:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `launch_wait` | Wait time after opening app | 6s |
| `check_timeout` | Maximum time to check if app opened | 10s |
| `tap_delay` | Delay after tapping | 0.5s |
| `swipe_delay` | Delay after swiping | 1s |
| `live_button_search` | Wait before finding live button | 2.5s |
| `ui_stabilize` | Wait for UI to stabilize | 1.5s |
| `claim_check_interval` | Time between claim button checks | 1s |
| `reward_click_wait` | Wait after clicking reward button | 8s |
| `claim_tap_delay` | Delay after tapping claim button | 0.5s |
| `after_claim_delay` | Delay after claiming | 1s |
| `popup_check_after_claim` | Wait before checking popup after claim | 0.5s |

### Color Pattern Matrices
Color patterns are defined as arrays of points with colors to detect UI elements:

```lua
live_button = {
    {48, 61, 0xf0f0f0},
    {49, 62, 0xffffff},
    -- more points...
}
```

Each entry contains:
- X coordinate
- Y coordinate
- Color (hex value)

The system looks for these exact color patterns to identify UI elements.

### Search Regions
Search regions limit where the system looks for UI elements:

```lua
search_regions = {
    live_button = {0, 0, 200, 200},
    tiktok_loaded = {0, 1200, 750, 1350},
    reward_button = {0, 0, 375, 1350}
}
```

Each region contains:
- x1 (top-left x)
- y1 (top-left y)
- x2 (bottom-right x)
- y2 (bottom-right y)

### Adaptive Timing System
The claim detection uses an adaptive timing system that:
1. Starts with a base interval (`claim_check_interval`)
2. Reduces interval after successful claims
3. Gradually increases interval after consecutive failures
4. Optimizes processing by measuring elapsed time

## Workflow Documentation

### Account Switching Workflow

```
┌─────────┐     ┌─────────────┐     ┌────────────────┐
│ main.lua│     │change_account│     │ file_manager   │
└────┬────┘     └──────┬──────┘     └───────┬────────┘
     │                 │                    │
     │ switchTikTokAccount()                │
     ├────────────────►│                    │
     │                 │                    │
     │                 │ openADManager()    │
     │                 ├─────────┐          │
     │                 │         │          │
     │                 │◄────────┘          │
     │                 │                    │
     │                 │ clickAppsList()    │
     │                 ├─────────┐          │
     │                 │         │          │
     │                 │◄────────┘          │
     │                 │                    │
     │                 │findAndClickTikTokIcon()
     │                 ├─────────┐          │
     │                 │         │          │
     │                 │◄────────┘          │
     │                 │                    │
     │                 │ restoreAccount()   │
     │                 ├──────────────────►│
     │                 │                    │
     │                 │                   get/updateCurrentAccount()
     │                 │                    ├─┐
     │                 │                    │ │
     │                 │                    │◄┘
     │                 │◄───────────────────┘
     │◄────────────────┘                    │
     │                                      │
```

### Live Stream Automation Workflow

```
┌────────────┐     ┌────────────┐     ┌─────────────┐
│auto_tiktok │     │rewards_live│     │  utils      │
└─────┬──────┘     └─────┬──────┘     └─────┬───────┘
      │                  │                  │
      │initializeApp()   │                  │
      ├─────────────────┐│                  │
      │                 ││                  │
      │                 ││openTikTokLite()  │
      │                 │├────────────────►│
      │                 ││                  │
      │◄────────────────┘│◄─────────────────┘
      │                  │                  │
      │navigateToLiveStream()               │
      ├─────────────────►│                  │
      │                  │                  │
      │                  │tapLiveButton()   │
      │                  ├────────────────►│
      │                  │                  │
      │                  │◄─────────────────┘
      │                  │                  │
      │                  │waitForLiveScreen()
      │                  ├─────────────────┐│
      │                  │                 ││
      │                  │◄────────────────┘│
      │◄─────────────────┘                  │
      │                  │                  │
      │switchToNextStream()                 │
      ├─────────────────►│                  │
      │                  │                  │
      │                  │swipeWithConfig() │
      │                  ├────────────────►│
      │                  │                  │
      │                  │◄─────────────────┘
      │◄─────────────────┘                  │
      │                  │                  │
      │tapRewardButton() │                  │
      ├─────────────────►│                  │
      │                  │                  │
      │                  │checkRewardButton()
      │                  ├────────────────►│
      │                  │                  │
      │                  │◄─────────────────┘
      │◄─────────────────┘                  │
```

### Claim Detection & Handling Workflow

```
┌────────────┐     ┌────────────┐     ┌─────────────┐
│auto_tiktok │     │rewards_live│     │  utils      │
└─────┬──────┘     └─────┬──────┘     └─────┬───────┘
      │                  │                  │
      │ while true:      │                  │
      ├─────────┐        │                  │
      │         │        │                  │
      │         │tapClaimButton()           │
      │         ├─────────────────►│        │
      │         │                  │        │
      │         │                  │findColorPattern()
      │         │                  ├───────►│
      │         │                  │        │
      │         │                  │◄───────┘
      │         │                  │        │
      │         │                  │tapWithConfig()
      │         │                  ├───────►│
      │         │                  │        │
      │         │                  │◄───────┘
      │         │◄─────────────────┘        │
      │         │                           │
      │         │handlePopupsAfterClaim()   │
      │         ├────────────────┐          │
      │         │                │          │
      │         │◄───────────────┘          │
      │         │                           │
      │         │checkCompleteButton()      │
      │         ├─────────────────►│        │
      │         │                  │        │
      │         │◄─────────────────┘        │
      │         │                           │
      │◄────────┘                           │
```

## Extension Guide

### Adding New UI Element Detection
To add detection for a new UI element:

1. Add a new color matrix to `config.lua`:
```lua
new_button_matrix = {
    {x1, y1, color1},
    {x2, y2, color2},
    -- Add more points for reliability
}
```

2. Add a search region if needed:
```lua
search_regions = {
    -- existing regions
    new_button = {x1, y1, x2, y2}
}
```

3. Create detection functions in the appropriate module:
```lua
function rewardsLive.checkNewButton()
    return findButton(config.new_button_matrix, config.search_regions.new_button, "new button")
end

function rewardsLive.tapNewButton()
    local success, error = tapButton(
        rewardsLive.checkNewButton,
        nil,
        nil,
        "new button"
    )
    
    return success, error
end
```

### Updating Color Patterns
When TikTok Lite updates its UI, color patterns may need adjustment:

1. Take screenshots of the updated UI
2. Identify stable color points (avoid gradients and animations)
3. Use color picker tools to get exact RGB/hex values
4. Update the matrices in `config.lua`
5. Test with different device screens and lighting

Tips for reliable color patterns:
- Use at least 5-8 points per UI element
- Include points at the edges and center
- Add redundant matrices for critical elements
- Consider contrast, brightness, and device variations

### Adding New Reward Types
To extend the system for new reward types:

1. Create new color patterns for the new UI elements
2. Add new detection functions to `rewards_live.lua`
3. Create a new automation flow in a separate module or in `auto_tiktok.lua`
4. Update `main.lua` to include the new automation in the main flow

Example for video reward automation:
```lua
function autoTiktok.runVideoRewardAutomation()
    -- Similar structure to runTikTokLiteAutomation()
    -- but customized for video rewards
end
```

## Troubleshooting

### Common Issues and Solutions

| Issue | Possible Causes | Solutions |
|-------|----------------|-----------|
| Claim button not detected | UI changed, wrong color matrix | Update color matrices, increase search region |
| Account switching fails | ADManager UI changed, wrong coordinates | Update coordinates in config.admanager |
| App fails to open | Permission issues, app not installed | Check app installation, verify bundle ID |
| Slow claim response | Timing parameters too long | Adjust claim timing parameters in config |
| Something went wrong error | Too many rapid claims | Increase minimum time between claims |
| Popups not closing | Wrong popup coordinates | Update popup_close coordinates |

### Log Analysis Guide

The `analysis.txt` file contains logs of automation runs. Key elements to look for:

1. **Timing issues**:
   - Look for large gaps between timestamps
   - Check for repeated attempts at the same action

2. **UI detection failures**:
   - Look for "Không tìm thấy" (Not found) messages
   - Check the coordinates of found elements

3. **Claim patterns**:
   - Review the frequency of successful claims
   - Look for patterns in failed claim attempts

4. **Account switching**:
   - Check for successful account switching messages
   - Verify account names are being updated correctly

### Performance Tuning

For optimal performance:

1. **Color Pattern Optimization**:
   - Use minimum points needed for reliable detection
   - Position points strategically (edges and distinctive areas)

2. **Timing Optimization**:
   - Reduce `claim_check_interval` for faster claiming
   - Adjust `after_claim_delay` based on device performance

3. **Search Region Restriction**:
   - Limit search regions to the smallest possible area
   - Create targeted regions for each UI element

4. **Error Recovery**:
   - Add additional error recovery stages for common failures
   - Use adaptive retry intervals based on error types

### Debugging Tools

The system includes built-in debugging tools:

1. **Logger levels**:
   - Set `config.logging.level` to "debug" for detailed logs
   - Use `logger.debug()` for temporary debugging

2. **Screenshots**:
   - Enable `config.general.take_screenshots` for error captures
   - Screenshots are saved to the path in `config.paths.screenshots`

3. **Log Rotation**:
   - Control log file retention with `config.logging.rotate_logs`
   - Set max files with `config.logging.max_log_files` 