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

-- Tiện ích xử lý tìm kiếm màu sắc
----------------------------------

-- Chuyển đổi ma trận màu sang định dạng offset cho findMultiColorInRegionFuzzy
function convertMatrixToOffsetString(matrix)
    if not matrix or #matrix < 2 then
        return nil, nil, nil
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
function findColorPattern(matrix, region, similarity)
    similarity = similarity or config.accuracy.color_similarity
    
    -- Lấy kích thước màn hình
    local width, height = getScreenSize()
    
    -- Xác định vùng tìm kiếm
    local x1, y1, x2, y2
    if region then
        x1, y1, x2, y2 = region[1], region[2], region[3], region[4]
    else
        x1, y1, x2, y2 = 0, 0, width, height
    end
    
    -- Chuyển đổi ma trận
    local mainColor, mainX, mainY, offsetStr = convertMatrixToOffsetString(matrix)
    
    if not mainColor or not offsetStr then
        return false, nil, nil
    end
    
    -- Tìm kiếm mẫu màu trong vùng chỉ định
    local x, y = findMultiColorInRegionFuzzy(mainColor, offsetStr, similarity, x1, y1, x2, y2)
    
    -- Trả về kết quả tìm kiếm
    if x ~= -1 and y ~= -1 then
        return true, x, y
    else
        return false, nil, nil
    end
end

-- Kiểm tra TikTok Lite đã load xong chưa
function checkTikTokLoadedByColor()
    -- Sử dụng vùng tìm kiếm nếu được cấu hình
    local region = config.search_regions and config.search_regions.tiktok_loaded
    local found, x, y = findColorPattern(config.tiktok_matrix, region)
    
    if found then
        toast("TikTok Lite đã load thành công")
    end
    
    return found
end

-- Tiện ích tương tác ứng dụng
------------------------------

-- Mở ứng dụng TikTok Lite và đợi cho đến khi tải xong
function openTikTokLite(skipCheck)
    local bundleID = config.app.bundle_id
    local appName = config.app.name
    
    toast("Đang mở " .. appName)
    
    -- Kiểm tra app có đang chạy không trước khi mở
    local isRunning = appIsRunning(bundleID)
    toast("Kiểm tra: TikTok " .. (isRunning and "đang chạy" or "không chạy"))
    
    -- Đóng app nếu đang chạy để mở lại từ đầu
    if isRunning then
        toast("Đóng TikTok đang chạy...")
        closeApp(bundleID)
        mSleep(3000)
    end
    
    -- Mở ứng dụng TikTok Lite
    toast("Thực hiện lệnh mở TikTok...")
    local openResult = runApp(bundleID)
    
    if not openResult then
        toast("Lỗi: Không thể mở TikTok Lite")
        return false
    end
    
    -- Đợi app khởi động
    local waitTime = config.timing.launch_wait
    for i = 1, waitTime do
        toast("Khởi động ứng dụng... " .. i .. "/" .. waitTime)
        mSleep(1000)
    end
    
    -- Kiểm tra và đóng popup Add Friends nếu xuất hiện
    toast("Kiểm tra popup Add Friends sau khi mở app...")
    if checkAndCloseAddFriendsPopup() then
        toast("Đã đóng popup Add Friends")
    else
        toast("Không thấy popup Add Friends hoặc đã đóng tự động")
    end
    
    -- Bỏ qua kiểm tra nếu được yêu cầu
    if skipCheck then
        toast("Bỏ qua kiểm tra, coi như đã mở thành công")
        return true
    end
    
    -- Kiểm tra app có ở foreground không
    local isFront = isFrontApp(bundleID)
    toast("Kiểm tra: TikTok " .. (isFront and "đang ở foreground" or "không ở foreground"))
    
    if isFront then
        -- Kiểm tra ma trận màu để xác nhận app đã load xong
        local loaded = checkTikTokLoadedByColor()
        toast("Kiểm tra giao diện: " .. (loaded and "Đã load" or "Chưa load"))
        
        if loaded then
            return true
        else
            toast("Giao diện TikTok chưa load hoàn tất")
        end
    else
        toast("TikTok không ở foreground sau khi mở")
    end
    
    return isFront
end

