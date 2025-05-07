<!-- 
  activeContext.md - What we're currently working on
  This file contains information about current focus, recent changes, and next steps
-->

# Active Context

## Current Focus

The project is currently in the analysis and planning phase. Based on the codebase review and screenshots analysis, we're focusing on understanding:

1. The structure and functionality of the existing TikTok Lite automation code
2. The reward mechanisms in TikTok Lite that can be automated
3. The UI elements and interaction patterns needed for automation
4. The account management system for handling multiple accounts

## Recent Discoveries

From the code analysis:

1. The project is implemented in Lua using the TouchSprite framework for iOS automation
2. The codebase is modular with clear separation between account management, automation logic, and utility functions
3. The system uses color pattern detection and image recognition to identify UI elements
4. There's a comprehensive error handling and logging mechanism in place
5. The system supports multiple account switching

From the screenshots:

1. TikTok Lite has multiple reward mechanisms including livestream viewing, video watching, and daily tasks
2. The rewards can be converted to PayPay credits
3. There's a current Golden Week carnival campaign with increased rewards
4. The UI has clear patterns for reward buttons, claim buttons, and confirmation dialogs

## Active Decisions

1. **Architecture Enhancement**: Evaluating whether the current modular architecture is sufficient or needs enhancement
2. **Error Handling**: Considering improvements to error recovery mechanisms, especially for UI detection failures
3. **Logging**: Assessing the current logging system for improvements in error diagnosis
4. **Account Management**: Exploring optimizations for account switching and management
5. **New Reward Types**: Identifying additional reward mechanisms that could be automated
6. **Version Control Protocol**: Implemented strict rule that Git operations (commits/pushes) must only be performed with explicit user instruction

## Current Challenges

1. **UI Detection Reliability**: Ensuring reliable detection of UI elements across different device sizes and app versions
2. **Error Recovery**: Improving the system's ability to recover from unexpected states
3. **TikTok Lite Updates**: Handling potential changes in TikTok Lite's UI or reward mechanisms
4. **Account Security**: Managing accounts securely without risking detection or bans
5. **Optimization**: Finding the optimal balance between aggressiveness and reliability in the automation

## Implementation Status

Currently, the codebase shows:

1. A working implementation for livestream reward automation
2. Account switching functionality
3. Basic error handling and logging
4. Configuration management

The next focus areas appear to be:

1. Enhancing the reliability of UI element detection
2. Adding automation for additional reward types (video watching, daily check-ins)
3. Improving error recovery mechanisms
4. Optimizing the workflow for maximum point efficiency

## Next Steps

1. Create a comprehensive project structure for ongoing development
2. Document the existing codebase thoroughly
3. Identify areas for improvement or extension
4. Design enhancements for error recovery and logging
5. Plan for additional reward automation implementations

## Recent Changes

- Removed time limits by setting account_runtime and total_runtime to effectively unlimited values
- Removed backward compatibility code for old color pattern names
- Fixed Vietnamese text encoding issues in config.lua comments
- Fixed account reset mechanism to ensure the script correctly resets to account 1 after processing all accounts
- Added safety mechanisms to prevent infinite loops and ensure account state is reset properly
- Added critical project rule: Git operations require explicit user instruction before execution
- Added suppressNotification parameter to checkClaimButton and tapClaimButton to hide notifications when claim button not found
- Enhanced error suppression to completely silence both UI notifications and log file entries:
  - Updated logger.lua to add a suppress parameter that prevents both screen and file logging
  - Modified error_handler.lua to pass the suppress parameter through to the logger
  - Enhanced rewards_live.lua to properly propagate suppressNotification to all error handling calls
  - Updated auto_tiktok.lua to use suppressNotification=true where appropriate
  - Fixed bug where errors were still being logged to files even when UI notifications were suppressed
- Refactored duplicated swipe implementations:
  - Replaced manual swipe code in auto_tiktok.lua with calls to utils.swipeNextVideo()
  - Updated rewards_live.switchToNextStream to use utils.swipeNextVideo() instead of custom swipe implementation
  - Removed redundant rewards_live.checkAndClosePopup as it was just re-exporting utils.checkAndClosePopup

## Active Decisions and Considerations

- The script should work reliably across multiple accounts without manual intervention
- User experience should be smooth with clear logging and status updates
- After processing all accounts, the system should properly reset to account 1 for the next run
- The system should gracefully handle edge cases and errors
- Version control operations (commit/push) will only be performed when explicitly instructed
- Error notifications should be completely suppressed for expected "not found" scenarios (especially for claim buttons) 