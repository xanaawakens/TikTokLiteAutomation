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

-- Khởi tạo module tiện ích
local utils = {}

-- Thời gian chờ (sử dụng từ config hoặc giá trị mặc định)
local TIMING = {
    POPUP_DETECTION = config.timing.popup_detection or 5,        -- Thời gian tìm popup (giây)
    POPUP_CHECK_INTERVAL = config.timing.popup_check_interval or 0.2,  -- Thời gian giữa các lần kiểm tra popup (giây)
    AFTER_POPUP_CLOSE = config.timing.after_popup_close or 1,    -- Thời gian sau khi đóng popup (giây)
    SWIPE_STEP_DELAY = config.timing.swipe_step_delay or 0.005,  -- Độ trễ giữa các bước vuốt (giây)
    APP_CLOSE_WAIT = config.timing.app_close_wait or 3,          -- Thời gian chờ sau khi đóng app (giây)
    FIND_COLOR_TIMEOUT = config.timing.find_color_timeout or 5   -- Thời gian tối đa tìm kiếm màu (giây)
}

-- Hàm bắt lỗi thực thi an toàn
local function safeExecute(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        return false, "Lỗi thực thi: " .. tostring(result)
    end
    return true, result
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
    similarity = similarity or config.accuracy.color_similarity
    
    -- Lấy kích thước màn hình
    local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    
    -- Xác định vùng tìm kiếm
    local x1, y1, x2, y2
    if region then
        x1, y1, x2, y2 = region[1], region[2], region[3], region[4]
    else
        x1, y1, x2, y2 = 0, 0, width, height
    end
    
    -- Kiểm tra ma trận đầu vào
    if not matrix or #matrix < 1 then
        return false, nil, nil, "Ma trận màu không hợp lệ"
    end
    
    -- Thực thi an toàn việc chuyển đổi ma trận
    local success, mainColor, mainX, mainY, offsetStr = pcall(utils.convertMatrixToOffsetString, matrix)
    
    if not success then
        return false, nil, nil, "Lỗi khi chuyển đổi ma trận: " .. tostring(mainColor) -- mainColor chứa thông báo lỗi khi pcall thất bại
    end
    
    if not mainColor or not offsetStr then
        return false, nil, nil, "Không thể chuyển đổi ma trận màu"
    end
    
    -- Tìm kiếm mẫu màu trong vùng chỉ định
    local startTime = os.time()
    
    while os.time() - startTime < TIMING.FIND_COLOR_TIMEOUT do
        local x, y = findMultiColorInRegionFuzzy(mainColor, offsetStr, similarity, x1, y1, x2, y2)
        
        -- Trả về kết quả tìm kiếm
        if x ~= -1 and y ~= -1 then
            nLog("Tìm thấy mẫu màu tại " .. x .. "," .. y)
            return true, x, y, nil
        end
        
        mSleep(100)  -- Đợi một chút trước khi thử lại
    end
    
    return false, nil, nil, "Không tìm thấy mẫu màu sau " .. TIMING.FIND_COLOR_TIMEOUT .. " giây"
end

-- Kiểm tra TikTok Lite đã load xong chưa
function utils.checkTikTokLoadedByColor()
    -- Sử dụng vùng tìm kiếm nếu được cấu hình
    local region = config.search_regions and config.search_regions.tiktok_loaded
    local found, x, y, error = utils.findColorPattern(config.tiktok_matrix, region)
    
    if found then
        toast("TikTok Lite đã load thành công")
        return true, nil
    else
        return false, error or "Không thể xác nhận TikTok Lite đã load"
    end
end

-- Tiện ích tương tác ứng dụng
------------------------------

-- Mở ứng dụng TikTok Lite và đợi cho đến khi tải xong
function utils.openTikTokLite(skipCheck)
    local bundleID = config.app.bundle_id
    local appName = config.app.name
    
    toast("Đang mở " .. appName)
    
    -- Kiểm tra app có đang chạy không trước khi mở
    local isRunning = appIsRunning(bundleID)
    nLog("Kiểm tra: TikTok " .. (isRunning and "đang chạy" or "không chạy"))
    
    -- Đóng app nếu đang chạy để mở lại từ đầu
    if isRunning then
        nLog("Đóng TikTok đang chạy...")
        local closeSuccess, closeError = safeExecute(closeApp, bundleID)
        if not closeSuccess then
            return false, "Lỗi khi đóng app: " .. closeError
        end
        mSleep(TIMING.APP_CLOSE_WAIT * 1000)
    end
    
    -- Mở ứng dụng TikTok Lite
    local openSuccess, openResult = safeExecute(runApp, bundleID)
    
    if not openSuccess or not openResult then
        toast("Lỗi: Không thể mở TikTok Lite")
        return false, "Không thể mở TikTok Lite: " .. (openSuccess and "App không tồn tại" or openResult)
    end
    
    -- Đợi app khởi động
    local waitTime = config.timing.launch_wait
    for i = 1, waitTime do
        mSleep(1000)
    end
    
    -- Kiểm tra và đóng popup Add Friends nếu xuất hiện
    nLog("Kiểm tra popup Add Friends sau khi mở app...")
    local popupClosed, popupError = utils.checkAndClosePopupByImage("popupAddFriends.png", {400, 1267})
    if popupClosed then
        nLog("Đã đóng popup Add Friends")
    elseif popupError then
        nLog("Lỗi khi xử lý popup: " .. popupError)
    end
    
    -- Bỏ qua kiểm tra nếu được yêu cầu
    if skipCheck then
        nLog("Bỏ qua kiểm tra, coi như đã mở thành công")
        return true, nil
    end
    
    -- Kiểm tra app có ở foreground không
    local isFront = isFrontApp(bundleID)
    if not isFront then
        return false, "TikTok không ở foreground sau khi mở"
    end
    
    -- Kiểm tra giao diện đã load
    if config.check_ui_after_launch then
        local loaded, loadError = utils.checkTikTokLoadedByColor()
        if not loaded then
            return false, loadError or "Giao diện TikTok chưa load hoàn tất"
        end
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
    nLog("Kiểm tra: TikTok Lite " .. (appExists and "đã được cài đặt" or "chưa được cài đặt"))
    
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
            nLog("Đã tìm thấy " .. description)
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
function utils.tapWithConfig(x, y, description)
    description = description or "vị trí"
    
    if not x or not y then
        return false, "Tọa độ không hợp lệ"
    end
    
    local success, result = safeExecute(tap, x, y)
    if not success then
        return false, "Lỗi khi tap vào " .. description .. ": " .. result
    end
    
    nLog("Đã tap vào " .. description .. " (" .. x .. "," .. y .. ")")
    mSleep(config.timing.tap_delay * 1000)
    return true, nil
end

-- Thực hiện vuốt với độ trễ từ cấu hình
function utils.swipeWithConfig(x1, y1, x2, y2, duration, description)
    description = description or "màn hình"
    duration = duration or config.ui.swipe.duration
    
    if not x1 or not y1 or not x2 or not y2 then
        return false, "Tọa độ không hợp lệ"
    end
    
    local success, result = safeExecute(moveTo, x1, y1, x2, y2, duration)
    if not success then
        return false, "Lỗi khi vuốt " .. description .. ": " .. result
    end
    
    nLog("Đã vuốt từ (" .. x1 .. "," .. y1 .. ") đến (" .. x2 .. "," .. y2 .. ")")
    mSleep(config.timing.swipe_delay * 1000)
    return true, nil
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
    
    nLog("Bắt đầu tìm kiếm popup " .. imageName .. " - Thời gian tối đa: " .. timeout .. " giây")
    
    local startTime = os.time()
    
    while (os.time() - startTime < timeout) do
        local x, y = findImageInRegionFuzzy(imageName, config.accuracy.image_similarity, 0, 0, width, height, 0, 1)
        
        if x ~= -1 and y ~= -1 then
            nLog("Đã tìm thấy popup " .. imageName .. " tại vị trí " .. x .. "," .. y)
            
            -- Phương thức đóng popup: Click hoặc Swipe
            if clickCoords then
                -- Đóng bằng click vào tọa độ cụ thể
                local clickX = clickCoords[1]
                local clickY = clickCoords[2]
                
                nLog("Đóng popup bằng cách click vào vị trí " .. clickX .. "," .. clickY)
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
                
                nLog("Đóng popup bằng cách vuốt từ (" .. swipeStartX .. "," .. swipeStartY .. ") đến (" .. swipeEndX .. "," .. swipeEndY .. ")")
                
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
    
    nLog("Không tìm thấy popup " .. imageName .. " sau " .. timeout .. " giây")
    return false, nil -- Không tìm thấy popup, không phải lỗi
end

-- Hàm kiểm tra và đóng popup ở vùng màn hình cụ thể
function utils.checkAndClosePopup()
    return utils.checkAndClosePopupByImage("popup1.png", nil, true)
end

-- Hàm kiểm tra và đóng popup Add Friends khi mới mở app TikTok
function utils.checkAndCloseAddFriendsPopup()
    return utils.checkAndClosePopupByImage("popupAddFriends.png", {80, 1270})
end

-- Hàm bấm vào nút live sau khi kiểm tra popup
function utils.clickLiveWithPopupCheck(liveButtonX, liveButtonY)
    local popupClosed, popupError = utils.checkAndClosePopup()
    
    if popupClosed then
        nLog("Đã đóng popup, tiếp tục bấm nút live")
    elseif popupError then
        nLog("Lỗi khi xử lý popup: " .. popupError)
    else
        nLog("Không tìm thấy popup, tiếp tục bấm nút live")
    end
    
    -- Đợi sau khi kiểm tra popup
    mSleep(TIMING.AFTER_POPUP_CLOSE * 1000)
    
    -- Bấm vào nút live
    return utils.tapWithConfig(liveButtonX, liveButtonY, "nút live")
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
    safeExecute = safeExecute
}
