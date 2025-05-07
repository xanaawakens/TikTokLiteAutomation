require("TSLib")
require("config")
require("utils")
local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    -- 4. Vuốt sang video khác
local startY = math.floor(height * 0.9)   
local endY = math.floor(height * 0.6)   
local midX = math.floor(width / 2)
touchDown(1, midX, startY)
mSleep(100)
for i = 1, 10 do
    local moveY = startY - (i * (startY - endY) / 10)
    touchMove(1, midX, moveY)
    mSleep(10)
end
touchUp(1, midX, endY)
mSleep(1000)