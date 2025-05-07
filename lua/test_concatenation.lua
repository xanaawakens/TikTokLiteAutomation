-- Test script for safeToString implementation
require("TSLib")
local utils = require("utils")
local logger = require("logger")

-- Test with different types of values
local values = {
    nil,                             -- nil
    "string value",                  -- string
    123,                             -- number
    true,                            -- boolean
    {key = "value"},                 -- table
    {1, 2, 3, nested = {a = 1}},     -- table with nesting
    function() end,                  -- function
    -- userdata and thread are not easily created in this context
}

-- Test using safeToString directly
print("\n--- Testing safeToString directly ---")
for i, value in ipairs(values) do
    local valueType = type(value)
    local converted = utils.safeToString(value)
    print(string.format("%d. Type: %s, Converted: %s", i, valueType, converted))
end

-- Test using string concatenation
print("\n--- Testing string concatenation ---")
for i, value in ipairs(values) do
    local valueType = type(value)
    local result = "Prefix: " .. utils.safeToString(value) .. " :Suffix"
    print(string.format("%d. Type: %s, Result: %s", i, valueType, result))
end

-- Test using logger.lua
print("\n--- Testing logger ---")
for i, value in ipairs(values) do
    local valueType = type(value)
    print(string.format("%d. Type: %s", i, valueType))
    logger.info("Logging " .. utils.safeToString(value))
end

print("\n--- Testing error-prone concatenation (would fail without safeToString) ---")
local tableValue = {a = 1, b = 2}
print("Safe: " .. utils.safeToString(tableValue))

print("\nAll tests completed successfully!")
