-- Module auto_tiktok.lua - Chức năng tự động hóa TikTok Lite
-- Mô tả: Chứa các hàm để tự động mở TikTok Lite, xem live stream và thu thập phần thưởng

require("TSLib")
local config = require("config")
local utils = require("utils")
local rewards_live = require("rewards_live")
local logger = require("logger")
local fileManager = require("file_manager") -- Thêm module quản lý file mới
local dailyCheckin = require("daily_checkin") -- Thêm module điểm danh hàng ngày

local autoTiktok = {}

-- Hàm safeToString đơn giản để tránh phụ thuộc vào utils.safeToString
local function safeToString(value)
    if value == nil then
        return "nil"
    elseif type(value) == "string" then
        return value
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    elseif type(value) == "table" then
        return "{table}"
    elseif type(value) == "function" then
        return "{function}"
    elseif type(value) == "userdata" or type(value) == "thread" then
        return "{" .. type(value) .. "}"
    else
        return "{unknown type: " .. type(value) .. "}"
    end
end

-- Khởi tạo và mở ứng dụng TikTok Lite
local function initializeApp()
    -- Mở TikTok Lite
    local success, error = utils.openTikTokLite(false)
    
    if not success then
        return false, "Không thể mở TikTok Lite: " .. safeToString(error or "")
    end
    
    mSleep(3000)
    
    -- Kiểm tra và đóng popup Add Friends nếu xuất hiện
    local popupClosed, popupError = utils.checkAndCloseAddFriendsPopup()
    if popupClosed then
        logger.info("Đã đóng popup Add Friends sau khi mở ứng dụng")
        -- Đợi một chút sau khi đóng popup
        mSleep(config.timing.after_popup_close * 1000)
    end
    
    return true, nil
end

-- Di chuyển đến màn hình xem live stream
local function navigateToLiveStream()
    -- Bấm vào nút xem live
    local tapped, tapError = rewards_live.tapLiveButton()
    
    if not tapped then
        return false, tapError or "Không thể tìm thấy nút xem live"
    end
    
    -- Kiểm tra đã load chưa
    local liveLoaded = false
    local maxLoadAttempts = 5  -- Giới hạn số lần thử
    local loadAttempt = 0
    
    while not liveLoaded and loadAttempt < maxLoadAttempts do
        loadAttempt = loadAttempt + 1
        liveLoaded, _ = rewards_live.waitForLiveScreen()
        
        if not liveLoaded then
            logger.info("Màn hình live chưa load, chờ 3s và kiểm tra lại...")
            mSleep(3000)
        end
    end
    
    if not liveLoaded then
        return false, "Không thể xác nhận màn hình live đã load sau nhiều lần thử"
    end
    
    mSleep(2000)
    return true, nil
end

-- Xử lý các popup sau khi claim
local function handlePopupsAfterClaim()
    local screenW, screenH = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    
    -- Đợi một chút trước khi kiểm tra popup (giảm thời gian chờ)
    mSleep(config.timing.popup_check_after_claim * 1000)
    
    -- Kiểm tra 2 lần cho popup nâng cấp phần thưởng (giảm từ 3 lần xuống 2 lần)
    for i = 1, 2 do
        local rewardX, rewardY = findImageInRegionFuzzy(config.images.popup.reward, config.accuracy.image_similarity, 1, 1, screenW, screenH, 0)
        if rewardX ~= -1 and rewardY ~= -1 then
            logger.info("Đóng popup nâng cấp phần thưởng sau khi claim - lần " .. i)
            tap(config.popup_close.reward[1], config.popup_close.reward[2])
            mSleep(config.timing.after_popup_close * 1000)
            break -- Thoát vòng lặp sau khi xử lý popup
        end
    end

    -- Kiểm tra 2 lần cho popup nhiệm vụ (giảm từ 3 lần xuống 2 lần)
    for i = 1, 2 do
        local missionX, missionY = findImageInRegionFuzzy(config.images.popup.mission, config.accuracy.image_similarity, 1, 1, screenW, screenH, 0)
        if missionX ~= -1 and missionY ~= -1 then
            logger.info("Đóng popup nhiệm vụ - lần " .. i)
            tap(config.popup_close.mission[1], config.popup_close.mission[2])
            mSleep(config.timing.after_popup_close * 1000)
            break -- Thoát vòng lặp sau khi xử lý popup
        end
    end
    
    -- Đợi thêm một chút trước khi tiếp tục (giảm thời gian chờ)
    mSleep(config.timing.after_popup_close * 1000)
    
    return true, nil
