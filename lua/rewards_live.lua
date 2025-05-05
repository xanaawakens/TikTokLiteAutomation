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

-- Hàm kiểm tra nút xem live có xuất hiện không
function checkButtonLive()
    -- Tìm kiếm nút xem live trong vùng đã cấu hình
    local found, x, y = utils.findColorPattern(config.live_matrix, config.search_regions.live_button)
    
    if found then
        toast("Đã tìm thấy nút xem live tại " .. x .. "," .. y)
    end
    
    return found, x, y
end

-- Hàm bấm vào nút xem live
function tapLiveButton()
    -- Tìm kiếm nút trước khi bấm
    mSleep(2500)
    local found, x, y = checkButtonLive()
    
    if found then
        if utils.checkAndClosePopup() then
            toast("Đã đóng popup, tiếp tục bấm nút live sau 1 giây")
            mSleep(1000)
        end
        -- Bấm vào vị trí đã tìm thấy
        utils.tapWithConfig(x, y)
        return true
    else
        toast("Không tìm thấy nút xem live")
        return false
    end
end

-- Hàm đợi và xác nhận đã vào được màn hình xem live
function waitForLiveScreen(timeout)
    mSleep(1500)
    timeout = timeout or config.timing.check_timeout
    local startTime = os.time()
    
    while os.time() - startTime < timeout do
        -- Kiểm tra màn hình live đã load bằng ma trận màu
        local found = utils.findColorPattern(config.in_live_matrix)
        
        if found then
            toast("Đã xác nhận màn hình live đã load")
            return true
        end
        
        mSleep(1000) -- Kiểm tra mỗi giây
    end
    toast("Không thể xác nhận màn hình live đã load")
    return false
end

-- Hàm kiểm tra nút phần thưởng trong live
function checkRewardButton()
    -- Kiểm tra nút phần thưởng thứ nhất
    local found, x, y = utils.findColorPattern(config.reward_button_matrix_1, config.search_regions.reward_button)
    if found then
        return true, x, y
    end
    
    -- Nếu không tìm thấy nút thứ nhất, kiểm tra nút thứ hai
    local found2, x2, y2 = utils.findColorPattern(config.reward_button_matrix_2, config.search_regions.reward_button)
    if found2 then
        return true, x2, y2
    end
    
    -- Không tìm thấy cả hai nút
    return false, 0, 0
end

-- Hàm bấm vào nút phần thưởng
function tapRewardButton()
    -- Tìm nút phần thưởng
    local found, x, y = checkRewardButton()
    
    if found then
        -- Bấm vào nút phần thưởng đã tìm thấy
        utils.tapWithConfig(x, y)
        
        -- Đợi một khoảng thời gian sau khi bấm
        mSleep(1000)
        
        return true
    else
        return false
    end
end

-- Hàm kiểm tra nút claim
function checkClaimButton()
    -- Lấy kích thước màn hình
    local width, height = utils.getDeviceScreen()
    
    -- Tạo vùng tìm kiếm cho nút claim (toàn màn hình)
    local fullScreenRegion = {0, 0, width, height}
    
    -- Tìm kiếm nút claim dựa vào ma trận
    local found, x, y = utils.findColorPattern(config.claim_button_matrix, fullScreenRegion)
    
    if found then
        return true, x, y
    end
    
    return false, 0, 0
end

-- Hàm bấm vào nút claim
function tapClaimButton()
    -- Tìm nút claim
    local found, x, y = checkClaimButton()
    
    if found then
        -- Bấm vào nút claim đã tìm thấy
        toast("Claim thành công!")
        utils.tapWithConfig(x, y)
        
        -- Đợi một khoảng thời gian sau khi bấm
        mSleep(1000)
        
        return true
    else
        return false
    end
end

-- Hàm kiểm tra nút complete (hoàn thành)
function checkCompleteButton()
    -- Lấy kích thước màn hình
    local width, height = utils.getDeviceScreen()
    
    -- Tạo vùng tìm kiếm cho nút complete (toàn màn hình)
    local fullScreenRegion = {0, 0, width, height}
    
    -- Tìm kiếm nút complete dựa vào ma trận
    local found, x, y = utils.findColorPattern(config.complete_button_matrix, fullScreenRegion)
    
    if found then
        return true, x, y
    end
    
    return false, 0, 0
end

-- Xuất các hàm
return {
    checkButtonLive = checkButtonLive,
    tapLiveButton = tapLiveButton,
    waitForLiveScreen = waitForLiveScreen,
    checkRewardButton = checkRewardButton,
    tapRewardButton = tapRewardButton,
    checkClaimButton = checkClaimButton,
    tapClaimButton = tapClaimButton,
    checkCompleteButton = checkCompleteButton,
    checkAndClosePopup = utils.checkAndClosePopup
}