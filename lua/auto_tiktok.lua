-- Module auto_tiktok.lua - Chức năng tự động hóa TikTok Lite
-- Mô tả: Chứa các hàm để tự động mở TikTok Lite, xem live stream và thu thập phần thưởng

require("TSLib")
local config = require("config")
local utils = require("utils")
local rewards_live = require("rewards_live")

local autoTiktok = {}

-- Hàm mở TikTok Lite và thực hiện các tác vụ tự động
function autoTiktok.runTikTokLiteAutomation()
    local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
    
    -- 1. Mở TikTok Lite
    local success = utils.openTikTokLite(false)
    
    if not success then
        return false, "Không thể mở TikTok Lite"
    end
    
    mSleep(3000)
    
    -- 2. Bấm vào nút xem live
    local tapped, tapError = rewards_live.tapLiveButton()
    
    if not tapped then
        return false, tapError or "Không thể tìm thấy nút xem live"
    end
    
    -- 3. Check đã load chưa, chưa load chờ 3s check tiếp
    local liveLoaded = false
    local maxLoadAttempts = 5  -- Giới hạn số lần thử
    local loadAttempt = 0
    
    while not liveLoaded and loadAttempt < maxLoadAttempts do
        loadAttempt = loadAttempt + 1
        liveLoaded, _ = rewards_live.waitForLiveScreen()
        
        if not liveLoaded then
            toast("Màn hình live chưa load, chờ 3s và kiểm tra lại...")
            mSleep(3000)
        end
    end
    
    if not liveLoaded then
        return false, "Không thể xác nhận màn hình live đã load sau nhiều lần thử"
    end
    
    toast("Màn hình live đã load xong")
    mSleep(3000)
    
    -- 4. Check và click vào nút phần thưởng
    local rewardTapped = false
    local rewardError = nil
    local maxRewardAttempts = 8  -- Kiểm tra trong khoảng 12 giây (8 lần * 1.5s)
    local rewardAttempt = 0
    
    while not rewardTapped and rewardAttempt < maxRewardAttempts do
        rewardAttempt = rewardAttempt + 1
        toast("Tìm nút phần thưởng, lần thử " .. rewardAttempt .. "/" .. maxRewardAttempts)
        
        rewardTapped, rewardError = rewards_live.tapRewardButton()
        
        if rewardTapped then
            toast("Đã bấm vào nút phần thưởng")
            break
        else
            mSleep(1500)  -- Chờ 1.5s trước khi thử lại
        end
    end
    
    if not rewardTapped then
        return false, rewardError or "Không tìm thấy nút phần thưởng sau nhiều lần thử"
    end
    
    -- 5. Chờ màn hình giao diện nhiệm vụ phần thưởng load xong
    local waitTime = config.timing.reward_click_wait or 8
    toast("Chờ " .. waitTime .. "s để giao diện phần thưởng load...")
    mSleep(waitTime * 1000)
    
    -- 6. Thực hiện kéo xuống bên dưới (vuốt từ dưới đi lên)
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
    
    -- 7. Check nút complete lần 1
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
    local claimCheckInterval = 10         -- 10s kiểm tra claim một lần
        
    -- 8. Vòng lặp chính - kiểm tra claim và complete
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
            
            -- Nếu claim 3 lần liên tiếp <35s thì báo lỗi something went wrong và đổi acc
            if #recentClaimTimes == 3 and recentClaimTimes[3] ~= nil and recentClaimTimes[1] ~= nil and (recentClaimTimes[3] - recentClaimTimes[1]) < 35 then
                toast("Lỗi Something went wrong")
                return false, "Lỗi Something went wrong"
            end
            
            -- Đợi sau khi bấm nút claim
            mSleep(2000)
            
            -- Kiểm tra popup Reward upgraded sau mỗi lần claim thành công
            local screenW, screenH = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
            local rewardX, rewardY = findImageInRegionFuzzy("popup2.png", 90, 1, 1, screenW, screenH, 0)
            if rewardX ~= -1 and rewardY ~= -1 then
                toast("Đóng popup nâng cấp phần thưởng sau khi claim")
                tap(357, 1033)
                mSleep(1000)
            end
            
            -- Đợi thêm 1s trước khi kiểm tra nút complete
            mSleep(1000)
            
            -- Kiểm tra nút complete sau khi claim thành công
            completeFound, _, _, _ = rewards_live.checkCompleteButton()
            
            if completeFound then
                return true, "Hoàn thành nhiệm vụ thành công sau khi claim"
            end
        end
        
        -- 9. Trong 250s đầu check popupMission.png
        local currentTime = os.time()
        
        if firstClaimTime ~= nil and 
           (currentTime - firstClaimTime <= 250) and
           (lastPopupCheckTime == 0 or currentTime - lastPopupCheckTime >= 3) then
            
            -- Cập nhật thời gian kiểm tra popup
            lastPopupCheckTime = currentTime
            
            -- Lấy kích thước màn hình 
            local screenW, screenH = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
            
            -- Kiểm tra popup nhiệm vụ
            local missionX, missionY = findImageInRegionFuzzy("popupMission.png", 90, 1, 1, screenW, screenH, 0)
            if missionX ~= -1 and missionY ~= -1 then
                toast("Đóng popup nhiệm vụ")
                tap(375, 1059)
                mSleep(1000)
            end
        end
        
        -- 10. Nếu trong 15s không thấy nút claim, check nút phần thưởng
        if lastClaimFoundTime ~= nil and os.time() - lastClaimFoundTime >= 15 then
            -- Kiểm tra nút phần thưởng - nếu có thì phiên live đã kết thúc
            local rewardFound, rx, ry, _ = rewards_live.checkRewardButton()
            
            if rewardFound then
                toast("Tìm thấy nút phần thưởng - phiên live hiện tại đã kết thúc")
                
                -- Vuốt để chuyển sang live stream khác
                toast("Vuốt xuống stream khác...")
                
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
                
                -- Tìm và bấm vào nút phần thưởng
                toast("Tìm và bấm vào nút phần thưởng ở stream mới...")
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
                    toast("Không tìm thấy nút phần thưởng ở stream mới")
                end
            end
        end
        
        -- Chờ đến lần kiểm tra claim tiếp theo (10s một lần)
        mSleep(claimCheckInterval * 1000)
    end
    
    return true, "Hoàn thành nhiệm vụ thành công"
