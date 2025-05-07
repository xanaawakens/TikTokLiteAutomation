--[[
  utils.lua - Thư viện các hàm tiện ích cho kịch bản TouchSprite TikTok Lite
  
  Thư viện này chứa các hàm tiện ích để:
  - Kiểm tra và mở ứng dụng TikTok Lite
  - Tìm kiếm các mẫu màu trên màn hình
  - Thực hiện các thao tác cơ bản như tap, swipe
]]

-- Khai báo thư viện cần thiết
require("TSLib")
local config = require("config")
local logger = require("logger")  -- Thêm module logger mới

-- Khởi tạo module tiện ích
local utils = {}

-- Định nghĩa các mã lỗi chuẩn
utils.ERROR = {
    -- Lỗi tham số
    MISSING_PARAM = "MISSING_PARAM",
    INVALID_PARAM_TYPE = "INVALID_PARAM_TYPE",
    INVALID_PARAM_VALUE = "INVALID_PARAM_VALUE",
    
    -- Lỗi ứng dụng
    APP_NOT_FOUND = "APP_NOT_FOUND",
    APP_LAUNCH_FAILED = "APP_LAUNCH_FAILED",
    APP_NOT_FOREGROUND = "APP_NOT_FOREGROUND",
    
    -- Lỗi giao diện
    UI_NOT_LOADED = "UI_NOT_LOADED",
    UI_ELEMENT_NOT_FOUND = "UI_ELEMENT_NOT_FOUND",
    
    -- Lỗi tương tác
    TAP_FAILED = "TAP_FAILED",
    SWIPE_FAILED = "SWIPE_FAILED",
    
    -- Lỗi tìm kiếm
    PATTERN_NOT_FOUND = "PATTERN_NOT_FOUND",
    INVALID_MATRIX = "INVALID_MATRIX",
    
    -- Lỗi khác
    TIMEOUT = "TIMEOUT",
    UNKNOWN_ERROR = "UNKNOWN_ERROR"
}

-- Thời gian chờ (sử dụng từ config hoặc giá trị mặc định)
local TIMING = {
    POPUP_DETECTION = config.timing.popup_detection or 5,        -- Thời gian tìm popup (giây)
    POPUP_CHECK_INTERVAL = config.timing.popup_check_interval or 0.2,  -- Thời gian giữa các lần kiểm tra popup (giây)
    AFTER_POPUP_CLOSE = config.timing.after_popup_close or 1,    -- Thời gian sau khi đóng popup (giây)
    SWIPE_STEP_DELAY = config.timing.swipe_step_delay or 0.005,  -- Độ trễ giữa các bước vuốt (giây)
    APP_CLOSE_WAIT = config.timing.app_close_wait or 3,          -- Thời gian chờ sau khi đóng app (giây)
    FIND_COLOR_TIMEOUT = config.timing.find_color_timeout or 5   -- Thời gian tối đa tìm kiếm màu (giây)
}

-- Hàm để kiểm tra tính hợp lệ của tham số
function utils.validateParam(param, paramName, paramType, isRequired, validValues)
    -- Kiểm tra tham số bắt buộc
    if isRequired and param == nil then
        return false, "Thiếu tham số bắt buộc: " .. paramName
    end
    
    -- Nếu tham số không tồn tại và không bắt buộc, bỏ qua
    if param == nil then
        return true
    end
    
    -- Kiểm tra kiểu dữ liệu
    if paramType and type(param) ~= paramType then
        return false, "Tham số " .. paramName .. " không đúng kiểu dữ liệu. Yêu cầu: " .. paramType .. ", Thực tế: " .. type(param)
    end
    
    -- Kiểm tra giá trị hợp lệ nếu được chỉ định
    if validValues and type(validValues) == "table" then
        local isValid = false
        for _, validValue in ipairs(validValues) do
            if param == validValue then
                isValid = true
                break
            end
        end
        if not isValid then
            return false, "Tham số " .. paramName .. " không có giá trị hợp lệ. Các giá trị hợp lệ: " .. table.concat(validValues, ", ")
        end
    end
    
    return true
