-- Module change_account.lua - Chức năng chuyển đổi tài khoản
-- Mô tả: Chứa các hàm để làm việc với danh sách tài khoản, thay đổi tài khoản trong ADManager

require("TSLib")
local config = require("config")

local changeAccount = {}

-- Đường dẫn chính
local input_folder = "/private/var/mobile/Library/ADManager"
local output_folder = "/private/var/mobile/Media/TouchSprite/lua"
local importedBackupsPlist = "/private/var/mobile/Library/ADManager/ImportedBackups.plist"

-- Hàm lấy danh sách tất cả các file trong thư mục và ghi vào file
function changeAccount.getAllFilesInFolder(folderPath)
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

-- Lấy số từ file current_backup.txt để biết chạy account thứ mấy và tổng số backup
function changeAccount.getCurrentAccount()
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

-- Lấy tên account từ file account_list.txt ở số hiện tại file currentbackup.txt
function changeAccount.getAccountName()
    local accountListFile = output_folder .. "/account_list.txt"
    local accountName = "unknown"
    local currentAccount, totalAccounts = changeAccount.getCurrentAccount()
    
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
            return nil, "Không tìm thấy account số " .. currentAccount .. " trong danh sách"
        end
    else
        toast("Không thể mở file danh sách account: " .. accountListFile)
        return nil, "Không thể mở file danh sách account: " .. accountListFile
    end

    return accountName
end

-- Chỉnh sửa file ImportedBackups.plist để chạy account chỉ định
function changeAccount.changeAccount(accountName)
    local plistFile = output_folder .. "/ImportedBackups.plist"
    local success, file = pcall(io.open, plistFile, "r")
    if not success then
        toast("Không thể mở file ImportedBackups.plist")
        return false, "Không thể mở file ImportedBackups.plist"
    end

    local content = file:read("*all")
    file:close()

    -- Thay thế "name backup" bằng accountName
    local newContent = content:gsub("name backup", accountName)

    -- Ghi lại nội dung đã thay đổi vào file ImportedBackups.plist trong thư mục ADManager
    success, file = pcall(io.open, importedBackupsPlist, "w")
    if not success then
        toast("Không thể ghi file ImportedBackups.plist")
        return false, "Không thể ghi file ImportedBackups.plist"
    end

    file:write(newContent)
    file:close()
    return true
end

-- Mở ứng dụng ADManager
function changeAccount.openADManager()
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
        return false, "Không thể mở Apps Manager"
    end
    
    -- Đợi app khởi động
    mSleep(3000)
    
    -- Kiểm tra app có ở foreground không
    if not isFrontApp(bundleID) then
        toast("Apps Manager không ở foreground sau khi mở")
        return false, "Apps Manager không ở foreground sau khi mở"
    end
    
    return true
end

-- Tìm và bấm vào danh sách các ứng dụng
function changeAccount.clickAppsList()
    local coord = config.admanager.app_list_coord
    
    toast("Bấm vào danh sách ứng dụng")
    tap(coord[1], coord[2])
    mSleep(2000)
    
    return true
end

-- Tìm và bấm vào ứng dụng TikTok Lite bằng tìm kiếm màu sắc
function changeAccount.findAndClickTikTokIcon()
    
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
            return false, "Không tìm thấy biểu tượng TikTok Lite trong danh sách"
        end
    end
end

-- Bấm vào nút Restore AppData
function changeAccount.restoreAccount()
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
    
    -- Lấy thông tin tài khoản hiện tại và tổng số tài khoản
    local currentAccount, totalAccounts = changeAccount.getCurrentAccount()
    
    -- Tăng số account ngay sau khi restore
    toast("Tăng số account lên " .. (currentAccount + 1) .. "/" .. totalAccounts)
    currentAccount = currentAccount + 1
    
    -- Cập nhật file currentbackup.txt sau khi tăng currentAccount
    local updateSuccess, updateError = changeAccount.updateCurrentAccount(currentAccount, totalAccounts)
    if not updateSuccess then
        toast("Không thể cập nhật file currentbackup.txt: " .. (updateError or ""))
        -- Tiếp tục thực hiện mặc dù có lỗi
    end

    return true
end

-- Thực hiện đầy đủ quy trình chuyển đổi tài khoản TikTok
function changeAccount.switchTikTokAccount()
    -- 1. Mở ADManager
    local success, reason = changeAccount.openADManager()
    if not success then
        return false, reason
    end
    
    -- 2. Bấm vào danh sách ứng dụng
    local clickSuccess = changeAccount.clickAppsList()
    if not clickSuccess then
        return false, "Không thể bấm vào danh sách ứng dụng"
    end
    
    -- 3. Tìm và bấm vào ứng dụng TikTok Lite
    local findSuccess, findReason = changeAccount.findAndClickTikTokIcon()
    if not findSuccess then
        return false, findReason or "Không thể tìm thấy biểu tượng TikTok Lite"
    end
    
    -- 4. Bấm vào nút Restore AppData
    local restoreSuccess = changeAccount.restoreAccount()
    if not restoreSuccess then
        return false, "Không thể thực hiện khôi phục dữ liệu"
    end
    
    return true
end

-- Cập nhật file currentbackup.txt
function changeAccount.updateCurrentAccount(currentAccount, totalAccounts)
    local currentBackupFile = output_folder .. "/currentbackup.txt"
    local currentFile = io.open(currentBackupFile, "w")
    if currentFile then
        currentFile:write(currentAccount .. "\n" .. totalAccounts)
        currentFile:close()
        return true
    else
        toast("Không thể cập nhật file currentbackup.txt")
        return false, "Không thể cập nhật file currentbackup.txt"
    end
end

-- Xuất các biến toàn cục để có thể truy cập từ bên ngoài
changeAccount.input_folder = input_folder
changeAccount.output_folder = output_folder
changeAccount.importedBackupsPlist = importedBackupsPlist

return changeAccount 