end

-- Hàm ghi log kết quả vào file analysis.txt
function autoTiktok.logResult(account, accountName, success, reason)
    local outputFolder = "/private/var/mobile/Media/TouchSprite/lua"
    local analysisFile = io.open(outputFolder .. "/analysis.txt", "a")
    
    if analysisFile then
        local currentTime = os.date("%Y-%m-%d %H:%M:%S")
        local status = success and "successfully" or "failed"
        
        -- Thông tin cơ bản luôn được ghi
        local logEntry = account .. ":" .. accountName .. " " .. status .. " " .. currentTime
        
        -- Nếu failed, ghi chi tiết hơn về lỗi
        if not success then
            -- Thêm dòng mới và thụt lề để dễ đọc
            logEntry = logEntry .. "\n    ERROR: " .. reason
            
            -- Thêm thông tin về thiết bị
            local deviceInfo = "Unknown"
            if getDeviceInfo then
                local info = getDeviceInfo()
                if info then
                    deviceInfo = info.model or "Unknown model"
                end
            end
            logEntry = logEntry .. "\n    DEVICE: " .. deviceInfo
            
            -- Thêm thông tin về màn hình
            local width, height = _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT
            logEntry = logEntry .. "\n    SCREEN: " .. width .. "x" .. height
            
            -- Thêm thông tin về phiên bản iOS nếu có
            local iosVer = getOSType()
            if iosVer then
                logEntry = logEntry .. "\n    OS: " .. iosVer
            end
            
            -- Lấy thông tin về bộ nhớ nếu có
            if getMemoryInfo then
                local mem = getMemoryInfo()
                if mem then
                    -- Kiểm tra xem trường 'used' và 'free' có tồn tại không
                    local usedMem = "Unknown"
                    local freeMem = "Unknown"
                    
                    if mem.used and type(mem.used) == "number" then
                        usedMem = math.floor(mem.used/1024/1024) .. "MB"
                    end
                    
                    if mem.free and type(mem.free) == "number" then
                        freeMem = math.floor(mem.free/1024/1024) .. "MB"
                    end
                    
                    logEntry = logEntry .. "\n    MEMORY: Used " .. usedMem .. ", Free " .. freeMem
                end
            end
            
            -- Thêm thời gian xảy ra lỗi (số giây từ khi script bắt đầu chạy)
            local runningTime = os.time() - _G.scriptStartTime
            if _G.scriptStartTime then
                logEntry = logEntry .. "\n    RUNTIME: " .. runningTime .. " giây"
            end
            
            -- Chụp ảnh màn hình nếu có lỗi và lưu đường dẫn
            local screenshotPath = nil
            local timestamp = os.date("%Y%m%d_%H%M%S")
            local ssFolder = "/private/var/mobile/Media/TouchSprite/screenshots"
            
            -- Tạo thư mục nếu chưa tồn tại
            os.execute("mkdir -p '" .. ssFolder .. "'")
            
            local ssFilename = account .. "_" .. timestamp .. ".png"
            screenshotPath = ssFolder .. "/" .. ssFilename
            
            -- Chụp ảnh màn hình
            snapshot(screenshotPath, 0, 0, width, height)
            
            -- Thêm đường dẫn ảnh vào log
            logEntry = logEntry .. "\n    SCREENSHOT: " .. screenshotPath .. "\n"
        else
            -- Nếu thành công, chỉ thêm lý do
            logEntry = logEntry .. ": " .. reason
        end
        
        -- Ghi dữ liệu vào file
        analysisFile:write(logEntry .. "\n")
        analysisFile:close()
        
        return true
    else
        toast("Không thể ghi vào file analysis.txt")
        return false
    end
end

-- Thêm theo dõi thời gian bắt đầu chạy script
if not _G.scriptStartTime then
    _G.scriptStartTime = os.time()
end

return autoTiktok 