--[[
  rewards_live.lua - Module xử lý chức năng xem live TikTok Lite
  
  Module này chứa các hàm để:
  - Tìm kiếm nút xem live trên giao diện TikTok
  - Bấm vào nút xem live
  - Xử lý luồng xem live và kiểm tra phần thưởng
]]

-- Khai báo thư viện cần thiết
require("TSLib")
local config = require("config")
local utils = require("utils")

-- Khởi tạo module
local rewardsLive = {}

-- Thời gian chờ (đưa vào config.lua nếu chưa có)
local TIMING = {
    AFTER_TAP = config.timing.tap_delay or 1,  -- Thời gian chờ sau khi tap
    LIVE_BUTTON_SEARCH = config.timing.live_button_search or 2.5,  -- Thời gian chờ trước khi tìm nút live
    UI_STABILIZE = config.timing.ui_stabilize or 1.5,  -- Thời gian chờ UI ổn định
    ACTION_VERIFICATION = config.timing.action_verification or 3  -- Thời gian chờ để xác minh hành động
}

-- Hàm bắt lỗi thực thi an toàn
local function safeExecute(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        return false, "Lỗi thực thi: " .. tostring(result)
    end
    return true, result
end

-- Hàm tìm kiếm một nút trên giao diện bằng mẫu màu
local function findButton(matrix, region, description)
    local success, result = safeExecute(utils.findColorPattern, matrix, region)
    
    if not success then
        return false, 0, 0, "Lỗi khi tìm " .. description .. ": " .. result
    end
    
    -- Xử lý kết quả trả về từ findColorPattern trực tiếp thay vì sử dụng unpack
    if result then
        local found = result
        local x = 0
        local y = 0
        
        -- Trong utils.findColorPattern, nếu tìm thấy, trả về true, x, y, nil
        if type(result) == "boolean" and result == true then
            -- Trong trường hợp này, kết quả là các giá trị riêng lẻ
            -- success = true, result = true (found), arg3 = x, arg4 = y
            _, found, x, y = pcall(utils.findColorPattern, matrix, region)
        end
        
        if found then
            nLog("Đã tìm thấy " .. description .. " tại " .. x .. "," .. y)
            return true, x, y, nil
        end
    end
    
    nLog("Không tìm thấy " .. description)
    return false, 0, 0, "Không tìm thấy " .. description
end

-- Hàm chung để tap vào nút với xác minh hành động
local function tapButton(checkFunc, tapAction, verifyFunc, description)
    -- Tìm nút
    local found, x, y, error = checkFunc()
    
    if not found then
        return false, error or "Không tìm thấy " .. description
    end
    
    -- Thực hiện tap
    if tapAction then
        local tapSuccess, tapError = safeExecute(tapAction, x, y)
        if not tapSuccess then
            return false, "Lỗi khi tap vào " .. description .. ": " .. tapError
        end
    else
        -- Mặc định sử dụng utils.tapWithConfig
        utils.tapWithConfig(x, y)
    end
    
    -- Đợi một khoảng thời gian cho UI ổn định
    mSleep(TIMING.AFTER_TAP * 1000)
    
    -- Xác minh hành động nếu có hàm xác minh
    if verifyFunc then
        local verifySuccess, verifyError = safeExecute(verifyFunc)
        if not verifySuccess then
            return false, "Không thể xác minh sau khi tap vào " .. description .. ": " .. verifyError
        end
        
        if not verifySuccess then
            return false, "Không thể xác minh sau khi tap vào " .. description
        end
    end
    
    toast("Đã tap vào " .. description)
    return true, nil
end

-- Hàm kiểm tra nút xem live có xuất hiện không
function rewardsLive.checkButtonLive()
    return findButton(config.live_matrix, config.search_regions.live_button, "nút xem live")
end

-- Hàm bấm vào nút xem live
function rewardsLive.tapLiveButton()
    -- Đợi UI ổn định trước khi tìm nút
    mSleep(TIMING.LIVE_BUTTON_SEARCH * 1000)
    
    -- Kiểm tra và đóng popup nếu cần
    local popupClosed = utils.checkAndClosePopup()
    if popupClosed then
        toast("Đã đóng popup, tiếp tục bấm nút live sau " .. TIMING.UI_STABILIZE .. " giây")
        mSleep(TIMING.UI_STABILIZE * 1000)
        end
    
    -- Sử dụng hàm chung tapButton để tap vào nút live
    local success, error = tapButton(
        rewardsLive.checkButtonLive,  -- Hàm kiểm tra
        nil,  -- Sử dụng tap mặc định
        nil,  -- Không cần xác minh thêm
        "nút xem live"
    )
    
    return success, error
end

-- Hàm đợi và xác nhận đã vào được màn hình xem live
function rewardsLive.waitForLiveScreen(timeout)
    mSleep(TIMING.UI_STABILIZE * 1000)
    timeout = timeout or config.timing.check_timeout
    local startTime = os.time()
    
    while os.time() - startTime < timeout do
        -- Kiểm tra màn hình live đã load bằng ma trận màu
        local success, result = safeExecute(utils.findColorPattern, config.in_live_matrix)
        
        if not success then
            return false, "Lỗi khi kiểm tra màn hình live: " .. result
        end
        
        if result then
            toast("Đã xác nhận màn hình live đã load")
            return true, nil
        end
        
        mSleep(1000) -- Kiểm tra mỗi giây
    end
    
    toast("Không thể xác nhận màn hình live đã load trong " .. timeout .. " giây")
    return false, "Timeout: Không thể xác nhận màn hình live đã load trong " .. timeout .. " giây"
end

-- Hàm kiểm tra nút phần thưởng trong live
function rewardsLive.checkRewardButton()
    -- Kiểm tra nút phần thưởng thứ nhất
    local found1, x1, y1, error1 = findButton(
        config.reward_button_matrix_1, 
        config.search_regions.reward_button, 
        "nút phần thưởng (mẫu 1)"
    )
    
    if found1 then
        return true, x1, y1, nil
    end
    
    -- Nếu không tìm thấy nút thứ nhất, kiểm tra nút thứ hai
    local found2, x2, y2, error2 = findButton(
        config.reward_button_matrix_2, 
        config.search_regions.reward_button, 
        "nút phần thưởng (mẫu 2)"
    )
    
    if found2 then
        return true, x2, y2, nil
    end
    
    -- Không tìm thấy cả hai nút
    return false, 0, 0, "Không tìm thấy nút phần thưởng (cả hai mẫu đều không khớp)"
end

-- Hàm bấm vào nút phần thưởng
function rewardsLive.tapRewardButton()
    -- Sử dụng hàm chung tapButton
    local success, error = tapButton(
        rewardsLive.checkRewardButton,
        nil,  -- Sử dụng tap mặc định
        nil,  -- Không cần xác minh thêm
        "nút phần thưởng"
    )
        
    return success, error
end

-- Hàm kiểm tra nút claim
function rewardsLive.checkClaimButton()
    -- Lấy kích thước màn hình từ biến toàn cục
    local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    
    -- Tạo vùng tìm kiếm cho nút claim (toàn màn hình)
    local fullScreenRegion = {0, 0, width, height}
    
    -- Tìm kiếm nút claim dựa vào ma trận
    return findButton(config.claim_button_matrix, fullScreenRegion, "nút claim")
end

-- Hàm bấm vào nút claim
function rewardsLive.tapClaimButton()
    -- Sử dụng hàm chung tapButton
    local success, error = tapButton(
        rewardsLive.checkClaimButton,
        function(x, y)
            utils.tapWithConfig(x, y)
        toast("Claim thành công!")
        end,
        nil,  -- Không cần xác minh thêm
        "nút claim"
    )
        
    return success, error
end

-- Hàm kiểm tra nút complete (hoàn thành)
function rewardsLive.checkCompleteButton()
    -- Lấy kích thước màn hình từ biến toàn cục
    local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    
    -- Tạo vùng tìm kiếm cho nút complete (toàn màn hình)
    local fullScreenRegion = {0, 0, width, height}
    
    -- Tìm kiếm nút complete dựa vào ma trận
    return findButton(config.complete_button_matrix, fullScreenRegion, "nút complete")
end

-- Hàm bấm vào nút complete
function rewardsLive.tapCompleteButton()
    -- Sử dụng hàm chung tapButton
    local success, error = tapButton(
        rewardsLive.checkCompleteButton,
        nil,  -- Sử dụng tap mặc định
        nil,  -- Không cần xác minh thêm
        "nút complete"
    )
    
    return success, error
end

-- Xuất các hàm
return {
    checkButtonLive = rewardsLive.checkButtonLive,
    tapLiveButton = rewardsLive.tapLiveButton,
    waitForLiveScreen = rewardsLive.waitForLiveScreen,
    checkRewardButton = rewardsLive.checkRewardButton,
    tapRewardButton = rewardsLive.tapRewardButton,
    checkClaimButton = rewardsLive.checkClaimButton,
    tapClaimButton = rewardsLive.tapClaimButton,
    checkCompleteButton = rewardsLive.checkCompleteButton,
    tapCompleteButton = rewardsLive.tapCompleteButton,
    checkAndClosePopup = utils.checkAndClosePopup
}