end

-- Hàm mở TikTok Lite và thực hiện các tác vụ tự động
function autoTiktok.runTikTokLiteAutomation()
    local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    
    -- 1. Khởi tạo ứng dụng
    logger.info("===== PHẦN 1: ĐIỂM DANH HÀNG NGÀY =====")
    logger.info("Khởi tạo ứng dụng cho phần điểm danh...")
    local success, error = initializeApp()
    if not success then
        return false, error
    end

    -- 2. Thực hiện điểm danh hàng ngày
    logger.info("Thực hiện điểm danh hàng ngày...")
    local checkinSuccess, checkinError = dailyCheckin.performDailyCheckin()
    
    -- Không quan tâm kết quả thành công hay thất bại, tiếp tục nhiệm vụ tiếp theo
    logger.info("Hoàn thành bước điểm danh, tiếp tục nhiệm vụ xem live...")
    
    -- 3. Đóng ứng dụng sau khi điểm danh
    logger.info("Đóng ứng dụng sau khi điểm danh...")
    
    -- Đảm bảo đóng app hoàn toàn
    local bundleID = config.app.bundle_id
    closeApp(bundleID)
    logger.info("Đã gửi lệnh đóng TikTok Lite")
    
    -- Đợi lâu hơn để đảm bảo app đóng hoàn toàn
    mSleep(1000)
    
    -- 4. Mở lại ứng dụng để thực hiện nhiệm vụ xem live
    logger.info("===== PHẦN 2: NHIỆM VỤ XEM LIVE =====")
    logger.info("Khởi tạo lại ứng dụng cho phần xem live...")
    success, error = initializeApp()
    if not success then
        return false, error
    end
    
    -- 5. Di chuyển đến màn hình xem live
    local navSuccess, navError = navigateToLiveStream()
    if not navSuccess then
        return false, navError
    end
    
    -- 6. Đợi để giao diện ổn định
    mSleep(config.timing.ui_stabilize * 1000)
    
    -- 7. Vuốt để chuyển sang 1 live stream khác (tránh live stream đầu tiên)
    local midX = math.floor(width / 2)       -- Giữa màn hình theo chiều ngang
    local startY = math.floor(height * 0.9)  -- Gần dưới cùng màn hình  
    local endY = math.floor(height * 0.6)    -- Khoảng giữa màn hình
    
    -- Vuốt trực tiếp bằng touchDown, touchMove, touchUp
    touchDown(1, midX, startY)
    mSleep(100)
    for i = 1, 10 do
        local moveY = startY - (i * (startY - endY) / 10)
        touchMove(1, midX, moveY)
        mSleep(20)
    end
    touchUp(1, midX, endY)
    
    mSleep(3000)
    logger.info("Vuốt xuống stream khác...")
    
    -- Kiểm tra xem live stream mới đã load xong chưa
    local liveLoaded, loadError = rewards_live.waitForLiveScreen(8)
    if not liveLoaded then
        logger.warning("Không thể xác nhận live stream đã load sau khi vuốt: " .. safeToString(loadError or ""))
        -- Thử vuốt lần nữa nếu live stream chưa load
    end
    
    -- Second swipe to ensure we're in a good live stream
    touchDown(1, midX, startY)
    mSleep(100)
    for i = 1, 10 do
        local moveY = startY - (i * (startY - endY) / 10)
        touchMove(1, midX, moveY)
        mSleep(20)
    end
    touchUp(1, midX, endY)
    
    mSleep(3000)
    
    -- Kiểm tra xem live stream thứ hai đã load xong chưa
    liveLoaded, loadError = rewards_live.waitForLiveScreen(8)
    if not liveLoaded then
        logger.warning("Không thể xác nhận live stream thứ hai đã load sau khi vuốt: " .. safeToString(loadError or ""))
        return false, "Không thể xác nhận live stream đã load sau khi vuốt"
    else
        logger.info("Đã xác nhận live stream đã load thành công")
    end
    
    -- 8. Check và click vào nút phần thưởng
    local rewardTapped = false
    local rewardError = nil
    local maxRewardAttempts = 4  -- Kiểm tra trong (4 lần * 1.5s)
    local rewardAttempt = 0
    
    while not rewardTapped and rewardAttempt < maxRewardAttempts do
        rewardAttempt = rewardAttempt + 1
        logger.info("Tìm nút phần thưởng, lần thử " .. rewardAttempt .. "/" .. maxRewardAttempts)
        
        rewardTapped, rewardError = rewards_live.tapRewardButton()
        
        if rewardTapped then
            logger.info("Đã bấm vào nút phần thưởng")
            break
        else
            mSleep(1500)  -- Chờ 1.5s trước khi thử lại
        end
    end
    
    if not rewardTapped then
        return false, rewardError or "Không tìm thấy nút phần thưởng sau nhiều lần thử"
    end
    
    -- Kiểm tra và đợi cho màn hình phần thưởng load
    logger.info("Kiểm tra xem đã vào màn hình phần thưởng chưa...")
    local inRewardScreen, rewardScreenError = rewards_live.waitForRewardScreen()
    if not inRewardScreen then
        logger.warning("Không thể xác nhận đang ở màn hình phần thưởng: " .. safeToString(rewardScreenError or ""))
        logger.info("Thực hiện quy trình khôi phục khi không load được màn hình phần thưởng...")
        
        -- 1. Bấm vào tọa độ 444, 444
        logger.info("Bấm vào tọa độ (444, 444) để thoát khỏi trạng thái hiện tại")
        tap(444, 444)
        mSleep(2000)
        
        -- 2. Thực hiện vuốt để chuyển sang stream mới
        logger.info("Vuốt để chuyển sang stream mới...")
        touchDown(1, midX, startY)
        mSleep(100)
        for i = 1, 10 do
            local moveY = startY - (i * (startY - endY) / 10)
            touchMove(1, midX, moveY)
            mSleep(20)
        end
        touchUp(1, midX, endY)
        mSleep(3000)
        
        -- 3. Kiểm tra xem đã trong màn hình live chưa
        logger.info("Kiểm tra xem đã load được màn hình live chưa...")
        local liveScreenLoaded, liveError = rewards_live.waitForLiveScreen(8)
        if not liveScreenLoaded then
            logger.warning("Không thể xác nhận đã vào màn hình live sau khi khôi phục: " .. safeToString(liveError or ""))
            return false, "Không thể khôi phục màn hình live sau khi gặp lỗi"
        end
        
        logger.info("Đã vào lại màn hình live thành công")
        
        -- 4. Bấm vào nút phần thưởng lại
        logger.info("Tìm và bấm vào nút phần thưởng lần nữa...")
        local rewardRetapped, retapError = rewards_live.tapRewardButton()
        if not rewardRetapped then
            logger.warning("Không thể tìm thấy nút phần thưởng sau khi khôi phục: " .. safeToString(retapError or ""))
            return false, "Không thể tìm lại nút phần thưởng sau khi khôi phục"
        end
        
        -- 5. Kiểm tra lại màn hình phần thưởng
        logger.info("Kiểm tra lại màn hình phần thưởng...")
        inRewardScreen, rewardScreenError = rewards_live.waitForRewardScreen()
        if not inRewardScreen then
            logger.warning("Vẫn không thể vào màn hình phần thưởng sau khi khôi phục: " .. safeToString(rewardScreenError or ""))
            return false, "Không thể vào màn hình phần thưởng sau khi khôi phục"
        end
        
        logger.info("Đã vào màn hình phần thưởng thành công sau khi khôi phục!")
    else
        logger.info("Đã vào màn hình phần thưởng thành công!")
    end
    
    -- 9. Thực hiện kéo xuống bên dưới (vuốt từ dưới đi lên)
    local startY = math.floor(height * 0.9)   -- Gần dưới cùng màn hình
    local endY = math.floor(height * 0.6)     -- Khoảng giữa màn hình
    local midX = math.floor(width / 2)       -- Giữa màn hình theo chiều ngang
    
    touchDown(1, midX, startY)
    mSleep(100)
    for i = 1, 10 do
        local moveY = startY - (i * (startY - endY) / 10)
        touchMove(1, midX, moveY)
        mSleep(10)
    end
    touchUp(1, midX, endY)
    
    -- Đợi màn hình ổn định sau khi vuốt
    mSleep(2000)
    
    -- 10. Check nút complete lần 1
    local completeFound, _, _, _ = rewards_live.checkCompleteButton(true)
    
    if completeFound then
        return true, "Hoàn thành nhiệm vụ thành công ngay sau lần đầu kiểm tra"
    end
    
    -- Vào vòng lặp xử lý claim
    local lastClaimFoundTime = os.time()  -- Thời điểm cuối cùng tìm thấy nút claim
    local firstClaimTime = nil            -- Thời điểm claim đầu tiên
    local lastPopupCheckTime = 0          -- Thời điểm kiểm tra popup cuối cùng
    local monitorStartTime = os.time()    -- Thời điểm bắt đầu giám sát
    local claimFound = false
    local claimCheckInterval = config.timing.claim_check_interval or 1
    local consecutiveFailures = 0
    local adaptiveInterval = claimCheckInterval
        
    -- 11. Vòng lặp chính - kiểm tra claim và complete
    while true do
        -- Kiểm tra và bấm nút Claim
        local startTime = os.time()
        claimFound, claimError = rewards_live.tapClaimButton(true)
        
        if claimFound then
            consecutiveFailures = 0
            adaptiveInterval = claimCheckInterval
            
            lastClaimFoundTime = os.time()  -- Cập nhật thời điểm tìm thấy claim
            logger.debug("Đã tap vào nút claim thành công")
            
            -- Ghi nhận thời điểm claim đầu tiên
            if firstClaimTime == nil then
                firstClaimTime = os.time()
            end
            
            -- Đợi sau khi bấm nút claim (sử dụng thời gian cấu hình)
            mSleep(config.timing.after_claim_delay * 1000)
            
            -- Xử lý các popup sau khi claim
            handlePopupsAfterClaim()
            
            -- Kiểm tra nút complete sau khi claim thành công
            completeFound, _, _, _ = rewards_live.checkCompleteButton(true)
            
            if completeFound then
                return true, "Hoàn thành nhiệm vụ thành công sau khi claim"
            end
            
            -- Đợi 5 giây rồi kiểm tra lại nút claim
            -- Nếu vẫn còn nút claim (không thay đổi) thì báo lỗi
            logger.info("Đợi 20s và kiểm tra xem nút claim còn hiện diện không...")
            mSleep(20000)
            
            local stillClaimButton, _, _, _ = rewards_live.checkClaimButton(true)
            if stillClaimButton then
                logger.warning("Lỗi: Something went wrong")
                return false, "Lỗi Something went wrong"
            end
        else
            -- Tăng số lần thất bại liên tiếp
            consecutiveFailures = consecutiveFailures + 1
            
            -- Điều chỉnh khoảng thời gian kiểm tra dựa trên số lần thất bại
            if consecutiveFailures > 5 then
                -- Nếu không tìm thấy claim sau nhiều lần, tăng khoảng cách để giảm tải CPU
                adaptiveInterval = math.min(3, claimCheckInterval + 0.5 * math.floor(consecutiveFailures / 5))
                logger.debug("Điều chỉnh khoảng thời gian kiểm tra claim lên " .. adaptiveInterval .. "s sau " .. consecutiveFailures .. " lần thất bại", true)
            end
        end
        
        -- Xử lý stream kết thúc (kiểm tra hiệu quả hơn sau nhiều lần không tìm thấy claim)
        if lastClaimFoundTime ~= nil and os.time() - lastClaimFoundTime >= 15 then
            -- Kiểm tra nút phần thưởng - nếu có thì phiên live đã kết thúc
            local rewardFound, rx, ry, _ = rewards_live.checkRewardButton(true)
            
            if rewardFound then
                logger.info("Tìm thấy nút phần thưởng - phiên live hiện tại đã kết thúc")
                
                -- Vuốt để chuyển sang live stream khác
                logger.info("Vuốt xuống stream khác...")
                
                -- Thực hiện vuốt trực tiếp
                touchDown(1, midX, startY)
                mSleep(100)
                for i = 1, 10 do
                    local moveY = startY - (i * (startY - endY) / 10)
                    touchMove(1, midX, moveY)
                    mSleep(20)
                end
                touchUp(1, midX, endY)
                
                mSleep(2000)
                
                -- Kiểm tra xem live stream mới đã load xong chưa
                local streamLoaded, streamError = rewards_live.waitForLiveScreen(8, true)
                if not streamLoaded then
                    logger.warning("Không thể xác nhận live stream đã load sau khi chuyển stream: " .. safeToString(streamError or ""))
                    goto continue_main_loop
                else
                    logger.info("Đã xác nhận live stream mới đã load thành công")
                end
                
                -- Tìm và bấm vào nút phần thưởng
                logger.info("Tìm và bấm vào nút phần thưởng ở stream mới...")
                local rewardPressed, rewardError = rewards_live.tapRewardButton(true)
                
                if rewardPressed then
                    -- Kiểm tra và đợi cho màn hình phần thưởng load
                    logger.info("Kiểm tra xem đã vào màn hình phần thưởng ở stream mới chưa...")
                    local inRewardScreen, rewardScreenError = rewards_live.waitForRewardScreen(nil, true)
                    if not inRewardScreen then
                        logger.warning("Không thể xác nhận đang ở màn hình phần thưởng ở stream mới")
                        -- Skip to next iteration of the while loop
                        goto continue_main_loop
                    end
                    
                    logger.info("Đã vào màn hình phần thưởng thành công ở stream mới!")
                    
                    -- Chờ giao diện phần thưởng load (giảm xuống)
                    mSleep((config.timing.reward_click_wait * 0.75) * 1000)
                    
                    -- Thực hiện vuốt mạnh từ dưới lên
                    touchDown(1, midX, startY)
                    mSleep(100)
                    for i = 1, 10 do
                        local moveY = startY - (i * (startY - endY) / 10)
                        touchMove(1, midX, moveY)
                        mSleep(20)
                    end
                    touchUp(1, midX, endY)
                    
                    mSleep(1500) -- giảm từ 2000ms xuống 1500ms
                    
                    -- Kiểm tra nút complete
                    completeFound, _, _, _ = rewards_live.checkCompleteButton(true)
                    
                    if completeFound then
                        return true, "Hoàn thành nhiệm vụ thành công"
                    end
                    
                    -- Cập nhật thời gian claim để tiếp tục vòng lặp
                    lastClaimFoundTime = os.time()
                    -- Reset lại số lần thất bại liên tiếp
                    consecutiveFailures = 0
                else
                    logger.warning("Không tìm thấy nút phần thưởng ở stream mới", true)
                end
            end
        end
        
        -- Kiểm tra thời gian chạy tổng cộng, nếu vượt quá giới hạn thì dừng
        if os.time() - monitorStartTime > config.limits.account_runtime then
            logger.warning("Đã vượt quá thời gian giới hạn chạy cho một tài khoản")
            return false, "Đã vượt quá thời gian giới hạn chạy"
        end
        
        -- Tính toán thời gian đã trải qua từ đầu vòng lặp
        local elapsedTime = os.time() - startTime
        -- Chỉ chờ thêm nếu thời gian xử lý ít hơn adaptiveInterval
        if elapsedTime < adaptiveInterval then
            mSleep((adaptiveInterval - elapsedTime) * 1000)
        end
        
        ::continue_main_loop::
    end
    
    return true, "Hoàn thành nhiệm vụ thành công"
end

return autoTiktok 
