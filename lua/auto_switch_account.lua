require("TSLib")
local config = require("config")
local utils = require("utils")

-- Hàm xử lý lỗi với khả năng thử lại
function handleError(message, retryFunction, maxRetries)
    maxRetries = maxRetries or 1
    local retryCount = 0
    
    toast(message)
    
    while retryCount < maxRetries do
        retryCount = retryCount + 1
        toast("Thử lại lần " .. retryCount .. "/" .. maxRetries)
        
        local success = retryFunction()
        if success then
            return success
        end
        
        mSleep(1000)  -- Đợi 1 giây trước khi thử lại
    end
    
    return false
end

-- Mở ứng dụng ADManager
function openADManager()
    local bundleID = config.admanager.bundle_id
    
    toast("Đang mở Apps Manager")
    
    -- Đóng app nếu đang chạy để mở lại từ đầu
    if appIsRunning(bundleID) then
        closeApp(bundleID)
        mSleep(2000)
    end
    
    -- Mở ứng dụng ADManager
    local openResult = runApp(bundleID)
    
    if not openResult then
        toast("Lỗi: Không thể mở Apps Manager")
        return false
    end
    
    -- Đợi app khởi động
    mSleep(3000)
    
    -- Kiểm tra app có ở foreground không
    if not isFrontApp(bundleID) then
        toast("Apps Manager không ở foreground sau khi mở")
        return false
    end
    
    return true
end

-- Tìm và bấm vào danh sách các ứng dụng
function clickAppsList()
    local coord = config.admanager.app_list_coord
    
    toast("Bấm vào danh sách ứng dụng")
    tap(coord[1], coord[2])
    mSleep(2000)
    
    return true
end

-- Tìm và bấm vào ứng dụng TikTok Lite bằng tìm kiếm màu sắc
function findAndClickTikTokIcon()
    toast("Đang tìm biểu tượng TikTok Lite bằng mẫu màu")
    
    -- Màu chính và các điểm offset
    local mainColor = 0x000000  -- Màu chính là màu đen
    local mainX = 41
    local mainY = 357
    
    -- Chuỗi offset từ điểm chính
    local offsetStr = "23|-3|0x000000,42|1|0x000000,45|43|0x000000,14|44|0x000000,9|23|0xffffff,26|38|0xfeffff,26|37|0xfeffff,27|11|0xffffff,31|15|0xffffff"
    
    -- Lấy kích thước màn hình
    local width, height = getScreenSize()
    
    -- Tìm kiếm mẫu màu trên màn hình
    local x, y = findMultiColorInRegionFuzzy(mainColor, offsetStr, config.accuracy.color_similarity, 0, 0, width, height)
    
    if x ~= -1 and y ~= -1 then
        toast("Đã tìm thấy biểu tượng TikTok Lite ở vị trí: " .. x .. ", " .. y)
        tap(x, y)
        mSleep(2000)
        return true
    else
        toast("Không tìm thấy biểu tượng TikTok Lite")
        
        -- Thử tìm kiếm lại với mẫu màu thay thế
        -- (Mẫu này dựa trên chuỗi gốc của người dùng: 41,357,0x00000064,354,0x00000083,358,0x00000086,400,0x00000039,401,0x00000055,380,0xffffff50,395,0xfeffff67,394,0xfeffff68,368,0xffffff79,372,0xffffff)
        mainColor = 0x000000
        mainX = 41
        mainY = 357
        
        offsetStr = ""
        local offsets = {
            {64-41, 354-357, 0x000000},
            {83-41, 358-357, 0x000000},
            {86-41, 400-357, 0x000000},
            {39-41, 401-357, 0x000000},
            {55-41, 380-357, 0xffffff},
            {50-41, 395-357, 0xfeffff},
            {67-41, 394-357, 0xfeffff},
            {68-41, 368-357, 0xffffff},
            {79-41, 372-357, 0xffffff}
        }
        
        for i, offset in ipairs(offsets) do
            offsetStr = offsetStr .. offset[1] .. "|" .. offset[2] .. "|" .. string.format("0x%06X", offset[3])
            if i < #offsets then
                offsetStr = offsetStr .. ","
            end
        end
        
        -- Tìm kiếm với mẫu màu thay thế
        x, y = findMultiColorInRegionFuzzy(mainColor, offsetStr, config.accuracy.color_similarity, 0, 0, width, height)
        
        if x ~= -1 and y ~= -1 then
            toast("Đã tìm thấy biểu tượng TikTok Lite với mẫu thay thế ở vị trí: " .. x .. ", " .. y)
            tap(x, y)
            mSleep(2000)
            return true
        else
            toast("Không tìm thấy biểu tượng TikTok Lite với cả hai mẫu màu")
            return false
        end
    end
end