-- Kiểm tra TikTok Lite đã được cài đặt chưa (không mở app)
function isTikTokLiteInstalled()
    local bundleID = config.app.bundle_id
    
    -- Phương pháp 1: Dùng appIsInstalled (nếu có)
    if type(appIsInstalled) == "function" then
        if appIsInstalled(bundleID) then
            return true
        end
    end
    
    -- Phương pháp 2: Kiểm tra app có thể chạy không
    if appIsRunning(bundleID) then
        return true
    end
    
    -- Phương pháp 3: Kiểm tra trong danh sách app đã cài đặt
    if type(getInstalledApps) == "function" then
        local apps = getInstalledApps()
        if apps then
            for _, app in ipairs(apps) do
                if app.bid == bundleID then
                    return true
                end
            end
        end
    end
    
    -- Chỉ trả về kết quả dựa trên việc kiểm tra, không mở app để thử
    toast("Kiểm tra: TikTok Lite " .. (appExist(bundleID) and "đã được cài đặt" or "chưa được cài đặt"))
    return appExist(bundleID)
end

-- Đợi màn hình hiển thị màu hoặc hình ảnh cụ thể
function waitForScreen(colorOrImage, x, y, sim, timeout)
    sim = sim or config.accuracy.color_similarity
    timeout = timeout or config.timing.check_timeout
    
    local startTime = os.time()
    while os.time() - startTime < timeout do
        if type(colorOrImage) == "number" then
            -- Kiểm tra màu
            if isColor(x, y, colorOrImage, sim) then
                return true
            end
        else
            -- Kiểm tra hình ảnh
            local result = findImage(colorOrImage, sim)
            if result then
                return true
            end
        end
        mSleep(500)
    end
    
    return false
end

-- Tiện ích thao tác màn hình
-----------------------------

-- Thực hiện tap với độ trễ từ cấu hình
function tapWithConfig(x, y)
    tap(x, y)
    mSleep(config.timing.tap_delay * 1000)
end

-- Thực hiện vuốt với độ trễ từ cấu hình
function swipeWithConfig(x1, y1, x2, y2, duration)
    duration = duration or config.ui.swipe.duration
    moveTo(x1, y1, x2, y2, duration)
    mSleep(config.timing.swipe_delay * 1000)
end

-- Vuốt lên để xem video tiếp theo
function swipeNextVideo()
    local swipe = config.ui.swipe
    swipeWithConfig(swipe.start_x, swipe.start_y, swipe.end_x, swipe.end_y)
end

-- Tiện ích khởi tạo
-------------------

-- Lấy kích thước màn hình
function getDeviceScreen()
    local width, height = getScreenSize()
    return width, height
end

-- Khởi tạo ghi log
function initLogging()
    if not config.logging.enabled then
        return
    end
    
    if config.logging.save_to_file then
        local logPath = config.paths.logs
        
        -- Tạo thư mục log nếu chưa tồn tại
        if not isFileExist(logPath) and type(newfolder) == "function" then
            newfolder(logPath)
        end
        
        -- Đường dẫn file log
        local logFile = logPath .. os.date("%Y-%m-%d") .. ".log"
        
        -- Khởi tạo log file
        pcall(function()
            initLog(logFile, config.logging.level:upper())
        end)
    end
end

-- Hàm kiểm tra và đóng popup ở vùng màn hình cụ thể
function checkAndClosePopup()
    -- Lấy kích thước màn hình để tìm kiếm toàn màn hình
    local width, height = getScreenSize()
    
    -- Đường dẫn đến hình ảnh popup
    local popupImage = "popup1.png"  -- Không cần đường dẫn đầy đủ, chỉ cần tên file trong thư mục res
    
    -- Thiết lập thời gian tìm kiếm tối đa là 5 giây
    local startTime = os.time()
    local timeoutSeconds = 5
    
    nLog("Bắt đầu tìm kiếm popup - Thời gian tối đa: " .. timeoutSeconds .. " giây")
    
    -- Lặp tìm kiếm popup trong khoảng thời gian 5 giây
    while (os.time() - startTime < timeoutSeconds) do
        -- Tìm kiếm hình ảnh popup1.png trên toàn màn hình với phương pháp nhị phân hóa (kind=1)
        local x, y = findImageInRegionFuzzy(popupImage, 90, 0, 0, width, height, 0, 1)
        
        if x ~= -1 and y ~= -1 then  -- Kiểm tra đúng cách: x, y khác -1 là tìm thấy
            nLog("Đã tìm thấy popup tại vị trí " .. x .. "," .. y .. " sau " .. (os.time() - startTime) .. " giây")
            
            -- Tính toán điểm vuốt (từ dưới lên trên popup)
            local swipeStartX = x + 50 -- Điểm vuốt cách vị trí tìm thấy 50px theo chiều ngang
            local swipeStartY = y + 100 -- Điểm bắt đầu vuốt ở dưới popup
            local swipeEndX = swipeStartX -- Cùng vị trí X
            local swipeEndY = y - 50 -- Điểm kết thúc vuốt ở trên popup
            
            -- Đảm bảo điểm vuốt nằm trong màn hình
            swipeStartY = math.min(swipeStartY, height - 10)
            swipeEndY = math.max(swipeEndY, 10)
            
            -- Thực hiện vuốt để đóng popup
            nLog("Đang vuốt để đóng popup từ (" .. swipeStartX .. "," .. swipeStartY .. ") đến (" .. swipeEndX .. "," .. swipeEndY .. ")")
            
            touchDown(1, swipeStartX, swipeStartY)
            mSleep(50)
            
            -- Di chuyển ngón tay lên trên để đóng popup
            for i = 1, 10 do
                local currentY = swipeStartY - i * ((swipeStartY - swipeEndY) / 10)
                touchMove(1, swipeStartX, currentY)
                mSleep(5)
            end
            
            touchUp(1, swipeEndX, swipeEndY)
            
            -- Đợi sau khi đóng popup
            mSleep(1000)
            
            return true -- Đã tìm thấy và đóng popup
        end
        
        -- Đợi 200ms trước khi tìm kiếm lại
        mSleep(200)
    end
    
    nLog("Không tìm thấy popup sau " .. timeoutSeconds .. " giây")
    return false -- Không tìm thấy popup
