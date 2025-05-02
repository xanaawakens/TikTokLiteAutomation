--[[
  main.lua - File chính cho kịch bản tự động TikTok Lite
  
  File này chịu trách nhiệm:
  - Khởi tạo kịch bản và các thiết lập cần thiết
  - Thực hiện quy trình tự động chính
  - Xử lý lỗi và báo cáo kết quả
]]

-- Khai báo thư viện cần thiết
require("TSLib")
local utils = require("utils")
local config = require("config")
local rewards_live = require("rewards_live")

-- Khởi tạo
init(0)  -- Chế độ tự động (không cần tên ứng dụng)

-- Hàm mở TikTok Lite và thực hiện các tác vụ tự động
function runTikTokLiteAutomation()
    -- 1. Kiểm tra và thiết lập ban đầu
    local width, height = utils.getDeviceScreen()
    utils.initLogging()
    
    -- 2. Kiểm tra app đã cài đặt chưa
    if not utils.isTikTokLiteInstalled() then
        dialog("Lỗi: TikTok Lite chưa được cài đặt!")
        return false
    end
    
    -- 3. Mở ứng dụng TikTok Lite (chỉ mở một lần)
    toast("Mở ứng dụng TikTok Lite...")
    local success = utils.openTikTokLite(false)
    
    if not success then
        dialog("Không thể mở TikTok Lite! Hãy kiểm tra lại ứng dụng.")
        return false
    end
    
    -- 4. Đợi ứng dụng ổn định
    toast("Đợi ứng dụng ổn định...")
    mSleep(3000)  -- Tăng thời gian đợi để ứng dụng ổn định hơn
    
    -- 5. Tìm và bấm vào nút xem live
    toast("Tìm kiếm nút xem live...")
    local tapped = rewards_live.tapLiveButton()
    
    if tapped then
        -- 6. Đợi màn hình live load xong
        toast("Đã bấm vào nút live, đang đợi...")
        
        -- Đợi hoặc xác nhận màn hình live
        local liveLoaded = rewards_live.waitForLiveScreen()
        
        if liveLoaded then
            -- 7. Thực hiện các hành động trong live
            toast("Đã vào màn hình live thành công")
            
            -- Chờ thêm 3 giây sau khi xác nhận live đã load
            toast("Chờ 3 giây trước khi tìm kiếm nút phần thưởng...")
            for i = 3, 1, -1 do
                toast("Còn " .. i .. " giây")
                mSleep(1000)
            end
            
            -- 7.1. Kiểm tra và bấm nút phần thưởng
            local checkInterval = 1.5  -- Kiểm tra mỗi 1.5 giây
            local totalCheckTime = 12  -- Chỉ kiểm tra trong 12 giây
            local startTime = os.time()
            local rewardTapped = false

            -- Kiểm tra nút phần thưởng trong 12 giây, mỗi lần cách nhau 1.5 giây
            toast("Bắt đầu kiểm tra nút phần thưởng trong " .. totalCheckTime .. " giây")
            while os.time() - startTime < totalCheckTime do
                -- Kiểm tra và bấm nút phần thưởng
                rewardTapped = rewards_live.tapRewardButton()
                
                if rewardTapped then
                    -- Chờ 5 giây sau khi bấm nút để giao diện phần thưởng load
                    mSleep(8000)
                    
                    -- Vuốt từ dưới lên trên (cuộn xuống)
                    local swipeConfig = config.ui.swipe
                    utils.swipeWithConfig(swipeConfig.start_x, swipeConfig.start_y, swipeConfig.end_x, swipeConfig.end_y)
                    
                    -- Kiểm tra nút complete ngay lần đầu tiên sau khi kéo xuống
                    mSleep(1000)  -- Đợi một chút để màn hình ổn định
                    local completeFound, _, _ = rewards_live.checkCompleteButton()
                    
                    if completeFound then
                        -- Hiển thị dialog hoàn thành claim
                        dialog("Hoàn thành nhận phần thưởng!", "Thông báo")
                        return true
                    end
                    
                    break  -- Tìm thấy và bấm vào nút rồi thì dừng vòng lặp này
                end
                
                -- Đợi đến lần kiểm tra tiếp theo
                toast("Kiểm tra lại sau " .. checkInterval .. " giây...")
                mSleep(checkInterval * 1000)
            end
            
            -- Nếu không tìm thấy nút phần thưởng sau khi kiểm tra đủ thời gian
            if not rewardTapped then
                dialog("Tài khoản có thể bị FAQ!", "Cảnh báo")
                return false
            end

            -- Chỉ tiếp tục tìm nút claim và complete nếu đã bấm được nút phần thưởng
            if rewardTapped then
                -- 7.2. Liên tục kiểm tra nút Claim và Complete - không giới hạn thời gian
                local claimCheckInterval = 3  -- Kiểm tra mỗi 3 giây
                local lastClaimFoundTime = os.time()  -- Thời điểm cuối cùng tìm thấy nút claim
                local claimFound = false
                local completeFound = false
                local monitorStartTime = os.time()
                
                -- Mảng lưu thời gian của các lần claim gần đây
                local recentClaimTimes = {}
                
                -- Biến theo dõi thời điểm claim đầu tiên
                local firstClaimTime = nil
                
                -- Biến theo dõi thời gian của lần kiểm tra popup cuối cùng
                local lastPopupCheckTime = 0
                
                toast("Bắt đầu giám sát nút Claim và Complete (không giới hạn thời gian)...")
                -- Vòng lặp vô hạn, chỉ dừng lại khi tìm thấy nút complete
                while not completeFound do
                    -- Kiểm tra và bấm nút Claim
                    claimFound = rewards_live.tapClaimButton()
                    
                    if claimFound then
                        lastClaimFoundTime = os.time()  -- Cập nhật thời điểm tìm thấy nút claim
                        
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
                        
                        -- Kiểm tra nếu có 3 lần claim liên tiếp trong khoảng thời gian dưới 20 giây
                        if #recentClaimTimes == 3 and (recentClaimTimes[3] - recentClaimTimes[1]) < 20 then
                            -- Hiển thị dialog thông báo lỗi
                            dialog("Lỗi: Something went wrong", "Cảnh báo")
                            return false  -- Dừng chương trình
                        end
                        
                        -- Đợi 3 giây sau khi bấm nút claim
                        mSleep(3000)
                        
                        -- Chỉ kiểm tra nút complete sau khi claim thành công
                        completeFound, _, _ = rewards_live.checkCompleteButton()
                        
                        if completeFound then
                            -- Hiển thị dialog hoàn thành claim
                            dialog("Hoàn thành nhận phần thưởng!", "Thông báo")
                            break  -- Thoát khỏi vòng lặp khi tìm thấy nút complete
                        end
                    end
                    
                    -- Kiểm tra xem đã qua 15 giây chưa tìm thấy nút claim hay chưa
                    if os.time() - lastClaimFoundTime >= 15 then
                        -- Kiểm tra nút phần thưởng trước
                        local rewardFound1, rx1, ry1 = rewards_live.checkRewardButton()
                        
                        if rewardFound1 then
                            -- Thực hiện vuốt từ dưới lên trên 2 lần để chuyển sang live stream khác
                            local swipeConfig = config.ui.swipe
                            
                            -- Vuốt lần 1
                            utils.swipeWithConfig(swipeConfig.start_x, swipeConfig.start_y, swipeConfig.end_x, swipeConfig.end_y)
                            mSleep(1000)  -- Đợi 1 giây giữa hai lần vuốt
                            
                            -- Vuốt lần 2
                            utils.swipeWithConfig(swipeConfig.start_x, swipeConfig.start_y, swipeConfig.end_x, swipeConfig.end_y)
                            mSleep(2000)  -- Đợi 2 giây cho nội dung mới tải
                            
                            -- Kiểm tra lại và bấm vào nút phần thưởng
                            local rewardFound2 = rewards_live.tapRewardButton()
                            
                            if rewardFound2 then
                                -- Chờ 3 giây sau khi bấm nút để giao diện phần thưởng load
                                mSleep(3000)
                                
                                -- Vuốt từ dưới lên trên (cuộn xuống)
                                utils.swipeWithConfig(swipeConfig.start_x, swipeConfig.start_y, swipeConfig.end_x, swipeConfig.end_y)
                                
                                -- Kiểm tra nút complete ngay lần đầu tiên sau khi kéo xuống
                                mSleep(1000)  -- Đợi một chút để màn hình ổn định
                                local completeFound, _, _ = rewards_live.checkCompleteButton()
                                
                                if completeFound then
                                    -- Hiển thị dialog hoàn thành claim
                                    dialog("Hoàn thành nhận phần thưởng!", "Thông báo")
                                    return true
                                end
                                
                                lastClaimFoundTime = os.time()  -- Cập nhật thời điểm để bắt đầu đếm lại
                            end
                        end
                    end
                    
                    -- Kiểm tra các popup trong 150 giây đầu tiên sau khi claim đầu tiên (mỗi 3 giây một lần)
                    local currentTime = os.time()
                    
                    -- Lấy kích thước màn hình một lần duy nhất
                    local screenW, screenH = getScreenSize()
                    
                    -- Kiểm tra popup nhiệm vụ (chỉ trong 150 giây đầu)
                    if firstClaimTime ~= nil and 
                       (currentTime - firstClaimTime <= 150) and
                       (currentTime - lastPopupCheckTime >= 3) then
                        
                        -- Cập nhật thời gian kiểm tra popup
                        lastPopupCheckTime = currentTime
                        
                        local missionX, missionY = findImageInRegionFuzzy("popupMission.png", 90, 1, 1, screenW, screenH, 0)
                        if missionX ~= -1 and missionY ~= -1 then
                            tap(375, 1059)
                            mSleep(1000)
                        end
                    end
                    
                    -- Kiểm tra popup Reward upgraded (kiểm tra liên tục)
                    local rewardX, rewardY = findImageInRegionFuzzy("popup2.png", 90, 1, 1, screenW, screenH, 0)
                    if rewardX ~= -1 and rewardY ~= -1 then
                        tap(359, 993)
                        mSleep(1000)
                    end
                    
                    -- Vuốt từ dưới lên trên định kỳ (sau mỗi 15 giây)
                    if os.time() - monitorStartTime > 15 and (os.time() - monitorStartTime) % 15 == 0 then
                        local swipeConfig = config.ui.swipe
                        utils.swipeWithConfig(swipeConfig.start_x, swipeConfig.start_y, swipeConfig.end_x, swipeConfig.end_y)
                    end
                    
                    -- Chờ đến lần kiểm tra tiếp theo
                    mSleep(claimCheckInterval * 1000)
                end
                
                toast("Đã hoàn thành quy trình kiểm tra phần thưởng")
            else
                toast("Không tìm thấy nút phần thưởng, kết thúc kịch bản")
            end
            
            return true
        end
    else
        dialog("Tài khoản bị chặn xem live", "Cảnh báo")
        return false
    end
end

-- Thực thi kịch bản với xử lý lỗi
function main()
    -- Bọc trong pcall để bắt lỗi
    local status, result = pcall(runTikTokLiteAutomation)
    
    if not status then
        -- Lỗi runtime
        local errorMsg = "Lỗi thực thi: " .. tostring(result)
        toast(errorMsg)
        dialog(errorMsg)
        return false
    else
        -- Kết quả thực thi
        if result then
            dialog("Kịch bản thực thi thành công!")
        else
            dialog("Kịch bản thất bại!")
        end
        return result
    end
end

-- Chạy kịch bản
main()
