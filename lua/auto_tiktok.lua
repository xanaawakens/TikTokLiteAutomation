-- Module auto_tiktok.lua - Chức năng tự động hóa TikTok Lite
-- Mô tả: Chứa các hàm để tự động mở TikTok Lite, xem live stream và thu thập phần thưởng

require("TSLib")
local config = require("config")
local utils = require("utils")
local rewards_live = require("rewards_live")
local logger = require("logger")
local fileManager = require("file_manager") -- Thêm module quản lý file mới

local autoTiktok = {}

-- Khởi tạo và mở ứng dụng TikTok Lite
local function initializeApp()
    -- Mở TikTok Lite
    local success, error = utils.openTikTokLite(false)
    
    if not success then
        return false, "Không thể mở TikTok Lite: " .. (error or "")
    end
    
    mSleep(3000)
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
    local success, error = initializeApp()
    if not success then
        return false, error
    end
    
    -- 2. Di chuyển đến màn hình xem live
    local navSuccess, navError = navigateToLiveStream()
    if not navSuccess then
        return false, navError
    end
    
    -- 3. Đợi để giao diện ổn định
    mSleep(config.timing.ui_stabilize * 1000)
    
    -- 4. Vuốt để chuyển sang 1 live stream khác (tránh live stream đầu tiên)
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
    
    -- 5. Check và click vào nút phần thưởng
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
        logger.warning("Không thể xác nhận đang ở màn hình phần thưởng: " .. (rewardScreenError or ""))
        return false, "Không thể vào màn hình phần thưởng"
    end
    
    logger.info("Đã vào màn hình phần thưởng thành công!")
    
    -- 6. Chờ màn hình giao diện nhiệm vụ phần thưởng load xong
    local waitTime = config.timing.reward_click_wait or 8
    logger.info("Chờ " .. waitTime .. "s để giao diện phần thưởng load...")
    mSleep(waitTime * 1000)
    
    -- 7. Thực hiện kéo xuống bên dưới (vuốt từ dưới đi lên)
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
    
    -- 8. Check nút complete lần 1
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
        
    -- 9. Vòng lặp chính - kiểm tra claim và complete
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
            
            -- Đợi 10 giây rồi kiểm tra lại nút claim
            -- Nếu vẫn còn nút claim (không thay đổi) thì báo lỗi
            logger.info("Đợi 10s và kiểm tra xem nút claim còn hiện diện không...")
            mSleep(10000)
            
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