end

-- Hàm bấm vào nút live sau khi kiểm tra popup
function clickLiveWithPopupCheck(liveButtonX, liveButtonY)
    if checkAndClosePopup() then
        nLog("Đã đóng popup, tiếp tục bấm nút live")
    else
        nLog("Không có popup, tiếp tục bấm nút live")
    end
    
    -- Đợi sau khi kiểm tra popup
    mSleep(1000)
    
    -- Bấm vào nút live
    tap(liveButtonX, liveButtonY)
end

-- Hàm kiểm tra và đóng popup Add Friends khi mới mở app TikTok
function checkAndCloseAddFriendsPopup()
    -- Lấy kích thước màn hình để tìm kiếm toàn màn hình
    local width, height = getScreenSize()
    
    -- Đường dẫn đến hình ảnh popup
    local popupImage = "popupAddFriends.png"
    
    -- Thiết lập thời gian tìm kiếm tối đa là 5 giây
    local startTime = os.time()
    local timeoutSeconds = 5
    
    nLog("Bắt đầu tìm kiếm popup Add Friends - Thời gian tối đa: " .. timeoutSeconds .. " giây")
    
    -- Lặp tìm kiếm popup trong khoảng thời gian 5 giây
    while (os.time() - startTime < timeoutSeconds) do
        -- Tìm kiếm hình ảnh popupAddFriends.png trên toàn màn hình với phương pháp nhị phân hóa (kind=1)
        local x, y = findImageInRegionFuzzy(popupImage, 90, 0, 0, width, height, 0, 1)
        
        if x ~= -1 and y ~= -1 then  -- Kiểm tra đúng cách: x, y khác -1 là tìm thấy
            nLog("Đã tìm thấy popup Add Friends tại vị trí " .. x .. "," .. y .. " sau " .. (os.time() - startTime) .. " giây")
            
            -- Click vào vị trí 400,1267 để đóng popup
            local closeX = 400
            local closeY = 1267
            
            nLog("Đóng popup Add Friends bằng cách click vào vị trí " .. closeX .. "," .. closeY)
            
            -- Thực hiện click
            touchDown(1, closeX, closeY)
            mSleep(50)
            touchUp(1, closeX, closeY)
            
            -- Đợi sau khi đóng popup
            mSleep(1000)
            
            return true -- Đã tìm thấy và đóng popup
        end
        
        -- Đợi 200ms trước khi tìm kiếm lại
        mSleep(200)
    end
    
    nLog("Không tìm thấy popup Add Friends sau " .. timeoutSeconds .. " giây")
    return false -- Không tìm thấy popup
end

-- Xuất các hàm
return {
    -- Kiểm tra và mở ứng dụng
    openTikTokLite = openTikTokLite,
    isTikTokLiteInstalled = isTikTokLiteInstalled,
    checkTikTokLoadedByColor = checkTikTokLoadedByColor,
    waitForScreen = waitForScreen,
    
    -- Tìm kiếm màu
    findColorPattern = findColorPattern,
    convertMatrixToOffsetString = convertMatrixToOffsetString,
    
    -- Thao tác màn hình
    tapWithConfig = tapWithConfig,
    swipeWithConfig = swipeWithConfig,
    swipeNextVideo = swipeNextVideo,
    
    -- Khởi tạo
    getDeviceScreen = getDeviceScreen,
    initLogging = initLogging,
    
    -- Xử lý popup
    checkAndClosePopup = checkAndClosePopup,
    checkAndCloseAddFriendsPopup = checkAndCloseAddFriendsPopup,
    clickLiveWithPopupCheck = clickLiveWithPopupCheck
}
