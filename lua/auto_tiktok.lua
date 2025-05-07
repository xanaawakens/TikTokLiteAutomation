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
    
    -- Kiểm tra 3 lần cho popup nâng cấp phần thưởng
    for i = 1, 3 do
        local rewardX, rewardY = findImageInRegionFuzzy(config.images.popup.reward, config.accuracy.image_similarity, 1, 1, screenW, screenH, 0)
        if rewardX ~= -1 and rewardY ~= -1 then
            logger.info("Đóng popup nâng cấp phần thưởng sau khi claim - lần " .. i)
            tap(config.popup_close.reward[1], config.popup_close.reward[2])
            mSleep(1000)
        end
    end

    -- Kiểm tra 3 lần cho popup nhiệm vụ
    for i = 1, 3 do
        local missionX, missionY = findImageInRegionFuzzy(config.images.popup.mission, config.accuracy.image_similarity, 1, 1, screenW, screenH, 0)
        if missionX ~= -1 and missionY ~= -1 then
            logger.info("Đóng popup nhiệm vụ - lần " .. i)
            tap(config.popup_close.mission[1], config.popup_close.mission[2])
            mSleep(1000)
        end
    end
    
    -- Đợi thêm 1s trước khi tiếp tục
    mSleep(1000)
    
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
    local switchSuccess, switchError = rewards_live.switchToNextStream(1)
    if not switchSuccess then
        return false, switchError
    end
    
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
    local completeFound, _, _, _ = rewards_live.checkCompleteButton()
    
    if completeFound then
        return true, "Hoàn thành nhiệm vụ thành công ngay sau lần đầu kiểm tra"
    end
    
    -- Vào vòng lặp xử lý claim
    local lastClaimFoundTime = os.time()  -- Thời điểm cuối cùng tìm thấy nút claim
    local firstClaimTime = nil            -- Thời điểm claim đầu tiên
    local lastPopupCheckTime = 0          -- Thời điểm kiểm tra popup cuối cùng
    local monitorStartTime = os.time()    -- Thời điểm bắt đầu giám sát
    local recentClaimTimes = {}           -- Mảng lưu thời gian claim gần đây
    local claimFound = false
    local claimCheckInterval = 5         -- 5s kiểm tra claim một lần
        
    -- 9. Vòng lặp chính - kiểm tra claim và complete
    while true do
        -- Kiểm tra và bấm nút Claim
        claimFound, claimError = rewards_live.tapClaimButton()
        
        if claimFound then
            lastClaimFoundTime = os.time()  -- Cập nhật thời điểm tìm thấy claim
            
            -- Ghi nhận thời điểm claim đầu tiên
            if firstClaimTime == nil then
                firstClaimTime = os.time()
            end
            
            -- Thêm thời điểm claim vào mảng
            table.insert(recentClaimTimes, os.time())
            
            -- Chỉ giữ lại 3 lần claim gần nhất
            if #recentClaimTimes > 3 then
                table.remove(recentClaimTimes, 1)
            end
            
            -- Nếu claim 3 lần liên tiếp <45s thì báo lỗi something went wrong và đổi acc
            if #recentClaimTimes == 3 and recentClaimTimes[3] ~= nil and recentClaimTimes[1] ~= nil and (recentClaimTimes[3] - recentClaimTimes[1]) < 45 then
                logger.warning("Lỗi Something went wrong")
                return false, "Lỗi Something went wrong"
            end
            
            -- Đợi sau khi bấm nút claim
            mSleep(2000)
            
            -- Xử lý các popup sau khi claim
            handlePopupsAfterClaim()
            
            -- Kiểm tra nút complete sau khi claim thành công
            completeFound, _, _, _ = rewards_live.checkCompleteButton()
            
            if completeFound then
                return true, "Hoàn thành nhiệm vụ thành công sau khi claim"
            end
        end
        
        -- 10. Nếu trong 15s không thấy nút claim, check nút phần thưởng
        if lastClaimFoundTime ~= nil and os.time() - lastClaimFoundTime >= 15 then
            -- Kiểm tra nút phần thưởng - nếu có thì phiên live đã kết thúc
            local rewardFound, rx, ry, _ = rewards_live.checkRewardButton()
            
            if rewardFound then
                logger.info("Tìm thấy nút phần thưởng - phiên live hiện tại đã kết thúc")
                
                -- Vuốt để chuyển sang live stream khác
                logger.info("Vuốt xuống stream khác...")

                touchDown(1, midX, startY)
                mSleep(100)
                for i = 1, 10 do
                    local moveY = startY - (i * (startY - endY) / 10)
                    touchMove(1, midX, moveY)
                    mSleep(10)
                end
                touchUp(1, midX, endY)
                
                mSleep(2000)
                
                -- Tìm và bấm vào nút phần thưởng
                logger.info("Tìm và bấm vào nút phần thưởng ở stream mới...")
                local rewardPressed, rewardError = rewards_live.tapRewardButton()
                
                if rewardPressed then
                    -- Chờ giao diện phần thưởng load
                    mSleep(waitTime * 1000)      
                    -- Thực hiện vuốt mạnh từ dưới lên
                    touchDown(1, midX, startY)
                    mSleep(100)
                    for i = 1, 10 do
                        local moveY = startY - (i * (startY - endY) / 10)
                        touchMove(1, midX, moveY)
                        mSleep(10)
                    end
                    touchUp(1, midX, endY)
                    
                    mSleep(2000)
                    
                    -- Kiểm tra nút complete
                    completeFound, _, _, _ = rewards_live.checkCompleteButton()
                    
                    if completeFound then
                        return true, "Hoàn thành nhiệm vụ thành công"
                    end
                    
                    -- Cập nhật thời gian claim để tiếp tục vòng lặp
                    lastClaimFoundTime = os.time()
                else
                    logger.warning("Không tìm thấy nút phần thưởng ở stream mới")
                end
            end
        end
        
        -- Kiểm tra thời gian chạy tổng cộng, nếu vượt quá giới hạn thì dừng
        if os.time() - monitorStartTime > config.limits.account_runtime then
            logger.warning("Đã vượt quá thời gian giới hạn chạy cho một tài khoản")
            return false, "Đã vượt quá thời gian giới hạn chạy"
        end
        
        -- Chờ đến lần kiểm tra claim tiếp theo (5s một lần)
        mSleep(claimCheckInterval * 1000)
    end
    
    return true, "Hoàn thành nhiệm vụ thành công"
end

return autoTiktok 