end

-- Hàm bắt lỗi thực thi an toàn
local function safeExecute(func, ...)
    -- Kiểm tra tham số
    if type(func) ~= "function" then
        return false, nil, "safeExecute: Tham số không phải là hàm"
    end
    
    -- Thực thi function trong pcall để bắt lỗi
    local success, result = pcall(func, ...)
    
    if not success then
        return false, nil, "Lỗi thực thi: " .. tostring(result)
    end
    
    -- Trả về kết quả theo cấu trúc thống nhất: success, result, error
    return true, result, nil
end

-- Tiện ích xử lý tìm kiếm màu sắc
----------------------------------

-- Chuyển đổi ma trận màu sang định dạng offset cho findMultiColorInRegionFuzzy
function utils.convertMatrixToOffsetString(matrix)
    if not matrix or #matrix < 2 then
        return nil, nil, nil, "Ma trận màu không hợp lệ hoặc không đủ điểm"
    end
    
    -- Lấy điểm màu mẫu đầu tiên làm điểm gốc
    local mainColor = matrix[1][3]
    local mainX = matrix[1][1]
    local mainY = matrix[1][2]
    
    -- Tạo chuỗi điểm màu phụ
    local offsetStr = ""
    for i = 2, #matrix do
        local point = matrix[i]
        local offsetX = point[1] - mainX
        local offsetY = point[2] - mainY
        offsetStr = offsetStr .. string.format("%d|%d|%06X,", offsetX, offsetY, point[3])
    end
    
    -- Loại bỏ dấu phẩy cuối cùng
    if offsetStr ~= "" then
        offsetStr = string.sub(offsetStr, 1, -2)
    end
    
    return mainColor, mainX, mainY, offsetStr
end