-- Tìm backup có số thứ tự từ 1-50
-- 1	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 2	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 3	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 4	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 5	:	48,457,0x007aff,37,457,0x007aff,36,463,0x007aff,36,468,0x007aff,43,464,0x5facff,50,472,0x278eff,42,478,0x007aff,35,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 6	:	49,461,0x69b1ff,42,456,0x007aff,37,461,0x007aff,36,471,0x007aff,44,478,0x007aff,50,473,0x007aff,43,466,0x0d81ff,38,468,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 7	:	35,457,0x007aff,44,457,0x007aff,48,457,0x007aff,45,463,0x007aff,44,465,0x007aff,41,471,0x007aff,39,475,0x007aff,37,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 8	:	41,467,0x007aff,36,461,0x007aff,42,456,0x007aff,49,461,0x007aff,44,467,0x007aff,50,474,0x007aff,43,479,0x007aff,35,473,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 9	:	48,467,0x007aff,41,470,0x007aff,35,463,0x007aff,41,456,0x007aff,49,463,0x007aff,48,474,0x007aff,42,479,0x007aff,37,476,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff
-- 10	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,57,456,0x007aff,64,469,0x007aff,61,477,0x007aff,57,479,0x007aff,49,466,0x007aff,52,459,0x007aff
-- 11	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,49,461,0x007aff,51,459,0x007aff,56,456,0x0b80ff,56,466,0x007aff,55,473,0x007aff,56,479,0x007aff,57,479,0x7abaff
-- 12	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,49,462,0x3194ff,57,456,0x007aff,63,463,0x73b6ff,56,470,0x007aff,50,478,0x007aff,58,478,0x007aff,62,478,0x007aff
-- 13	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,50,461,0x007aff,57,456,0x007aff,63,461,0x007aff,55,467,0x007aff,62,474,0x007aff,57,478,0x007aff,50,476,0x007aff,50,475,0x007aff
-- 14	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,65,473,0x0f82ff,49,473,0x007aff,52,467,0x007aff,56,460,0x007aff,60,456,0x0b80ff,61,473,0x007aff,61,478,0x007aff
-- 15	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,63,457,0x73b6ff,56,456,0x0b80ff,51,458,0x007aff,51,464,0x047cff,50,468,0x007aff,57,465,0x007aff,64,472,0x278eff,56,479,0x007aff,49,475,0x037cff
-- 16	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,63,461,0x69b1ff,57,457,0x007aff,51,460,0x007aff,49,469,0x007aff,52,477,0x007aff,57,479,0x007aff,64,473,0x007aff,61,467,0x007aff,56,465,0x007aff,53,467,0x007aff
-- 17	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,47,457,0x9ccbff,52,457,0x007aff,61,457,0x007aff,61,460,0x007aff,57,466,0x007aff,54,471,0x1283ff,51,479,0x007aff
-- 18	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,56,467,0x007aff,50,461,0x007aff,56,456,0x007aff,63,460,0x007aff,61,465,0x007aff,63,472,0x007aff,62,477,0x007aff,57,479,0x007aff,50,476,0x007aff,50,472,0x007aff
-- 19	:	34,461,0x2c91ff,36,460,0x007aff,39,458,0x007aff,41,456,0x0b80ff,41,462,0x007aff,41,470,0x007aff,41,479,0x007aff,43,479,0x7abaff,37,458,0x3f9bff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,61,467,0x007aff,56,470,0x007aff,52,468,0x007aff,49,464,0x007aff,56,456,0x007aff,62,460,0x007aff,64,470,0x007aff,61,475,0x047cff,57,478,0x007aff,50,474,0x74b7ff
-- 20	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,57,456,0x007aff,64,469,0x007aff,61,477,0x007aff,57,479,0x007aff,49,466,0x007aff,52,459,0x007aff
-- 21	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,49,461,0x007aff,51,459,0x007aff,56,456,0x0b80ff,56,466,0x007aff,55,473,0x007aff,56,479,0x007aff,57,479,0x7abaff
-- 22	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,49,462,0x3194ff,57,456,0x007aff,63,463,0x73b6ff,56,470,0x007aff,50,478,0x007aff,58,478,0x007aff,62,478,0x007aff
-- 23	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,50,461,0x007aff,57,456,0x007aff,63,461,0x007aff,55,467,0x007aff,62,474,0x007aff,57,478,0x007aff,50,476,0x007aff,50,475,0x007aff
-- 24	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,65,473,0x0f82ff,49,473,0x007aff,52,467,0x007aff,56,460,0x007aff,60,456,0x0b80ff,61,473,0x007aff,61,478,0x007aff
-- 25	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,63,457,0x73b6ff,56,456,0x0b80ff,51,458,0x007aff,51,464,0x047cff,50,468,0x007aff,57,465,0x007aff,64,472,0x278eff,56,479,0x007aff,49,475,0x037cff
-- 26	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,63,461,0x69b1ff,57,457,0x007aff,51,460,0x007aff,49,469,0x007aff,52,477,0x007aff,57,479,0x007aff,64,473,0x007aff,61,467,0x007aff,56,465,0x007aff,53,467,0x007aff
-- 27	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,47,457,0x9ccbff,52,457,0x007aff,61,457,0x007aff,61,460,0x007aff,57,466,0x007aff,54,471,0x1283ff,51,479,0x007aff
-- 28	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,56,467,0x007aff,50,461,0x007aff,56,456,0x007aff,63,460,0x007aff,61,465,0x007aff,63,472,0x007aff,62,477,0x007aff,57,479,0x007aff,50,476,0x007aff,50,472,0x007aff
-- 29	:	36,462,0x3093ff,39,457,0x007aff,42,455,0x82beff,48,461,0x007aff,40,472,0x037cff,36,479,0x007aff,49,478,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,61,467,0x007aff,56,470,0x007aff,52,468,0x007aff,49,464,0x007aff,56,456,0x007aff,62,460,0x007aff,64,470,0x007aff,61,475,0x047cff,57,478,0x007aff,50,474,0x74b7ff
-- 30	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,57,456,0x007aff,64,469,0x007aff,61,477,0x007aff,57,479,0x007aff,49,466,0x007aff,52,459,0x007aff
-- 31	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,49,461,0x007aff,51,459,0x007aff,56,456,0x0b80ff,56,466,0x007aff,55,473,0x007aff,56,479,0x007aff,57,479,0x7abaff
-- 32	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,49,462,0x3194ff,57,456,0x007aff,63,463,0x73b6ff,56,470,0x007aff,50,478,0x007aff,58,478,0x007aff,62,478,0x007aff
-- 33	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,50,461,0x007aff,57,456,0x007aff,63,461,0x007aff,55,467,0x007aff,62,474,0x007aff,57,478,0x007aff,50,476,0x007aff,50,475,0x007aff
-- 34	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,65,473,0x0f82ff,49,473,0x007aff,52,467,0x007aff,56,460,0x007aff,60,456,0x0b80ff,61,473,0x007aff,61,478,0x007aff
-- 35	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,63,457,0x73b6ff,56,456,0x0b80ff,51,458,0x007aff,51,464,0x047cff,50,468,0x007aff,57,465,0x007aff,64,472,0x278eff,56,479,0x007aff,49,475,0x037cff
-- 36	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,63,461,0x69b1ff,57,457,0x007aff,51,460,0x007aff,49,469,0x007aff,52,477,0x007aff,57,479,0x007aff,64,473,0x007aff,61,467,0x007aff,56,465,0x007aff,53,467,0x007aff
-- 37	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,47,457,0x9ccbff,52,457,0x007aff,61,457,0x007aff,61,460,0x007aff,57,466,0x007aff,54,471,0x1283ff,51,479,0x007aff
-- 38	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,56,467,0x007aff,50,461,0x007aff,56,456,0x007aff,63,460,0x007aff,61,465,0x007aff,63,472,0x007aff,62,477,0x007aff,57,479,0x007aff,50,476,0x007aff,50,472,0x007aff
-- 39	:	36,462,0xaed5ff,39,458,0x017bff,42,456,0x007aff,48,461,0x007aff,43,467,0x007aff,50,474,0x057dff,42,479,0x007aff,36,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,61,467,0x007aff,56,470,0x007aff,52,468,0x007aff,49,464,0x007aff,56,456,0x007aff,62,460,0x007aff,64,470,0x007aff,61,475,0x047cff,57,478,0x007aff,50,474,0x74b7ff
-- 40	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,57,456,0x007aff,64,469,0x007aff,61,477,0x007aff,57,479,0x007aff,49,466,0x007aff,52,459,0x007aff
-- 41	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,49,461,0x007aff,51,459,0x007aff,56,456,0x0b80ff,56,466,0x007aff,55,473,0x007aff,56,479,0x007aff,57,479,0x7abaff
-- 42	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,49,462,0x3194ff,57,456,0x007aff,63,463,0x73b6ff,56,470,0x007aff,50,478,0x007aff,58,478,0x007aff,62,478,0x007aff
-- 43	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,50,461,0x007aff,57,456,0x007aff,63,461,0x007aff,55,467,0x007aff,62,474,0x007aff,57,478,0x007aff,50,476,0x007aff,50,475,0x007aff
-- 44	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,65,473,0x0f82ff,49,473,0x007aff,52,467,0x007aff,56,460,0x007aff,60,456,0x0b80ff,61,473,0x007aff,61,478,0x007aff
-- 45	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,63,457,0x73b6ff,56,456,0x0b80ff,51,458,0x007aff,51,464,0x047cff,50,468,0x007aff,57,465,0x007aff,64,472,0x278eff,56,479,0x007aff,49,475,0x037cff
-- 46	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,63,461,0x69b1ff,57,457,0x007aff,51,460,0x007aff,49,469,0x007aff,52,477,0x007aff,57,479,0x007aff,64,473,0x007aff,61,467,0x007aff,56,465,0x007aff,53,467,0x007aff
-- 47	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,47,457,0x9ccbff,52,457,0x007aff,61,457,0x007aff,61,460,0x007aff,57,466,0x007aff,54,471,0x1283ff,51,479,0x007aff
-- 48	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,56,467,0x007aff,50,461,0x007aff,56,456,0x007aff,63,460,0x007aff,61,465,0x007aff,63,472,0x007aff,62,477,0x007aff,57,479,0x007aff,50,476,0x007aff,50,472,0x007aff
-- 49	:	51,473,0x0f82ff,35,473,0x007aff,40,464,0x007aff,47,456,0x0b80ff,47,464,0x007aff,47,473,0x007aff,47,479,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,61,467,0x007aff,56,470,0x007aff,52,468,0x007aff,49,464,0x007aff,56,456,0x007aff,62,460,0x007aff,64,470,0x007aff,61,475,0x047cff,57,478,0x007aff,50,474,0x74b7ff
-- 50	:	48,457,0x007aff,37,457,0x007aff,36,463,0x007aff,36,468,0x007aff,43,464,0x5facff,50,472,0x278eff,42,478,0x007aff,35,474,0x007aff,57,456,0xffffff,64,469,0xffffff,61,477,0xffffff,57,479,0xffffff,49,466,0xffffff,52,459,0xffffff,57,456,0x007aff,64,469,0x007aff,61,477,0x007aff,57,479,0x007aff,49,466,0x007aff,52,459,0x007aff
function findBackupNumber(number)
    if number < 1 or number > 50 then
        toast("Số backup phải từ 1-50")
        return false, 0, 0
    end

    -- Định nghĩa ma trận màu cho các số 1-50
    local matrix_color_number = {
        -- Số 1
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 2
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 3
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 4
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 5
        {
            {x = 48, y = 457, color = 0x007aff},
            {x = 37, y = 457, color = 0x007aff},
            {x = 36, y = 463, color = 0x007aff},
            {x = 36, y = 468, color = 0x007aff},
            {x = 43, y = 464, color = 0x5facff},
            {x = 50, y = 472, color = 0x278eff},
            {x = 42, y = 478, color = 0x007aff},
            {x = 35, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 6
        {
            {x = 49, y = 461, color = 0x69b1ff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 37, y = 461, color = 0x007aff},
            {x = 36, y = 471, color = 0x007aff},
            {x = 44, y = 478, color = 0x007aff},
            {x = 50, y = 473, color = 0x007aff},
            {x = 43, y = 466, color = 0x0d81ff},
            {x = 38, y = 468, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 7
        {
            {x = 35, y = 457, color = 0x007aff},
            {x = 44, y = 457, color = 0x007aff},
            {x = 48, y = 457, color = 0x007aff},
            {x = 45, y = 463, color = 0x007aff},
            {x = 44, y = 465, color = 0x007aff},
            {x = 41, y = 471, color = 0x007aff},
            {x = 39, y = 475, color = 0x007aff},
            {x = 37, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 8
        {
            {x = 41, y = 467, color = 0x007aff},
            {x = 36, y = 461, color = 0x007aff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 49, y = 461, color = 0x007aff},
            {x = 44, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x007aff},
            {x = 43, y = 479, color = 0x007aff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 9
        {
            {x = 48, y = 467, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 35, y = 463, color = 0x007aff},
            {x = 41, y = 456, color = 0x007aff},
            {x = 49, y = 463, color = 0x007aff},
            {x = 48, y = 474, color = 0x007aff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 37, y = 476, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff}
        },
        -- Số 10
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 64, y = 469, color = 0x007aff},
            {x = 61, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 49, y = 466, color = 0x007aff},
            {x = 52, y = 459, color = 0x007aff}
        },
        -- Số 11
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 49, y = 461, color = 0x007aff},
            {x = 51, y = 459, color = 0x007aff},
            {x = 56, y = 456, color = 0x0b80ff},
            {x = 56, y = 466, color = 0x007aff},
            {x = 55, y = 473, color = 0x007aff},
            {x = 56, y = 479, color = 0x007aff},
            {x = 57, y = 479, color = 0x7abaff}
        },
        -- Số 12
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 49, y = 462, color = 0x3194ff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 63, y = 463, color = 0x73b6ff},
            {x = 56, y = 470, color = 0x007aff},
            {x = 50, y = 478, color = 0x007aff},
            {x = 58, y = 478, color = 0x007aff},
            {x = 62, y = 478, color = 0x007aff}
        },
        -- Số 13
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 50, y = 461, color = 0x007aff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 63, y = 461, color = 0x007aff},
            {x = 55, y = 467, color = 0x007aff},
            {x = 62, y = 474, color = 0x007aff},
            {x = 57, y = 478, color = 0x007aff},
            {x = 50, y = 476, color = 0x007aff},
            {x = 50, y = 475, color = 0x007aff}
        },
        -- Số 14
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 65, y = 473, color = 0x0f82ff},
            {x = 49, y = 473, color = 0x007aff},
            {x = 52, y = 467, color = 0x007aff},
            {x = 56, y = 460, color = 0x007aff},
            {x = 60, y = 456, color = 0x0b80ff},
            {x = 61, y = 473, color = 0x007aff},
            {x = 61, y = 478, color = 0x007aff}
        },
        -- Số 15
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 63, y = 457, color = 0x73b6ff},
            {x = 56, y = 456, color = 0x0b80ff},
            {x = 51, y = 458, color = 0x007aff},
            {x = 51, y = 464, color = 0x047cff},
            {x = 50, y = 468, color = 0x007aff},
            {x = 57, y = 465, color = 0x007aff},
            {x = 64, y = 472, color = 0x278eff},
            {x = 56, y = 479, color = 0x007aff},
            {x = 49, y = 475, color = 0x037cff}
        },
        -- Số 16
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 63, y = 461, color = 0x69b1ff},
            {x = 57, y = 457, color = 0x007aff},
            {x = 51, y = 460, color = 0x007aff},
            {x = 49, y = 469, color = 0x007aff},
            {x = 52, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 64, y = 473, color = 0x007aff},
            {x = 61, y = 467, color = 0x007aff},
            {x = 56, y = 465, color = 0x007aff},
            {x = 53, y = 467, color = 0x007aff}
        },
        -- Số 17
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 47, y = 457, color = 0x9ccbff},
            {x = 52, y = 457, color = 0x007aff},
            {x = 61, y = 457, color = 0x007aff},
            {x = 61, y = 460, color = 0x007aff},
            {x = 57, y = 466, color = 0x007aff},
            {x = 54, y = 471, color = 0x1283ff},
            {x = 51, y = 479, color = 0x007aff}
        },
        -- Số 18
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 56, y = 467, color = 0x007aff},
            {x = 50, y = 461, color = 0x007aff},
            {x = 56, y = 456, color = 0x007aff},
            {x = 63, y = 460, color = 0x007aff},
            {x = 61, y = 465, color = 0x007aff},
            {x = 63, y = 472, color = 0x007aff},
            {x = 62, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 50, y = 476, color = 0x007aff},
            {x = 50, y = 472, color = 0x007aff}
        },
        -- Số 19
        {
            {x = 34, y = 461, color = 0x2c91ff},
            {x = 36, y = 460, color = 0x007aff},
            {x = 39, y = 458, color = 0x007aff},
            {x = 41, y = 456, color = 0x0b80ff},
            {x = 41, y = 462, color = 0x007aff},
            {x = 41, y = 470, color = 0x007aff},
            {x = 41, y = 479, color = 0x007aff},
            {x = 43, y = 479, color = 0x7abaff},
            {x = 37, y = 458, color = 0x3f9bff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 61, y = 467, color = 0x007aff},
            {x = 56, y = 470, color = 0x007aff},
            {x = 52, y = 468, color = 0x007aff},
            {x = 49, y = 464, color = 0x007aff},
            {x = 56, y = 456, color = 0x007aff},
            {x = 62, y = 460, color = 0x007aff},
            {x = 64, y = 470, color = 0x007aff},
            {x = 61, y = 475, color = 0x047cff},
            {x = 57, y = 478, color = 0x007aff},
            {x = 50, y = 474, color = 0x74b7ff}
        },
        -- Số 20
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 64, y = 469, color = 0x007aff},
            {x = 61, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 49, y = 466, color = 0x007aff},
            {x = 52, y = 459, color = 0x007aff}
        },
        -- Số 21
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 49, y = 461, color = 0x007aff},
            {x = 51, y = 459, color = 0x007aff},
            {x = 56, y = 456, color = 0x0b80ff},
            {x = 56, y = 466, color = 0x007aff},
            {x = 55, y = 473, color = 0x007aff},
            {x = 56, y = 479, color = 0x007aff},
            {x = 57, y = 479, color = 0x7abaff}
        },
        -- Số 22
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 49, y = 462, color = 0x3194ff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 63, y = 463, color = 0x73b6ff},
            {x = 56, y = 470, color = 0x007aff},
            {x = 50, y = 478, color = 0x007aff},
            {x = 58, y = 478, color = 0x007aff},
            {x = 62, y = 478, color = 0x007aff}
        },
        -- Số 23
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 50, y = 461, color = 0x007aff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 63, y = 461, color = 0x007aff},
            {x = 55, y = 467, color = 0x007aff},
            {x = 62, y = 474, color = 0x007aff},
            {x = 57, y = 478, color = 0x007aff},
            {x = 50, y = 476, color = 0x007aff},
            {x = 50, y = 475, color = 0x007aff}
        },
        -- Số 24
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 65, y = 473, color = 0x0f82ff},
            {x = 49, y = 473, color = 0x007aff},
            {x = 52, y = 467, color = 0x007aff},
            {x = 56, y = 460, color = 0x007aff},
            {x = 60, y = 456, color = 0x0b80ff},
            {x = 61, y = 473, color = 0x007aff},
            {x = 61, y = 478, color = 0x007aff}
        },
        -- Số 25
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 63, y = 457, color = 0x73b6ff},
            {x = 56, y = 456, color = 0x0b80ff},
            {x = 51, y = 458, color = 0x007aff},
            {x = 51, y = 464, color = 0x047cff},
            {x = 50, y = 468, color = 0x007aff},
            {x = 57, y = 465, color = 0x007aff},
            {x = 64, y = 472, color = 0x278eff},
            {x = 56, y = 479, color = 0x007aff},
            {x = 49, y = 475, color = 0x037cff}
        },
        -- Số 26
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 63, y = 461, color = 0x69b1ff},
            {x = 57, y = 457, color = 0x007aff},
            {x = 51, y = 460, color = 0x007aff},
            {x = 49, y = 469, color = 0x007aff},
            {x = 52, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 64, y = 473, color = 0x007aff},
            {x = 61, y = 467, color = 0x007aff},
            {x = 56, y = 465, color = 0x007aff},
            {x = 53, y = 467, color = 0x007aff}
        },
        -- Số 27
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 47, y = 457, color = 0x9ccbff},
            {x = 52, y = 457, color = 0x007aff},
            {x = 61, y = 457, color = 0x007aff},
            {x = 61, y = 460, color = 0x007aff},
            {x = 57, y = 466, color = 0x007aff},
            {x = 54, y = 471, color = 0x1283ff},
            {x = 51, y = 479, color = 0x007aff}
        },
        -- Số 28
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 56, y = 467, color = 0x007aff},
            {x = 50, y = 461, color = 0x007aff},
            {x = 56, y = 456, color = 0x007aff},
            {x = 63, y = 460, color = 0x007aff},
            {x = 61, y = 465, color = 0x007aff},
            {x = 63, y = 472, color = 0x007aff},
            {x = 62, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 50, y = 476, color = 0x007aff},
            {x = 50, y = 472, color = 0x007aff}
        },
        -- Số 29
        {
            {x = 36, y = 462, color = 0x3093ff},
            {x = 39, y = 457, color = 0x007aff},
            {x = 42, y = 455, color = 0x82beff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 40, y = 472, color = 0x037cff},
            {x = 36, y = 479, color = 0x007aff},
            {x = 49, y = 478, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 61, y = 467, color = 0x007aff},
            {x = 56, y = 470, color = 0x007aff},
            {x = 52, y = 468, color = 0x007aff},
            {x = 49, y = 464, color = 0x007aff},
            {x = 56, y = 456, color = 0x007aff},
            {x = 62, y = 460, color = 0x007aff},
            {x = 64, y = 470, color = 0x007aff},
            {x = 61, y = 475, color = 0x047cff},
            {x = 57, y = 478, color = 0x007aff},
            {x = 50, y = 474, color = 0x74b7ff}
        },
        -- Số 30
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 64, y = 469, color = 0x007aff},
            {x = 61, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 49, y = 466, color = 0x007aff},
            {x = 52, y = 459, color = 0x007aff}
        },
        -- Số 31
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 49, y = 461, color = 0x007aff},
            {x = 51, y = 459, color = 0x007aff},
            {x = 56, y = 456, color = 0x0b80ff},
            {x = 56, y = 466, color = 0x007aff},
            {x = 55, y = 473, color = 0x007aff},
            {x = 56, y = 479, color = 0x007aff},
            {x = 57, y = 479, color = 0x7abaff}
        },
        -- Số 32
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 49, y = 462, color = 0x3194ff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 63, y = 463, color = 0x73b6ff},
            {x = 56, y = 470, color = 0x007aff},
            {x = 50, y = 478, color = 0x007aff},
            {x = 58, y = 478, color = 0x007aff},
            {x = 62, y = 478, color = 0x007aff}
        },
        -- Số 33
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 50, y = 461, color = 0x007aff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 63, y = 461, color = 0x007aff},
            {x = 55, y = 467, color = 0x007aff},
            {x = 62, y = 474, color = 0x007aff},
            {x = 57, y = 478, color = 0x007aff},
            {x = 50, y = 476, color = 0x007aff},
            {x = 50, y = 475, color = 0x007aff}
        },
        -- Số 34
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 65, y = 473, color = 0x0f82ff},
            {x = 49, y = 473, color = 0x007aff},
            {x = 52, y = 467, color = 0x007aff},
            {x = 56, y = 460, color = 0x007aff},
            {x = 60, y = 456, color = 0x0b80ff},
            {x = 61, y = 473, color = 0x007aff},
            {x = 61, y = 478, color = 0x007aff}
        },
        -- Số 35
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 63, y = 457, color = 0x73b6ff},
            {x = 56, y = 456, color = 0x0b80ff},
            {x = 51, y = 458, color = 0x007aff},
            {x = 51, y = 464, color = 0x047cff},
            {x = 50, y = 468, color = 0x007aff},
            {x = 57, y = 465, color = 0x007aff},
            {x = 64, y = 472, color = 0x278eff},
            {x = 56, y = 479, color = 0x007aff},
            {x = 49, y = 475, color = 0x037cff}
        },
        -- Số 36
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 63, y = 461, color = 0x69b1ff},
            {x = 57, y = 457, color = 0x007aff},
            {x = 51, y = 460, color = 0x007aff},
            {x = 49, y = 469, color = 0x007aff},
            {x = 52, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 64, y = 473, color = 0x007aff},
            {x = 61, y = 467, color = 0x007aff},
            {x = 56, y = 465, color = 0x007aff},
            {x = 53, y = 467, color = 0x007aff}
        },
        -- Số 37
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 47, y = 457, color = 0x9ccbff},
            {x = 52, y = 457, color = 0x007aff},
            {x = 61, y = 457, color = 0x007aff},
            {x = 61, y = 460, color = 0x007aff},
            {x = 57, y = 466, color = 0x007aff},
            {x = 54, y = 471, color = 0x1283ff},
            {x = 51, y = 479, color = 0x007aff}
        },
        -- Số 38
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 56, y = 467, color = 0x007aff},
            {x = 50, y = 461, color = 0x007aff},
            {x = 56, y = 456, color = 0x007aff},
            {x = 63, y = 460, color = 0x007aff},
            {x = 61, y = 465, color = 0x007aff},
            {x = 63, y = 472, color = 0x007aff},
            {x = 62, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 50, y = 476, color = 0x007aff},
            {x = 50, y = 472, color = 0x007aff}
        },
        -- Số 39
        {
            {x = 36, y = 462, color = 0xaed5ff},
            {x = 39, y = 458, color = 0x017bff},
            {x = 42, y = 456, color = 0x007aff},
            {x = 48, y = 461, color = 0x007aff},
            {x = 43, y = 467, color = 0x007aff},
            {x = 50, y = 474, color = 0x057dff},
            {x = 42, y = 479, color = 0x007aff},
            {x = 36, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 61, y = 467, color = 0x007aff},
            {x = 56, y = 470, color = 0x007aff},
            {x = 52, y = 468, color = 0x007aff},
            {x = 49, y = 464, color = 0x007aff},
            {x = 56, y = 456, color = 0x007aff},
            {x = 62, y = 460, color = 0x007aff},
            {x = 64, y = 470, color = 0x007aff},
            {x = 61, y = 475, color = 0x047cff},
            {x = 57, y = 478, color = 0x007aff},
            {x = 50, y = 474, color = 0x74b7ff}
        },
        -- Số 40
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 64, y = 469, color = 0x007aff},
            {x = 61, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 49, y = 466, color = 0x007aff},
            {x = 52, y = 459, color = 0x007aff}
        },
        -- Số 41
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 49, y = 461, color = 0x007aff},
            {x = 51, y = 459, color = 0x007aff},
            {x = 56, y = 456, color = 0x0b80ff},
            {x = 56, y = 466, color = 0x007aff},
            {x = 55, y = 473, color = 0x007aff},
            {x = 56, y = 479, color = 0x007aff},
            {x = 57, y = 479, color = 0x7abaff}
        },
        -- Số 42
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 49, y = 462, color = 0x3194ff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 63, y = 463, color = 0x73b6ff},
            {x = 56, y = 470, color = 0x007aff},
            {x = 50, y = 478, color = 0x007aff},
            {x = 58, y = 478, color = 0x007aff},
            {x = 62, y = 478, color = 0x007aff}
        },
        -- Số 43
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 50, y = 461, color = 0x007aff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 63, y = 461, color = 0x007aff},
            {x = 55, y = 467, color = 0x007aff},
            {x = 62, y = 474, color = 0x007aff},
            {x = 57, y = 478, color = 0x007aff},
            {x = 50, y = 476, color = 0x007aff},
            {x = 50, y = 475, color = 0x007aff}
        },
        -- Số 44
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 65, y = 473, color = 0x0f82ff},
            {x = 49, y = 473, color = 0x007aff},
            {x = 52, y = 467, color = 0x007aff},
            {x = 56, y = 460, color = 0x007aff},
            {x = 60, y = 456, color = 0x0b80ff},
            {x = 61, y = 473, color = 0x007aff},
            {x = 61, y = 478, color = 0x007aff}
        },
        -- Số 45
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 63, y = 457, color = 0x73b6ff},
            {x = 56, y = 456, color = 0x0b80ff},
            {x = 51, y = 458, color = 0x007aff},
            {x = 51, y = 464, color = 0x047cff},
            {x = 50, y = 468, color = 0x007aff},
            {x = 57, y = 465, color = 0x007aff},
            {x = 64, y = 472, color = 0x278eff},
            {x = 56, y = 479, color = 0x007aff},
            {x = 49, y = 475, color = 0x037cff}
        },
        -- Số 46
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 63, y = 461, color = 0x69b1ff},
            {x = 57, y = 457, color = 0x007aff},
            {x = 51, y = 460, color = 0x007aff},
            {x = 49, y = 469, color = 0x007aff},
            {x = 52, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 64, y = 473, color = 0x007aff},
            {x = 61, y = 467, color = 0x007aff},
            {x = 56, y = 465, color = 0x007aff},
            {x = 53, y = 467, color = 0x007aff}
        },
        -- Số 47
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 47, y = 457, color = 0x9ccbff},
            {x = 52, y = 457, color = 0x007aff},
            {x = 61, y = 457, color = 0x007aff},
            {x = 61, y = 460, color = 0x007aff},
            {x = 57, y = 466, color = 0x007aff},
            {x = 54, y = 471, color = 0x1283ff},
            {x = 51, y = 479, color = 0x007aff}
        },
        -- Số 48
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 56, y = 467, color = 0x007aff},
            {x = 50, y = 461, color = 0x007aff},
            {x = 56, y = 456, color = 0x007aff},
            {x = 63, y = 460, color = 0x007aff},
            {x = 61, y = 465, color = 0x007aff},
            {x = 63, y = 472, color = 0x007aff},
            {x = 62, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 50, y = 476, color = 0x007aff},
            {x = 50, y = 472, color = 0x007aff}
        },
        -- Số 49
        {
            {x = 51, y = 473, color = 0x0f82ff},
            {x = 35, y = 473, color = 0x007aff},
            {x = 40, y = 464, color = 0x007aff},
            {x = 47, y = 456, color = 0x0b80ff},
            {x = 47, y = 464, color = 0x007aff},
            {x = 47, y = 473, color = 0x007aff},
            {x = 47, y = 479, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 61, y = 467, color = 0x007aff},
            {x = 56, y = 470, color = 0x007aff},
            {x = 52, y = 468, color = 0x007aff},
            {x = 49, y = 464, color = 0x007aff},
            {x = 56, y = 456, color = 0x007aff},
            {x = 62, y = 460, color = 0x007aff},
            {x = 64, y = 470, color = 0x007aff},
            {x = 61, y = 475, color = 0x047cff},
            {x = 57, y = 478, color = 0x007aff},
            {x = 50, y = 474, color = 0x74b7ff}
        },
        -- Số 50
        {
            {x = 48, y = 457, color = 0x007aff},
            {x = 37, y = 457, color = 0x007aff},
            {x = 36, y = 463, color = 0x007aff},
            {x = 36, y = 468, color = 0x007aff},
            {x = 43, y = 464, color = 0x5facff},
            {x = 50, y = 472, color = 0x278eff},
            {x = 42, y = 478, color = 0x007aff},
            {x = 35, y = 474, color = 0x007aff},
            {x = 57, y = 456, color = 0xffffff},
            {x = 64, y = 469, color = 0xffffff},
            {x = 61, y = 477, color = 0xffffff},
            {x = 57, y = 479, color = 0xffffff},
            {x = 49, y = 466, color = 0xffffff},
            {x = 52, y = 459, color = 0xffffff},
            {x = 57, y = 456, color = 0x007aff},
            {x = 64, y = 469, color = 0x007aff},
            {x = 61, y = 477, color = 0x007aff},
            {x = 57, y = 479, color = 0x007aff},
            {x = 49, y = 466, color = 0x007aff},
            {x = 52, y = 459, color = 0x007aff}
        }
    }
    
    toast("Tìm backup số " .. number)
    
    -- Lấy mẫu màu tương ứng với số cần tìm
    local number_matrix = matrix_color_number[number]
    if not number_matrix then
        toast("Không có mẫu màu cho số " .. number)
        return false, 0, 0
    end
    
    -- Chọn điểm đầu tiên làm điểm gốc và màu chính
    local mainPoint = number_matrix[1]
    local mainColor = mainPoint.color
    local mainX = mainPoint.x
    local mainY = mainPoint.y
    
    -- Tạo chuỗi offset từ các điểm còn lại
    local offsetStr = ""
    for i = 2, #number_matrix do
        local point = number_matrix[i]
        local offsetX = point.x - mainX
        local offsetY = point.y - mainY
        
        offsetStr = offsetStr .. offsetX .. "|" .. offsetY .. "|" .. string.format("0x%06X", point.color)
        if i < #number_matrix then
            offsetStr = offsetStr .. ","
        end
    end
    
    -- Vùng tìm kiếm (chỉ 1/3 màn hình bên trái như yêu cầu)
    local width, height = getScreenSize()
    local searchLeft = 0
    local searchRight = math.floor(width / 3)
    local searchTop = 200
    local searchBottom = height - 150
    
    toast("Tìm kiếm trong vùng: " .. searchLeft .. "," .. searchTop .. " đến " .. searchRight .. "," .. searchBottom)
    
    -- Tìm kiếm mẫu màu trong vùng tìm kiếm
    local x, y = findMultiColorInRegionFuzzy(mainColor, offsetStr, 90, 
                                            searchLeft, searchTop, searchRight, searchBottom)
    
    if x ~= -1 and y ~= -1 then
        toast("Đã tìm thấy số " .. number .. " tại vị trí: " .. x .. "," .. y)
        
        -- Tọa độ bấm: giữa màn hình theo chiều ngang, giữ nguyên tọa độ y đã tìm thấy
        local tapX = 375
        local tapY = y
        return true, tapX, tapY
    else
        toast("Không tìm thấy số " .. number .. " trong vùng tìm kiếm")
        return false, 0, 0
    end
