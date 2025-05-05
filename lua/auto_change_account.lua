-- 1. Lấy danh sách tất cả các file adbk trong thư mục ghi vào file account_list.txt
-- 2. Lấy số từ file current_account.txt để biết chạy account thứ mấy
-- 3. đọc file account_list.txt và lấy tên account ở số đó để chạy
-- 5. Chỉnh sửa file ImportedBackups.plist để chạy account đó
-- 6. Tắt Apps Manager Mở lại Apps Manager Restore chạy account đó
-- 7. Mở Tiktok Lite để chạy
-- 8. sau khi chạy xong tắt tiktok rồi apps manager restore lại. mỗi lần restore file current_account.txt sẽ tăng lên 1
-- 9. lặp lại cho đến khi hết account

-- 1. Lấy danh sách tất cả các file adbk trong thư mục ghi vào file account_list.txt

require("TSLib")
local config = require("config")
local utils = require("utils")
local rewards_live = require("rewards_live")


local input_folder = "/private/var/mobile/Library/ADManager"
local output_folder = "/private/var/mobile/Media/TouchSprite/lua"
local importedBackupsPlist = "/private/var/mobile/Library/ADManager/ImportedBackups.plist"

-- Hàm lấy danh sách tất cả các file trong thư mục và ghi vào file
function getAllFilesInFolder(folderPath)
    local files = {}
    local outputFile = output_folder .. "/account_list.txt"
    local currentBackupFile = output_folder .. "/currentbackup.txt"
    
    -- Sử dụng io.popen để liệt kê các file
    local command = "ls -la \"" .. folderPath .. "\" 2>/dev/null"
    local handle = io.popen(command)
    
    if not handle then
        toast("Không thể thực hiện lệnh ls trên thư mục")
        return files
    end
    
    local result = handle:read("*a")
    handle:close()
    
    -- Kiểm tra xem thư mục có tồn tại không
    if result == "" then
        toast("Thư mục không tồn tại: " .. folderPath)
        return files
    end
    
    -- Phân tích kết quả để lấy tên file
    for line in result:gmatch("[^\r\n]+") do
        -- Bỏ qua dòng đầu tiên và dòng chứa "." và ".."
        if not line:match("^total") and not line:match(" %.$") and not line:match(" %.%.$") then
            -- Mẫu ls -la thường có định dạng: 
            -- drwxr-xr-x  2 user group   4096 Apr 22 10:34 filename
            -- Phần filename là tất cả sau ngày và giờ (phần thứ 8 trở đi)
            local isDir = line:match("^d") ~= nil
            
            -- Bỏ qua nếu là thư mục
            if not isDir then
                -- Tách các phần của dòng ra
                local parts = {}
                for part in line:gmatch("%S+") do
                    table.insert(parts, part)
                end
                
                -- Lấy phần tên file (từ phần tử thứ 9 trở đi, sau timestamp)
                if #parts >= 9 then
                    local fileName = parts[9]
                    -- Nếu có nhiều phần hơn, có nghĩa là tên file có khoảng trắng
                    for i = 10, #parts do
                        fileName = fileName .. " " .. parts[i]
                    end
                    
                    -- Chỉ lưu những file có đuôi .adbk
                    if fileName:match("%.adbk$") then
                        -- Lưu tên file không có đuôi .adbk
                        local nameWithoutExt = fileName:gsub("%.adbk$", "")
                        table.insert(files, nameWithoutExt)
                    end
                end
            end
        end
    end
    
    -- Ghi danh sách vào file account_list.txt
    local file = io.open(outputFile, "w")
    if file then
        for i, fileName in ipairs(files) do
            file:write(i .. ": " .. fileName .. "\n")
        end
        file:close()
        toast("Đã ghi danh sách vào file: " .. outputFile .. " (" .. #files .. " files)")
    else
        toast("Lỗi: Không thể ghi vào file: " .. outputFile)
    end
    
    -- Ghi số lượng file vào dòng thứ 2 của currentbackup.txt
    local currentBackup = io.open(currentBackupFile, "r")
    local currentAccount = "1"
    if currentBackup then
        currentAccount = currentBackup:read() or "1"
        currentBackup:close()
    end
    
    currentBackup = io.open(currentBackupFile, "w")
    if currentBackup then
        currentBackup:write(currentAccount .. "\n" .. #files)
        currentBackup:close()
        toast("Đã cập nhật số lượng file vào currentbackup.txt: " .. #files)
    else
        toast("Lỗi: Không thể ghi vào file currentbackup.txt")
    end
    
    return files
end

-- getAllFilesInFolder(input_folder)

-- 2. Lấy số từ file current_backup.txt để biết chạy account thứ mấy và tổng số backup
function getCurrentAccount()
    local currentAccountFile = output_folder .. "/currentbackup.txt"
    local currentAccount = 1
    local totalAccounts = 1

    -- Kiểm tra file tồn tại bằng cách thử mở file
    local success, file = pcall(io.open, currentAccountFile, "r")
    if success and file then
        -- Đọc dòng đầu tiên - số account hiện tại
        local line1 = file:read()
        if line1 then
            currentAccount = tonumber(line1) or 1
        end
        
        -- Đọc dòng thứ hai - tổng số account
        local line2 = file:read()
        if line2 then
            totalAccounts = tonumber(line2) or 1
        end
        
        file:close()
    end

    return currentAccount, totalAccounts
end

-- local currentAccount, totalAccounts = getCurrentAccount()
-- toast("Account hiện tại: " .. currentAccount .. "/" .. totalAccounts)

-- Chỉnh sửa file ImportedBackups.plist để chạy account đó
-- lấy tên account từ file account_list.txt ở số hiện tại file currentbackup.txt
function getAccountName()
    local accountListFile = output_folder .. "/account_list.txt"
    local accountName = "unknown"
    local currentAccount, totalAccounts = getCurrentAccount()
    
    -- Đọc tên account từ account_list.txt
    local success, file = pcall(io.open, accountListFile, "r")
    if success and file then
        for line in file:lines() do
            local number, name = line:match("(%d+):%s*(.+)")
            if number and tonumber(number) == currentAccount then
                accountName = name
                break
            end
        end
        file:close()
        
        if accountName == "unknown" then
            toast("Không tìm thấy account số " .. currentAccount .. " trong danh sách")
        end
    else
        toast("Không thể mở file danh sách account: " .. accountListFile)
    end

    return accountName
end

function changeAccount(accountName)
    local plistFile = output_folder .. "/ImportedBackups.plist"
    local success, file = pcall(io.open, plistFile, "r")
    if not success then
        toast("Không thể mở file ImportedBackups.plist")
        return false
    end

    local content = file:read("*all")
    file:close()

    -- Thay thế "name backup" bằng accountName
    local newContent = content:gsub("name backup", accountName)

    -- Ghi lại nội dung đã thay đổi vào file ImportedBackups.plist trong thư mục ADManager
    success, file = pcall(io.open, importedBackupsPlist, "w")
    if not success then
        toast("Không thể ghi file ImportedBackups.plist")
        return false
    end

    file:write(newContent)
    file:close()
    return true
end


-- Mở ứng dụng ADManager
function openADManager()
    local bundleID = config.admanager.bundle_id
    
    toast("Đang mở Apps Manager")
    
    -- Đóng app nếu đang chạy để mở lại từ đầu
    if appIsRunning(bundleID) then
        closeApp(bundleID)
        mSleep(2000)
    end
    
    -- Mở ứng dụng ADManager
    local openResult = runApp(bundleID)
    
    if not openResult then
        toast("Lỗi: Không thể mở Apps Manager")
        return false
    end
    
    -- Đợi app khởi động
    mSleep(3000)
    
    -- Kiểm tra app có ở foreground không
    if not isFrontApp(bundleID) then
        toast("Apps Manager không ở foreground sau khi mở")
        return false
    end
    
    return true
end

-- Tìm và bấm vào danh sách các ứng dụng
function clickAppsList()
    local coord = config.admanager.app_list_coord
    
    toast("Bấm vào danh sách ứng dụng")
    tap(coord[1], coord[2])
    mSleep(2000)
    
    return true
end

-- Tìm và bấm vào ứng dụng TikTok Lite bằng tìm kiếm màu sắc
function findAndClickTikTokIcon()
    
    -- Màu chính và các điểm offset
    local mainColor = 0x000000  -- Màu chính là màu đen
    local mainX = 41
    local mainY = 357
    
    -- Chuỗi offset từ điểm chính
    local offsetStr = "23|-3|0x000000,42|1|0x000000,45|43|0x000000,14|44|0x000000,9|23|0xffffff,26|38|0xfeffff,26|37|0xfeffff,27|11|0xffffff,31|15|0xffffff"
    
    -- Lấy kích thước màn hình
    local width, height = getScreenSize()
    
    -- Tìm kiếm mẫu màu trên màn hình
    local x, y = findMultiColorInRegionFuzzy(mainColor, offsetStr, config.accuracy.color_similarity, 0, 0, width, height)
    
    if x ~= -1 and y ~= -1 then
        tap(x, y)
        mSleep(2000)
        return true
    else
        mainColor = 0x000000
        mainX = 41
        mainY = 357
        
        offsetStr = ""
        local offsets = {
            {64-41, 354-357, 0x000000},
            {83-41, 358-357, 0x000000},
            {86-41, 400-357, 0x000000},
            {39-41, 401-357, 0x000000},
            {55-41, 380-357, 0xffffff},
            {50-41, 395-357, 0xfeffff},
            {67-41, 394-357, 0xfeffff},
            {68-41, 368-357, 0xffffff},
            {79-41, 372-357, 0xffffff}
        }
        
        for i, offset in ipairs(offsets) do
            offsetStr = offsetStr .. offset[1] .. "|" .. offset[2] .. "|" .. string.format("0x%06X", offset[3])
            if i < #offsets then
                offsetStr = offsetStr .. ","
            end
        end
        
        -- Tìm kiếm với mẫu màu thay thế
        x, y = findMultiColorInRegionFuzzy(mainColor, offsetStr, config.accuracy.color_similarity, 0, 0, width, height)
        
        if x ~= -1 and y ~= -1 then
            tap(x, y)
            mSleep(2000)
            return true
        else
            return false
        end
    end
end

-- Bấm vào nút Restore AppData
function restoreAccount()
    -- Sử dụng tọa độ dựa trên kích thước màn hình
    local width, height = getScreenSize()
    
    -- Nút Restore thường nằm ở phía dưới màn hình
    local restoreX = 360  -- Giữa màn hình theo chiều ngang
    local restoreY = 1135  -- 85% chiều cao màn hình
    local accountX = 356
    local accountY = 478

    tap(accountX, accountY)
    mSleep(3000)

    tap(restoreX, restoreY)
    mSleep(1000)

    return true
end


function switchTikTokAccount()
    -- 1. Mở ADManager
    openADManager()
    
    -- 2. Bấm vào danh sách ứng dụng
    clickAppsList()
    
    -- 3. Tìm và bấm vào ứng dụng TikTok Lite
    findAndClickTikTokIcon()
    
    -- 4. Bấm vào nút Restore AppData
    restoreAccount()
end

-- Hàm mở TikTok Lite và thực hiện các tác vụ tự động
function runTikTokLiteAutomation()
    local width, height = utils.getDeviceScreen()
    -- utils.initLogging()
    
    -- 1. Mở TikTok Lite
    local success = utils.openTikTokLite(false)
    
    if not success then
        return false
    end
    
    mSleep(3000)
    
    -- 5. Tìm và bấm vào nút xem live
    local tapped = rewards_live.tapLiveButton()
    
    if tapped then
        -- 6. Đợi màn hình live load xong
        
        -- Đợi hoặc xác nhận màn hình live
        local liveLoaded = rewards_live.waitForLiveScreen()
        
        if liveLoaded then
            
            for i = 3, 1, -1 do
                mSleep(1000)
            end
            
            -- 7.1. Kiểm tra và bấm nút phần thưởng
            local checkInterval = 1.5  -- Kiểm tra mỗi 1.5 giây
            local totalCheckTime = 12  -- Chỉ kiểm tra trong 12 giây
            local startTime = os.time()
            local rewardTapped = false

            -- Kiểm tra nút phần thưởng trong 12 giây, mỗi lần cách nhau 1.5 giây
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
                        return true
                    end
                    
                    break  -- Tìm thấy và bấm vào nút rồi thì dừng vòng lặp này
                end
                
                -- Đợi đến lần kiểm tra tiếp theo
                mSleep(checkInterval * 1000)
            end
            
            -- Nếu không tìm thấy nút phần thưởng sau khi kiểm tra đủ thời gian
            if not rewardTapped then
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
                            return false  -- Dừng chương trình
                        end
                        
                        -- Đợi 3 giây sau khi bấm nút claim
                        mSleep(3000)
                        
                        -- Chỉ kiểm tra nút complete sau khi claim thành công
                        completeFound, _, _ = rewards_live.checkCompleteButton()
                        
                        if completeFound then
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
                    
                    -- Kiểm tra popup nhiệm vụ (chỉ trong 250 giây đầu)
                    if firstClaimTime ~= nil and 
                       (currentTime - firstClaimTime <= 250) and
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
                        toast("Đang đóng popup")
                        tap(357,1033)
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
                
            else
            end
            
            return true
        end
    else
        return false
    end
end


function main()
    getAllFilesInFolder(input_folder)
    
    local currentAccount, totalAccounts = getCurrentAccount()
    
    -- Chạy từ account hiện tại đến hết
    while currentAccount <= totalAccounts do
        -- Đóng tất cả ứng dụng trước khi chuyển account
        closeApp("*",1)
        mSleep(3000)
        
        -- Lấy tên account và thực hiện chuyển đổi
        local accountName = getAccountName()
        if not accountName then
            toast("Không thể lấy tên account")
            return false
        end
        
        local success = changeAccount(accountName)
        if not success then
            toast("Không thể chuyển sang account " .. currentAccount)
            return false
        end
        
        toast("Đang chuyển sang account " .. currentAccount)
        mSleep(1500)
        
        -- Chuyển account trong TikTok
        switchTikTokAccount()
        mSleep(1500)
        
        -- Cập nhật file currentbackup.txt trước khi chạy automation
        local currentFile = io.open(output_folder .. "/currentbackup.txt", "w")
        if currentFile then
            currentFile:write(currentAccount .. "\n" .. totalAccounts)
            currentFile:close()
        else
            toast("Không thể cập nhật file currentbackup.txt")
            return false
        end
        
        mSleep(7000)
        
        -- Chạy automation cho account hiện tại
        toast("Đang chạy account thứ " .. currentAccount .. "/" .. totalAccounts)
        mSleep(1000)
        
        if runTikTokLiteAutomation() then
            local analysisFile = io.open(output_folder .. "/analysis.txt", "a")
            if analysisFile then
                local currentTime = os.date("%Y-%m-%d %H:%M:%S")
                analysisFile:write(currentAccount .. ":" .. accountName .. " successfully " .. currentTime .. "\n")
                analysisFile:close()
            else
                toast("Không thể ghi vào file analysis.txt")
            end
        else
            local analysisFile = io.open(output_folder .. "/analysis.txt", "a")
            if analysisFile then
                local currentTime = os.date("%Y-%m-%d %H:%M:%S")
                analysisFile:write(currentAccount .. ":" .. accountName .. " failed " .. currentTime .. "\n")
                analysisFile:close()
            else
                toast("Không thể ghi vào file analysis.txt")
            end
        end
        
        mSleep(3000)
        closeApp("*",1)
        
        -- Tăng số account sau khi chạy xong
        currentAccount = currentAccount + 1
        
        -- Cập nhật file currentbackup.txt sau khi tăng currentAccount
        local currentFile = io.open(output_folder .. "/currentbackup.txt", "w")
        if currentFile then
            currentFile:write(currentAccount .. "\n" .. totalAccounts)
            currentFile:close()
        else
            toast("Không thể cập nhật file currentbackup.txt")
            return false
        end
    end
    
    toast("Đã chạy xong tất cả " .. totalAccounts .. " account")
    return true
end

main()