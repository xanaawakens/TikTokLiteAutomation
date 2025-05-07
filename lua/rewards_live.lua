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
local logger = require("logger")
local errorHandler = require("error_handler")

-- Khởi tạo module
local rewardsLive = {}

-- Tên module để sử dụng trong log
local MODULE_NAME = "rewards_live"

-- Thời gian chờ (đưa vào config.lua nếu chưa có)
local TIMING = {
    AFTER_TAP = config.timing.tap_delay or 1,  -- Thời gian chờ sau khi tap
    LIVE_BUTTON_SEARCH = config.timing.live_button_search or 2.5,  -- Thời gian chờ trước khi tìm nút live
    UI_STABILIZE = config.timing.ui_stabilize or 1.5,  -- Thời gian chờ UI ổn định
    ACTION_VERIFICATION = config.timing.action_verification or 3  -- Thời gian chờ để xác minh hành động
}

-- Mã lỗi cụ thể cho module này
local ERROR = {
    BUTTON_NOT_FOUND = errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.UI].ELEMENT_NOT_FOUND,
    TAP_FAILED = errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.UI].TAP_FAILED,
    VERIFICATION_FAILED = errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.UI].SCREEN_MISMATCH,
    TIMEOUT = errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.GENERAL].TIMEOUT
}

-- Hàm tìm kiếm một nút trên giao diện bằng mẫu màu
local function findButton(matrix, region, description)
    local success, result, error = utils.findColorPattern(matrix, region)
    
    if not success then
        local errorObj = errorHandler.createError(
            ERROR.BUTTON_NOT_FOUND,
            "Không thể tìm " .. description,
            {details = error}
        )
        return false, 0, 0, errorObj
    end
    
    if result then
        logger.debug("Đã tìm thấy " .. description .. " tại " .. (result.x or 0) .. "," .. (result.y or 0))
        return true, result.x, result.y, nil
    end
    
    logger.debug("Không tìm thấy " .. description)
    local errorObj = errorHandler.createError(
        ERROR.BUTTON_NOT_FOUND,
        "Không tìm thấy " .. description
    )
    return false, 0, 0, errorObj
end

-- Hàm chung để tap vào nút với xác minh hành động
local function tapButton(checkFunc, tapAction, verifyFunc, description)
    -- Tìm nút
    local found, x, y, error = checkFunc()
    
    if not found then
        -- Nếu error đã là đối tượng lỗi thì sử dụng nó, nếu không tạo mới
        if type(error) ~= "table" or not error.code then
            error = errorHandler.createError(
                ERROR.BUTTON_NOT_FOUND,
                "Không tìm thấy " .. description,
                {error = error}
            )
        end
        return false, error
    end
    
    -- Thực hiện tap
    if tapAction then
        local tapSuccess, tapResult, tapError = utils.retryOperation(function()
            return tapAction(x, y)
        end, 3, 500)
        
        if not tapSuccess then
            local errorObj = errorHandler.createError(
                ERROR.TAP_FAILED,
                "Lỗi khi tap vào " .. description,
                {error = tapError}
            )
            return false, errorObj
        end
    else
        -- Mặc định sử dụng utils.tapWithConfig
        local tapSuccess, _, tapError = utils.tapWithConfig(x, y, description)
        if not tapSuccess then
            local errorObj = errorHandler.createError(
                ERROR.TAP_FAILED,
                "Lỗi khi tap vào " .. description,
                {error = tapError}
            )
            return false, errorObj
        end
    end
    
    -- Đợi một khoảng thời gian cho UI ổn định
    mSleep(TIMING.AFTER_TAP * 1000)
    
    -- Xác minh hành động nếu có hàm xác minh
    if verifyFunc then
        local verifySuccess, verifyResult, verifyError = utils.retryOperation(verifyFunc, 3, 500)
        
        if not verifySuccess then
            local errorObj = errorHandler.createError(
                ERROR.VERIFICATION_FAILED,
                "Không thể xác minh sau khi tap vào " .. description,
                {error = verifyError}
            )
            return false, errorObj
        end
    end
    
    logger.info("Đã tap vào " .. description)
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
    local popupClosed, popupError = utils.checkAndClosePopup()
    if popupClosed then
        logger.info("Đã đóng popup, tiếp tục bấm nút live sau " .. TIMING.UI_STABILIZE .. " giây")
        mSleep(TIMING.UI_STABILIZE * 1000)
    elseif popupError then
        logger.warning("Lỗi khi xử lý popup: " .. popupError)
    end
    
    -- Sử dụng hàm chung tapButton để tap vào nút live
    local success, error = tapButton(
        rewardsLive.checkButtonLive,  -- Hàm kiểm tra
        nil,  -- Sử dụng tap mặc định
        nil,  -- Không cần xác minh thêm
        "nút xem live"
    )
    
    if not success and error then
        errorHandler.logError(error, MODULE_NAME)
    end
    
    return success, error
