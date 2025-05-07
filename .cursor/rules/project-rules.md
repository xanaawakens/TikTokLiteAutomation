# TikTok Lite Automation Project Rules

## Code Organization
- Lua modules should follow the module pattern (local table, functions, return)
- Keep related functionality in the same module
- Use clear, descriptive function names in Vietnamese or English
- File names should reflect their purpose and content

## Error Handling
- Functions should return `(success, result_or_error)` tuples
- Use descriptive error messages that include what failed and why
- Handle unexpected states gracefully
- Log errors with sufficient context for diagnosis
- UI element descriptions can be hidden by setting `logErrors=false` in UI detection functions
- Use `suppressNotification=true` with `checkClaimButton` and `tapClaimButton` to completely suppress error notifications when claim button is not found

## UI Automation
- Use color pattern detection as the primary means of identifying UI elements
- Have fallback mechanisms when primary detection fails
- Use image recognition for complex UI elements
- Include appropriate delays after UI interactions
- Set `logErrors=false` when checking for UI elements to completely suppress error logging and notifications

## Configuration
- All configurable values should be in config.lua
- Use default values when configuration is not provided
- Group related configuration values together
- Use descriptive names for configuration keys
- All color patterns are now organized under config.color_patterns and old compatibility names have been removed

## Version Control Practices
- **CRITICAL RULE**: Commits and pushes must ONLY be performed when explicitly instructed by the user
- Wait for specific instruction phrases like "commit these changes" or "push to repository" 
- Never automatically commit or push code changes as part of other operations
- Always show staged changes before committing and wait for confirmation
- Commit messages should follow the standard format and be approved by user
- Specific Git workflow commands (checkout, branch, merge) also require explicit user instruction

## Logging
- Use `toast` for user-visible messages
- Use `nLog` for technical debugging
- Log to file for persistent records
- Take screenshots on errors

## Testing
- Test on different device sizes
- Verify detection patterns after TikTok Lite updates
- Test the full workflow with different accounts
- Validate error recovery paths

## Documentation
- Document public functions with purpose and parameters
- Include examples for complex functions
- Maintain architecture documentation
- Document known issues and workarounds

## Performance
- Minimize unnecessary sleep/delay times
- Batch UI interactions when possible
- Use efficient detection patterns
- Avoid unnecessary screen captures

## Security
- Do not hardcode sensitive information
- Protect account credentials
- Handle failures securely
- Respect TikTok Lite's terms of service

## Project-Specific Conventions
- Vietnamese function and variable names are acceptable
- Comments can be in Vietnamese
- Use `mSleep` for timing delays
- Use utils.lua for common functionality

## Runtime Configuration
- account_runtime and total_runtime are set to effectively unlimited values (99999999 seconds)
- Timing limits are primarily controlled through config.lua
- Account switching continues even if error occurs with one account
- The system runs until all accounts are processed or manually stopped
- Account reset mechanism now ensures that after processing the last account, the system resets to account 1 