end

-- Bấm vào nút Restore AppData
function clickRestoreButton()
    -- Sử dụng tọa độ dựa trên kích thước màn hình
    local width, height = getScreenSize()
    
    -- Nút Restore thường nằm ở phía dưới màn hình
    local restoreX = 360  -- Giữa màn hình theo chiều ngang
    local restoreY = 1135  -- 85% chiều cao màn hình
    
    toast("🔘 Nhấn vào nút Restore AppData tại " .. restoreX .. "," .. restoreY)
    
    touchDown(1, restoreX, restoreY)
    mSleep(150)  -- Giữ lâu hơn
    touchUp(1, restoreX, restoreY)
    
    return true
end




-- Chuyển đổi tài khoản TikTok bằng cách khôi phục backup
function switchTikTokAccount(accountNumber)
    -- Mở ứng dụng ADManager
    if not openADManager() then
        return handleError("Không thể mở Apps Manager", function()
            mSleep(2000)
            return openADManager()
        end)
    end
    
    -- Bấm vào danh sách ứng dụng
    if not clickAppsList() then
        return handleError("Không thể bấm vào danh sách ứng dụng", function()
            mSleep(1000)
            return clickAppsList()
        end)
    end
    
    -- Tìm và bấm vào ứng dụng TikTok Lite
    if not findAndClickTikTokIcon() then
        return handleError("Không tìm thấy biểu tượng TikTok Lite", function()
            return findAndClickTikTokIcon()
        end)
    end
    
    -- Đợi màn hình danh sách backup hiển thị
    toast("Đợi màn hình backup hiển thị...")
    mSleep(3000)
    
    
    -- Kiểm tra lần đầu trước khi vuốt
    found, tapX, tapY = findBackupNumber(accountNumber)
    
    -- Bấm vào backup đã tìm thấy
    toast("Đã tìm thấy backup số " .. accountNumber .. ", đang bấm vào vị trí: " .. tapX .. ", " .. tapY)
    tap(tapX, tapY)
    mSleep(6000)

    clickRestoreButton()
    mSleep(7000)
    return true, "Đã chuyển sang tài khoản " .. accountNumber .. " thành công"
end