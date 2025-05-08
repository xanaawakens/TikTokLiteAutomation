--[[
  daily_checkin.lua - Module xử lý chức năng điểm danh hàng ngày TikTok Lite
  
  Module này chứa các hàm để:
  - Chuyển đến tab nhiệm vụ (mission)
  - Tìm kiếm nút điểm danh hàng ngày
  - Bấm vào nút điểm danh
]]

require("TSLib")
local config = require("config")
local utils = require("utils")
local logger = require("logger")
local fileManager = require("file_manager")
local errorHandler = require("error_handler")

local dailyCheckin = {}

-- Tên module để sử dụng trong log
local MODULE_NAME = "daily_checkin"

-- Thời gian chờ (giây)
local TIMING = {
    AFTER_TAP = config.timing.tap_delay or 1,  -- Thời gian chờ sau khi tap
    UI_STABILIZE = config.timing.ui_stabilize or 1.5,  -- Thời gian chờ UI ổn định
    MISSION_TAB_SEARCH = config.timing.mission_tab_search or 2, -- Thời gian chờ tìm tab nhiệm vụ
    SCROLL_DELAY = config.timing.scroll_delay or 0.5, -- Thời gian chờ giữa các lần cuộn
    ACTION_VERIFICATION = config.timing.action_verification or 3 -- Thời gian chờ để xác minh hành động
}

-- Mã lỗi cụ thể cho module này
local ERROR = {
    TAB_NOT_FOUND = "MISSION_TAB_NOT_FOUND",
    BUTTON_NOT_FOUND = "DAILY_CHECK_BUTTON_NOT_FOUND",
    TAP_FAILED = "TAP_FAILED",
    VERIFICATION_FAILED = "VERIFICATION_FAILED",
    TIMEOUT = "TIMEOUT"
}

-- Hàm safeToString đơn giản để tránh phụ thuộc vào utils.safeToString
local function safeToString(value)
    if value == nil then
        return "nil"
    elseif type(value) == "string" then
        return value
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    else
        return "{" .. type(value) .. "}"
    end
end

-- Hàm chuyển đến tab nhiệm vụ
function dailyCheckin.navigateToMissionTab()
    logger.info("Chuyển đến tab nhiệm vụ...")
    
    -- Lấy tọa độ tab nhiệm vụ từ config
    local tabX, tabY = config.ui.tab_mission[1], config.ui.tab_mission[2]
    
    -- Tap vào tab nhiệm vụ
    local tapSuccess, _, tapError = utils.tapWithConfig(
        tabX, 
        tabY, 
        "tab nhiệm vụ"
    )
    
    if not tapSuccess then
        logger.error("Không thể tap vào tab nhiệm vụ: " .. safeToString(tapError))
        return false, ERROR.TAP_FAILED
    end
    
    -- Đợi UI ổn định
    mSleep(TIMING.UI_STABILIZE * 1000)
    
    logger.info("Đã chuyển đến tab nhiệm vụ thành công")
    return true, nil
end

-- Hàm tìm kiếm nút điểm danh hàng ngày
function dailyCheckin.findDailyCheckButton()
    logger.info("Tìm kiếm nút điểm danh hàng ngày...")
    
    -- Khu vực tìm kiếm
    local screenW, screenH = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    local searchRegion = {50, 200, screenW - 50, screenH - 300} -- Vùng giữa màn hình, bỏ qua vùng đáy
    
    -- Thử tìm nút điểm danh
    local found, result, error = utils.findColorPattern(config.color_patterns.daily_check_button, searchRegion)
    
    if found and result and result.x and result.y then
        local x, y = result.x, result.y
        logger.info("Đã tìm thấy nút điểm danh tại vị trí " .. x .. "," .. y)
        return true, x, y, nil
    end
    
    -- Nếu không tìm thấy, cuộn màn hình để tìm
    logger.info("Không tìm thấy nút điểm danh, thử cuộn màn hình để tìm...")
    
    -- Tối đa 8 lần cuộn
    for i = 1, 6 do
        -- Cuộn từ giữa màn hình lên
        local midX = screenW / 2
        local startY = screenH * 0.7
        local endY = screenH * 0.3
        
        touchDown(1, midX, startY)
        mSleep(100)  -- Tăng thời gian chờ sau khi touch down
        for step = 1, 100 do  -- 50 bước cuộn
            local currentY = startY - (step * (startY - endY) / 40)
            touchMove(1, midX, currentY)
            mSleep(50)  -- Giữ nguyên thời gian chờ giữa các bước
        end
        touchUp(1, midX, endY)
        
        -- Đợi màn hình ổn định lâu hơn
        mSleep((TIMING.SCROLL_DELAY * 2) * 1000)
        
        -- Thử tìm lại nút điểm danh
        found, result, error = utils.findColorPattern(config.color_patterns.daily_check_button, searchRegion)
        
        if found and result and result.x and result.y then
            local x, y = result.x, result.y
            logger.info("Đã tìm thấy nút điểm danh sau khi cuộn lần " .. i .. " tại vị trí " .. x .. "," .. y)
            return true, x, y, nil
        end
    end
    
    logger.error("Không tìm thấy nút điểm danh sau nhiều lần cuộn màn hình")
    return false, 0, 0, ERROR.BUTTON_NOT_FOUND
end

-- Hàm tap vào nút điểm danh
function dailyCheckin.tapDailyCheckButton()
    -- Tìm nút điểm danh
    local found, x, y, error = dailyCheckin.findDailyCheckButton()
    
    if not found then
        return false, error
    end
    
    logger.info("Tap vào nút điểm danh tại vị trí " .. x .. "," .. y)
    
    -- Đơn giản chỉ tap một lần đúng vị trí
    touchDown(1, x, y)
    mSleep(100)
    touchUp(1, x, y)
    mSleep(1000)
    
    -- Không quan tâm kết quả, coi như thành công
    logger.info("Đã thực hiện tap vào nút điểm danh, tiếp tục nhiệm vụ...")
    return true, nil
end

-- Hàm thực hiện toàn bộ quy trình điểm danh hàng ngày
function dailyCheckin.performDailyCheckin()
    logger.info("Bắt đầu quy trình điểm danh hàng ngày...")
    
    -- Bước 1: Chuyển đến tab nhiệm vụ
    local navSuccess, navError = dailyCheckin.navigateToMissionTab()
    
    if not navSuccess then
        logger.warning("Không thể chuyển đến tab nhiệm vụ: " .. safeToString(navError))
        return true, "Bỏ qua điểm danh, tiếp tục nhiệm vụ" -- Vẫn trả về thành công
    end

    -- Đợi tab nhiệm vụ load
    mSleep(8000)
    
    -- Bước 2: Tìm và tap vào nút điểm danh
    local tapSuccess, tapError = dailyCheckin.tapDailyCheckButton()
    
    if not tapSuccess then
        logger.warning("Không tìm thấy nút điểm danh: " .. safeToString(tapError))
    else
        logger.info("Đã tap vào nút điểm danh")
    end
    
    -- Luôn trả về thành công để tiếp tục với nhiệm vụ tiếp theo
    return true, "Hoàn thành bước điểm danh, tiếp tục nhiệm vụ"
end

return dailyCheckin