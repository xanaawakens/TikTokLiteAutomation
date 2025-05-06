# Technical Context

## Development Environment

The TikTok Lite Automation project is developed for mobile automation using:

- **Language**: Lua scripting language
- **Framework**: TouchSprite automation framework for iOS devices
- **Platform**: iOS mobile devices
- **Dependencies**: TSLib (TouchSprite Library)

## Core Technologies

### Lua
The entire codebase is written in Lua, which is commonly used for mobile automation scripts in the TouchSprite ecosystem.

### TouchSprite
TouchSprite is a framework for automating interactions with mobile applications on iOS. It provides APIs for:
- Screen capture and analysis
- Touch simulation (tap, swipe, etc.)
- Image recognition
- Color pattern matching
- UI navigation

### TSLib
TSLib is the core library that provides the interface between Lua scripts and the TouchSprite engine. It includes functions for:
- `findImageInRegionFuzzy` - Finding images on screen
- `tap`, `touchDown`, `touchMove`, `touchUp` - Touch simulation
- `getScreenSize` - Getting device screen dimensions
- `snapshot` - Taking screenshots
- `getDeviceInfo` - Getting device information
- `closeApp` - Closing applications

## Key Technical Components

### Color Pattern Detection
The system relies heavily on color pattern matrices to identify UI elements:
- `config.live_matrix` - For detecting the Live button
- `config.reward_button_matrix_1` and `config.reward_button_matrix_2` - For detecting reward buttons
- `config.claim_button_matrix` - For detecting claim buttons
- `config.complete_button_matrix` - For detecting completion buttons

### Image Recognition
The system uses image recognition to detect specific popups like:
- `popupMission.png` - Mission popup
- `popup2.png` - Reward upgrade popup

### Configuration System
A centralized `config.lua` file contains all configurable parameters:
- Timing configurations
- Search regions
- Color patterns
- Delay intervals

### Logging System
The system logs execution details to:
- Console (via `toast` and `nLog`)
- File (`analysis.txt`)
- Screenshots on error

## Technical Constraints

1. **Device Dependency**: The automation is designed for iOS devices and depends on device-specific features.
2. **Screen Resolution Dependency**: The color pattern detection is dependent on screen resolution.
3. **UI Changes Sensitivity**: The automation can break if TikTok Lite updates its UI.
4. **Timing Dependencies**: The script relies on specific timing configurations that may need adjustment based on network speed or device performance.

## Development Tools

1. TouchSprite editor for script editing
2. Mobile device for testing and execution
3. TouchSprite's debugging and logging features 