-- Tìm kiếm mẫu màu trong vùng cụ thể
function utils.findColorPattern(matrix, region, similarity)
    -- Xác thực tham số
    local isValid, errMsg = utils.validateParam(matrix, "matrix", "table", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    isValid, errMsg = utils.validateParam(region, "region", "table", false)
    if not isValid then
        return false, nil, errMsg
    end
    
    similarity = similarity or config.accuracy.color_similarity
    
    -- Lấy kích thước màn hình
    local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    
    -- Xác định vùng tìm kiếm
    local x1, y1, x2, y2
    if region then
        if #region < 4 then
            return false, nil, "Vùng tìm kiếm không hợp lệ: cần 4 giá trị {x1, y1, x2, y2}"
        end
        x1, y1, x2, y2 = region[1], region[2], region[3], region[4]
    else
        x1, y1, x2, y2 = 0, 0, width, height
    end
    
    -- Kiểm tra ma trận đầu vào
    if #matrix < 1 then
        return false, nil, "Ma trận màu không hợp lệ hoặc không đủ điểm"
    end
    
    -- Thực thi an toàn việc chuyển đổi ma trận
    local success, mainColor, mainX, mainY, offsetStr = pcall(utils.convertMatrixToOffsetString, matrix)
    
    if not success then
        return false, nil, "Lỗi khi chuyển đổi ma trận: " .. tostring(mainColor) -- mainColor chứa thông báo lỗi khi pcall thất bại
    end
    
    if not mainColor or not offsetStr then
        return false, nil, "Không thể chuyển đổi ma trận màu"
    end
    
    -- Tìm kiếm mẫu màu trong vùng chỉ định
    local startTime = os.time()
    
    while os.time() - startTime < TIMING.FIND_COLOR_TIMEOUT do
        local x, y = findMultiColorInRegionFuzzy(mainColor, offsetStr, similarity, x1, y1, x2, y2)
        
        -- Trả về kết quả tìm kiếm
        if x ~= -1 and y ~= -1 then
            logger.debug("Tìm thấy mẫu màu tại " .. x .. "," .. y)
            return true, {x = x, y = y}, nil
        end
        
        mSleep(100)  -- Đợi một chút trước khi thử lại
    end
    
    return false, nil, "Không tìm thấy mẫu màu sau " .. TIMING.FIND_COLOR_TIMEOUT .. " giây"
end

-- Kiểm tra TikTok Lite đã load xong chưa
function utils.checkTikTokLoadedByColor()
    -- Sử dụng vùng tìm kiếm nếu được cấu hình
    local region = config.search_regions and config.search_regions.tiktok_loaded
    local success, result, error = utils.findColorPattern(config.color_patterns.tiktok_loaded, region)
    
    if success then
        logger.info("TikTok Lite đã load thành công")
        return true, nil
    else
        return false, error or "Không thể xác nhận TikTok Lite đã load"
    end
end

-- Tiện ích tương tác ứng dụng
------------------------------

-- Mở ứng dụng TikTok Lite và đợi cho đến khi tải xong
function utils.openTikTokLite(verify)
    -- Mở TikTok Lite bằng bundle ID từ cấu hình
    local bundleID = config.app.bundle_id
    
    -- Đóng TikTok Lite nếu đang chạy
    if appIsRunning(bundleID) then
        closeApp(bundleID)
        logger.debug("Đã đóng TikTok Lite đang chạy, chờ " .. TIMING.APP_CLOSE_WAIT .. "s")
        mSleep(TIMING.APP_CLOSE_WAIT * 1000)
    end
    
    -- Mở TikTok Lite
    logger.info("Đang mở TikTok Lite...")
    runApp(bundleID)
    mSleep(config.timing.launch_wait * 1000)
    
    -- Xác minh đã mở thành công nếu cần
    if verify then
        local region = config.search_regions.tiktok_loaded
        logger.debug("Kiểm tra TikTok đã mở...")
        local success, result, error = utils.findColorPattern(config.color_patterns.tiktok_loaded, region)
        
        if not success then
            return false, "Lỗi khi kiểm tra TikTok đã mở: " .. (error or "")
        end
        
        if not result then
            return false, "Không thể xác nhận TikTok đã mở"
        end
        
        logger.info("Đã xác nhận TikTok đã mở thành công")
    end
    
    return true, nil
end

-- Kiểm tra TikTok Lite đã được cài đặt chưa (không mở app)
function utils.isTikTokLiteInstalled()
    local bundleID = config.app.bundle_id
    
    -- Phương pháp 1: Dùng appIsInstalled (nếu có)
    if type(appIsInstalled) == "function" then
        if appIsInstalled(bundleID) then
            return true, nil
        end
    end
    
    -- Phương pháp 2: Kiểm tra app có thể chạy không
    if appIsRunning(bundleID) then
        return true, nil
    end
    
    -- Phương pháp 3: Kiểm tra trong danh sách app đã cài đặt
    if type(getInstalledApps) == "function" then
        local apps = getInstalledApps()
        if apps then
            for _, app in ipairs(apps) do
                if app.bid == bundleID then
                    return true, nil
                end
            end
        end
    end
    
    -- Chỉ trả về kết quả dựa trên việc kiểm tra, không mở app để thử
    local appExists = appExist(bundleID)
    logger.debug("Kiểm tra: TikTok Lite " .. (appExists and "đã được cài đặt" or "chưa được cài đặt"))
    
    if appExists then
        return true, nil
    else
        return false, "TikTok Lite chưa được cài đặt"
    end
end

-- Đợi màn hình hiển thị màu hoặc hình ảnh cụ thể
function utils.waitForScreen(colorOrImage, x, y, sim, timeout)
    sim = sim or config.accuracy.color_similarity
    timeout = timeout or config.timing.check_timeout
    
    local startTime = os.time()
    local description = type(colorOrImage) == "number" and "màu sắc" or "hình ảnh"
    
    while os.time() - startTime < timeout do
        local found = false
        local error = nil
        
        if type(colorOrImage) == "number" then
            -- Kiểm tra màu
            local success, result = safeExecute(isColor, x, y, colorOrImage, sim)
            if success and result then
                found = true
            elseif not success then
                error = "Lỗi khi kiểm tra màu: " .. result
            end
        else
            -- Kiểm tra hình ảnh
            local success, result = safeExecute(findImage, colorOrImage, sim)
            if success and result then
                found = true
            elseif not success then
                error = "Lỗi khi tìm hình ảnh: " .. result
            end
        end
        
        if found then
            logger.debug("Đã tìm thấy " .. description)
            return true, nil
        elseif error then
            return false, error
        end
        
        mSleep(500)
    end
    
    return false, "Không tìm thấy " .. description .. " sau " .. timeout .. " giây"
end

-- Tiện ích thao tác màn hình
-----------------------------

-- Thực hiện tap với độ trễ từ cấu hình
function utils.tapWithConfig(x, y, description, customDelay)
    description = description or "vị trí"
    
    -- Xác thực tham số
    local isValid, errMsg = utils.validateParam(x, "x", "number", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    isValid, errMsg = utils.validateParam(y, "y", "number", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    local success, result, error = safeExecute(tap, x, y)
    if not success then
        return false, nil, "Lỗi khi tap vào " .. description .. ": " .. (error or "")
    end
    
    -- Sử dụng customDelay nếu được cung cấp, nếu không sử dụng giá trị từ config
    local delay = customDelay or config.timing.tap_delay
    
    logger.debug("Đã tap vào " .. description .. " (" .. x .. "," .. y .. ")")
    mSleep(delay * 1000)
    return true, nil, nil
end

-- Thực hiện vuốt với độ trễ từ cấu hình
function utils.swipeWithConfig(x1, y1, x2, y2, duration, description)
    description = description or "màn hình"
    duration = duration or config.ui.swipe.duration
    
    -- Xác thực tham số
    local isValid, errMsg = utils.validateParam(x1, "x1", "number", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    isValid, errMsg = utils.validateParam(y1, "y1", "number", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    isValid, errMsg = utils.validateParam(x2, "x2", "number", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    isValid, errMsg = utils.validateParam(y2, "y2", "number", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    local success, result, error = safeExecute(moveTo, x1, y1, x2, y2, duration)
    if not success then
        return false, nil, "Lỗi khi vuốt " .. description .. ": " .. (error or "")
    end
    
    logger.debug("Đã vuốt từ (" .. x1 .. "," .. y1 .. ") đến (" .. x2 .. "," .. y2 .. ")")
    mSleep(config.timing.swipe_delay * 1000)
    return true, nil, nil
end

-- Vuốt lên để xem video tiếp theo
function utils.swipeNextVideo()
    local swipe = config.ui.swipe
    return utils.swipeWithConfig(swipe.start_x, swipe.start_y, swipe.end_x, swipe.end_y, nil, "lên để xem video tiếp theo")
end

-- Lấy kích thước màn hình
function utils.getDeviceScreen()
    -- Sử dụng biến toàn cục thay vì gọi lại getScreenSize()
    return _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
end

-- Hàm chung để tìm và xử lý popup bằng hình ảnh
function utils.checkAndClosePopupByImage(imageName, clickCoords, swipeAction, timeout)
    local width, height = utils.getDeviceScreen()
    timeout = timeout or TIMING.POPUP_DETECTION
    clickCoords = clickCoords or nil  -- Tọa độ để click đóng popup
    swipeAction = swipeAction or false -- True nếu cần vuốt để đóng
    
    logger.debug("Bắt đầu tìm kiếm popup " .. imageName .. " - Thời gian tối đa: " .. timeout .. " giây")
    
    local startTime = os.time()
    
    while (os.time() - startTime < timeout) do
        local x, y = findImageInRegionFuzzy(imageName, config.accuracy.image_similarity, 0, 0, width, height, 0, 1)
        
        if x ~= -1 and y ~= -1 then
            logger.info("Đã tìm thấy popup " .. imageName .. " tại vị trí " .. x .. "," .. y)
            
            -- Phương thức đóng popup: Click hoặc Swipe
            if clickCoords then
                -- Đóng bằng click vào tọa độ cụ thể
                local clickX = clickCoords[1]
                local clickY = clickCoords[2]
                
                logger.debug("Đóng popup bằng cách click vào vị trí " .. clickX .. "," .. clickY)
                local tapSuccess, tapError = utils.tapWithConfig(clickX, clickY, "nút đóng popup")
                if not tapSuccess then
                    return false, tapError
                end
            elseif swipeAction then
                -- Đóng bằng vuốt từ dưới lên
                local swipeStartX = x + 50 -- Điểm vuốt cách vị trí tìm thấy 50px theo chiều ngang
                local swipeStartY = y + 100 -- Điểm bắt đầu vuốt ở dưới popup
                local swipeEndX = swipeStartX -- Cùng vị trí X
                local swipeEndY = y - 50 -- Điểm kết thúc vuốt ở trên popup
                
                -- Đảm bảo điểm vuốt nằm trong màn hình
                swipeStartY = math.min(swipeStartY, height - 10)
                swipeEndY = math.max(swipeEndY, 10)
                
                logger.debug("Đóng popup bằng cách vuốt từ (" .. swipeStartX .. "," .. swipeStartY .. ") đến (" .. swipeEndX .. "," .. swipeEndY .. ")")
                
                touchDown(1, swipeStartX, swipeStartY)
                mSleep(50)
                
                -- Di chuyển ngón tay lên trên để đóng popup
                for i = 1, 10 do
                    local currentY = swipeStartY - i * ((swipeStartY - swipeEndY) / 10)
                    touchMove(1, swipeStartX, currentY)
                    mSleep(TIMING.SWIPE_STEP_DELAY * 1000)
                end
                
                touchUp(1, swipeEndX, swipeEndY)
            else
                -- Mặc định: tap trực tiếp vào popup
                local tapSuccess, tapError = utils.tapWithConfig(x, y, "popup " .. imageName)
                if not tapSuccess then
                    return false, tapError
                end
            end
            
            -- Đợi sau khi đóng popup
            mSleep(TIMING.AFTER_POPUP_CLOSE * 1000)
            
            return true, nil -- Đã tìm thấy và đóng popup
        end
        
        -- Đợi trước khi tìm kiếm lại
        mSleep(TIMING.POPUP_CHECK_INTERVAL * 1000)
    end
    
    logger.debug("Không tìm thấy popup " .. imageName .. " sau " .. timeout .. " giây")
    return false, nil -- Không tìm thấy popup, không phải lỗi
end

-- Hàm kiểm tra và đóng popup ở vùng màn hình cụ thể
function utils.checkAndClosePopup()
    return utils.checkAndClosePopupByImage(config.images.popup.general, config.popup_close.general, true)
end

-- Hàm kiểm tra và đóng popup Add Friends khi mới mở app TikTok
function utils.checkAndCloseAddFriendsPopup()
    return utils.checkAndClosePopupByImage(config.images.popup.add_friends, config.popup_close.add_friends)
end

-- Hàm bấm vào nút live sau khi kiểm tra popup
function utils.clickLiveWithPopupCheck(liveButtonX, liveButtonY)
    local popupClosed, popupError = utils.checkAndClosePopup()
    
    if popupClosed then
        logger.debug("Đã đóng popup, tiếp tục bấm nút live")
    elseif popupError then
        logger.warning("Lỗi khi xử lý popup: " .. popupError)
    else
        logger.debug("Không tìm thấy popup, tiếp tục bấm nút live")
    end
    
    -- Đợi sau khi kiểm tra popup
    mSleep(TIMING.AFTER_POPUP_CLOSE * 1000)
    
    -- Bấm vào nút live
    return utils.tapWithConfig(liveButtonX, liveButtonY, "nút live")
end

-- Hàm thử lại thao tác trong trường hợp thất bại
function utils.retryOperation(operationFunc, maxRetries, delayMs, retryCondition)
    maxRetries = maxRetries or 3
    delayMs = delayMs or 1000
    
    -- Nếu retryCondition không được cung cấp, sử dụng hàm mặc định
    -- Mặc định sẽ thử lại khi kết quả là false hoặc nil
    if not retryCondition then
        retryCondition = function(result)
            return not result
        end
    end
    
    local lastError = nil
    
    for attempt = 1, maxRetries do
        local success, result, error = pcall(operationFunc)
        
        -- Nếu hàm thực thi không gây ra lỗi runtime
        if success then
            -- Kiểm tra xem có cần thử lại không
            if not retryCondition(result) then
                logger.debug("Thao tác thành công sau " .. attempt .. " lần thử")
                return true, result, nil
            else
                -- Lưu lỗi từ lần thử hiện tại
                lastError = error
                logger.warning("Thao tác thất bại ở lần thử " .. attempt .. "/" .. maxRetries .. 
                               ": " .. (error or "Không có chi tiết lỗi"))
                
                -- Nếu chưa phải lần thử cuối, đợi một khoảng thời gian
                if attempt < maxRetries then
                    logger.debug("Đợi " .. delayMs .. "ms trước khi thử lại...")
                    mSleep(delayMs)
                end
            end
        else
            -- Lỗi runtime trong hàm thực thi
            lastError = result -- Trong trường hợp pcall, error message nằm trong result
            logger.error("Lỗi runtime ở lần thử " .. attempt .. "/" .. maxRetries .. ": " .. tostring(result))
            
            -- Nếu chưa phải lần thử cuối, đợi một khoảng thời gian
            if attempt < maxRetries then
                logger.debug("Đợi " .. delayMs .. "ms trước khi thử lại...")
                mSleep(delayMs)
            end
        end
    end
    
    -- Nếu đã thử hết số lần và vẫn thất bại
    logger.error("Thao tác thất bại sau " .. maxRetries .. " lần thử")
    return false, nil, lastError or "Thao tác thất bại sau tất cả các lần thử"
end

-- Hàm ghi file an toàn với cơ chế atomic write
function utils.writeFileAtomic(filePath, content, backupFirst)
    -- Kiểm tra tham số
    local isValid, errMsg = utils.validateParam(filePath, "filePath", "string", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    -- Tạo backup nếu được yêu cầu và file đã tồn tại
    if backupFirst and io.open(filePath, "r") then
        -- Tên file backup
        local backupPath = filePath .. ".bak"
        
        -- Đọc nội dung file hiện tại
        local origFile = io.open(filePath, "r")
        if not origFile then
            return false, nil, "Không thể mở file gốc để backup"
        end
        
        local origContent = origFile:read("*all")
        origFile:close()
        
        -- Ghi vào file backup
        local backupFile = io.open(backupPath, "w")
        if not backupFile then
            return false, nil, "Không thể tạo file backup"
        end
        
        backupFile:write(origContent)
        backupFile:close()
        
        logger.debug("Đã tạo backup tại: " .. backupPath)
    end
    
    -- File tạm thời
    local tempPath = filePath .. ".tmp"
    
    -- Mở file tạm để ghi
    local tempFile = io.open(tempPath, "w")
    if not tempFile then
        return false, nil, "Không thể tạo file tạm thời"
    end
    
    -- Ghi nội dung vào file tạm
    local success, writeError = pcall(function()
        tempFile:write(content)
        tempFile:flush() -- Đảm bảo dữ liệu được ghi xuống đĩa
        tempFile:close()
    end)
    
    if not success then
        logger.error("Lỗi khi ghi vào file tạm: " .. tostring(writeError))
        os.remove(tempPath) -- Xóa file tạm
        return false, nil, "Lỗi khi ghi file: " .. tostring(writeError)
    end
    
    -- Di chuyển file tạm thành file thật (atomic operation)
    local renameSuccess = os.rename(tempPath, filePath)
    
    if not renameSuccess then
        logger.error("Không thể rename file tạm thành file thật")
        
        -- Phương pháp thay thế nếu rename thất bại
        local backupSuccess = false
        
        -- Đọc lại nội dung từ file tạm
        local tempContent = nil
        local readTempFile = io.open(tempPath, "r")
        
        if readTempFile then
            tempContent = readTempFile:read("*all")
            readTempFile:close()
            
            -- Ghi trực tiếp vào file thật
            local destFile = io.open(filePath, "w")
            if destFile then
                destFile:write(tempContent)
                destFile:close()
                backupSuccess = true
            end
        end
        
        -- Xóa file tạm
        os.remove(tempPath)
        
        if not backupSuccess then
            return false, nil, "Không thể hoàn thành ghi file"
        end
    end
    
    logger.debug("Đã ghi file thành công: " .. filePath)
    return true, filePath, nil
end

-- Hàm đọc file an toàn với cơ chế retry
function utils.readFileSafely(filePath, defaultContent)
    -- Kiểm tra tham số
    local isValid, errMsg = utils.validateParam(filePath, "filePath", "string", true)
    if not isValid then
        return false, nil, errMsg
    end
    
    -- Hàm đọc file
    local readFunc = function()
        local file = io.open(filePath, "r")
        if not file then
            return nil, "Không thể mở file: " .. filePath
        end
        
        local content = file:read("*all")
        file:close()
        
        if not content or content == "" then
            return nil, "File rỗng: " .. filePath
        end
        
        return content
    end
    
    -- Hàm kiểm tra điều kiện thử lại
    local retryCondition = function(result)
        return result == nil
    end
    
    -- Thử đọc file với cơ chế thử lại
    local success, content, error = utils.retryOperation(readFunc, 3, 500, retryCondition)
    
    if not success then
        if defaultContent ~= nil then
            logger.warning("Không thể đọc file " .. filePath .. ", sử dụng nội dung mặc định")
            return true, defaultContent, nil
        else
            return false, nil, error or "Không thể đọc file sau nhiều lần thử"
        end
    end
    
    return true, content, nil
end

-- Xuất các hàm
return {
    -- Kiểm tra và mở ứng dụng
    openTikTokLite = utils.openTikTokLite,
    isTikTokLiteInstalled = utils.isTikTokLiteInstalled,
    checkTikTokLoadedByColor = utils.checkTikTokLoadedByColor,
    waitForScreen = utils.waitForScreen,
    
    -- Tìm kiếm màu
    findColorPattern = utils.findColorPattern,
    convertMatrixToOffsetString = utils.convertMatrixToOffsetString,
    
    -- Thao tác màn hình
    tapWithConfig = utils.tapWithConfig,
    swipeWithConfig = utils.swipeWithConfig,
    swipeNextVideo = utils.swipeNextVideo,
    
    -- Khởi tạo
    getDeviceScreen = utils.getDeviceScreen,
    
    -- Xử lý popup
    checkAndClosePopupByImage = utils.checkAndClosePopupByImage,
    checkAndClosePopup = utils.checkAndClosePopup,
    checkAndCloseAddFriendsPopup = utils.checkAndCloseAddFriendsPopup,
    clickLiveWithPopupCheck = utils.clickLiveWithPopupCheck,
    
    -- Tiện ích khác
    safeExecute = safeExecute,
    
    -- Xử lý lỗi và retry
    retryOperation = utils.retryOperation,
    
    -- I/O an toàn
    writeFileAtomic = utils.writeFileAtomic,
    readFileSafely = utils.readFileSafely,
    
    -- Validation
    validateParam = utils.validateParam,
    
    -- Mã lỗi
    ERROR = utils.ERROR
}