end

-- Hàm đợi và xác nhận đã vào được màn hình xem live
function rewardsLive.waitForLiveScreen(timeout)
    mSleep(TIMING.UI_STABILIZE * 1000)
    timeout = timeout or config.timing.check_timeout
    local startTime = os.time()
    
    while os.time() - startTime < timeout do
        -- Kiểm tra màn hình live đã load bằng ma trận màu
        local success, result, error = utils.findColorPattern(config.in_live_matrix)
        
        if not success then
            local errorObj = errorHandler.createError(
                ERROR.VERIFICATION_FAILED,
                "Lỗi khi kiểm tra màn hình live",
                {error = error}
            )
            errorHandler.logError(errorObj, MODULE_NAME)
            return false, errorObj
        end
        
        if result then
            logger.info("Đã xác nhận màn hình live đã load")
            return true, nil
        end
        
        mSleep(1000) -- Kiểm tra mỗi giây
    end
    
    local errorObj = errorHandler.createError(
        ERROR.TIMEOUT,
        "Không thể xác nhận màn hình live đã load trong " .. timeout .. " giây"
    )
    errorHandler.logError(errorObj, MODULE_NAME)
    return false, errorObj
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
    local errorObj = errorHandler.createError(
        ERROR.BUTTON_NOT_FOUND,
        "Không tìm thấy nút phần thưởng"
    )
    return false, 0, 0, errorObj
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
        
    if not success and error then
        errorHandler.logError(error, MODULE_NAME)
    end
    
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
            local tapSuccess, _, tapError = utils.tapWithConfig(x, y, "nút claim")
            logger.info("Claim thành công!")
            return tapSuccess, nil, tapError
        end,
        nil,  -- Không cần xác minh thêm
        "nút claim"
    )
        
    if not success and error then
        errorHandler.logError(error, MODULE_NAME)
    end
    
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
    
    if not success and error then
        errorHandler.logError(error, MODULE_NAME)
    end
    
    return success, error
end

-- Thực hiện vuốt để chuyển sang live stream khác
function rewardsLive.switchToNextStream(count)
    count = count or 1
    local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    local startY = math.floor(height * 0.9)   
    local endY = math.floor(height * 0.6)   
    local midX = math.floor(width / 2)
    
    for i = 1, count do
        logger.info("Vuốt sang stream thứ " .. i)
        
        local swipeSuccess, _, swipeError = utils.swipeWithConfig(midX, startY, midX, endY, 500, "sang stream tiếp theo")
        if not swipeSuccess then
            local errorObj = errorHandler.createError(
                errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.UI].SWIPE_FAILED,
                "Không thể vuốt sang stream tiếp theo",
                {error = swipeError}
            )
            errorHandler.logError(errorObj, MODULE_NAME)
            return false, errorObj
        end
        
        mSleep(3000)
    end
    
    -- Kiểm tra live screen đã load sau khi vuốt
    local liveLoaded, loadError = rewardsLive.waitForLiveScreen()
    if not liveLoaded then
        return false, loadError
    end
    
    return true, nil
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
    switchToNextStream = rewardsLive.switchToNextStream,
    checkAndClosePopup = utils.checkAndClosePopup
}

