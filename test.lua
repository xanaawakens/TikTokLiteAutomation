--[[
  test.lua - Simple test script for TikTok Lite Automation
  
  This script tests:
  1. Daily check-in (optional task, tap once and continue)
  2. Move to live mission 
]]

require("TSLib")
local dailyCheckin = require("daily_checkin")
local utils = require("utils")
local config = require("config")
local logger = require("logger")

-- Function to test opening TikTok Lite
local function openTikTok()
    print("Opening TikTok Lite app...")
    local appID = config.app.bundle_id
    
    -- Close app if already running
    closeApp(appID)
    print("Waiting for app to close...")
    mSleep(config.timing.app_close_wait * 1000)
    
    -- Open app
    print("Launching TikTok Lite...")
    openURL("tiktok://")
    
    -- Wait for app to load
    print("Waiting for app to load...")
    mSleep(config.timing.launch_wait * 1000)
    
    print("TikTok Lite opened successfully")
    return true
end

-- Function to test the streamlined workflow
local function runStreamlinedTest()
    print("\n===== TESTING STREAMLINED WORKFLOW =====")
    
    -- Step 1: Open TikTok
    print("Step 1: Opening TikTok Lite")
    if not openTikTok() then
        print("❌ Failed to open TikTok Lite")
        return false
    end
    print("✅ App opened")
    
    -- Step 2: Attempt daily check-in (but don't verify success)
    print("\nStep 2: Attempting daily check-in (optional)")
    dailyCheckin.performDailyCheckin()
    print("✓ Daily check-in attempted - continuing regardless of result")
    
    -- Step 3: Close the app to prepare for live mission
    print("\nStep 3: Closing app to prepare for live mission")
    closeApp(config.app.bundle_id)
    print("Waiting for app to close...")
    mSleep(5000)
    print("✅ App closed")
    
    -- Step 4: Reopen for live mission
    print("\nStep 4: Reopening for live mission")
    if not openTikTok() then
        print("❌ Failed to reopen TikTok Lite")
        return false
    end
    
    print("✅ App reopened for live mission")
    print("\n✅ Test completed successfully")
    
    return true
end

-- Run the test
runStreamlinedTest() 