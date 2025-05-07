-- Module change_account.lua - Chức năng chuyển đổi tài khoản
-- Mô tả: Chứa các hàm để làm việc với danh sách tài khoản, thay đổi tài khoản trong ADManager

require("TSLib")
local config = require("config")
local logger = require("logger")
local fileManager = require("file_manager")  -- Sử dụng module quản lý file mới

local changeAccount = {}

-- Đường dẫn chính
local input_folder = "/private/var/mobile/Library/ADManager"
local output_folder = "/private/var/mobile/Media/TouchSprite/lua"
local importedBackupsPlist = "/private/var/mobile/Library/ADManager/ImportedBackups.plist"

-- Thêm đường dẫn backup
local backup_folder = output_folder .. "/backups"

-- Tạo thư mục backup nếu chưa tồn tại
local function ensureBackupFolderExists()
    local command = "mkdir -p \"" .. backup_folder .. "\" 2>/dev/null"
    local result = os.execute(command)
    if not result then
        logger.warning("Không thể tạo thư mục backup: " .. backup_folder)
    end
    return result
end

-- Hàm tạo bản sao lưu file
local function backupFile(filePath, backupSuffix)
    if not ensureBackupFolderExists() then
        return false, "Không thể tạo thư mục backup"
    end
    
    -- Tạo tên file backup
    local fileName = filePath:match("([^/]+)$")
    if not fileName then
        return false, "Không thể xác định tên file từ đường dẫn"
    end
    
    backupSuffix = backupSuffix or os.date("_%Y%m%d_%H%M%S")
    local backupFileName = fileName .. backupSuffix
    local backupPath = backup_folder .. "/" .. backupFileName
    
    -- Kiểm tra file nguồn tồn tại
    local sourceFile = io.open(filePath, "r")
    if not sourceFile then
        return false, "File nguồn không tồn tại: " .. filePath
    end
    
    -- Đọc nội dung file nguồn
    local content = sourceFile:read("*all")
    sourceFile:close()
    
    -- Ghi nội dung vào file backup
    local backupFile = io.open(backupPath, "w")
    if not backupFile then
        return false, "Không thể tạo file backup: " .. backupPath
    end
    
    backupFile:write(content)
    backupFile:close()
    
    logger.debug("Đã tạo bản sao lưu: " .. backupPath)
    return true, backupPath
end

-- Hàm phục hồi file từ bản sao lưu
local function restoreFromBackup(originalFilePath, backupFilePath)
    -- Kiểm tra file backup tồn tại
    local backupFile = io.open(backupFilePath, "r")
    if not backupFile then
        return false, "File backup không tồn tại: " .. backupFilePath
    end
    
    -- Đọc nội dung file backup
    local content = backupFile:read("*all")
    backupFile:close()
    
    -- Ghi nội dung vào file gốc
    local originalFile = io.open(originalFilePath, "w")
    if not originalFile then
        return false, "Không thể ghi vào file gốc: " .. originalFilePath
    end
    
    originalFile:write(content)
    originalFile:close()
    
    logger.info("Đã phục hồi file " .. originalFilePath .. " từ backup")
    return true
end

-- Hàm lấy danh sách tất cả các file trong thư mục và ghi vào file
function changeAccount.getAllFilesInFolder(folderPath)
    local files = {}
    local outputFile = output_folder .. "/account_list.txt"
    local currentBackupFile = output_folder .. "/currentbackup.txt"
    
    -- Lấy số account hiện tại để giữ nguyên khi cập nhật
    local currentAccount = 1
    local currentBackup = io.open(currentBackupFile, "r")
    if currentBackup then
        currentAccount = tonumber(currentBackup:read()) or 1
        currentBackup:close()
        logger.debug("Giữ nguyên currentAccount = " .. currentAccount .. " khi quét lại danh sách file")
    end
    
    -- Sử dụng io.popen để liệt kê các file
    local command = "ls -la \"" .. folderPath .. "\" 2>/dev/null"
    local handle = io.popen(command)
    
    if not handle then
        logger.error("Không thể thực hiện lệnh ls trên thư mục")
        return files
    end
    
    local result = handle:read("*a")
    handle:close()
    
    -- Kiểm tra xem thư mục có tồn tại không
    if result == "" then
        logger.error("Thư mục không tồn tại: " .. folderPath)
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
    
    -- Tạo backup trước khi ghi vào account_list.txt
    backupFile(outputFile, "_before_update")
    
    -- Ghi danh sách vào file account_list.txt
    local file = io.open(outputFile, "w")
    if file then
        for i, fileName in ipairs(files) do
            file:write(i .. ": " .. fileName .. "\n")
        end
        file:close()
        logger.info("Đã ghi danh sách vào file: " .. outputFile .. " (" .. #files .. " files)")
    else
        logger.error("Không thể ghi vào file: " .. outputFile)
    end
    
    -- Cập nhật file currentbackup.txt, giữ nguyên số account hiện tại
    local updateSuccess, updateError = changeAccount.updateCurrentAccount(currentAccount, #files)
    if not updateSuccess then
        logger.error("Không thể cập nhật file currentbackup.txt: " .. (updateError or ""))
    else
        logger.info("Đã cập nhật tổng số accounts: " .. #files .. ", giữ nguyên account hiện tại: " .. currentAccount)
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
    else
        -- Nếu file không tồn tại, tạo file với giá trị mặc định
        logger.warning("File currentbackup.txt không tồn tại, tạo file mới với giá trị mặc định")
        local updateSuccess, updateError = changeAccount.updateCurrentAccount(1, 1)
        if not updateSuccess then
            logger.error("Không thể tạo file currentbackup.txt: " .. (updateError or ""))
        end
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
            logger.error("Không tìm thấy account số " .. currentAccount .. " trong danh sách")
            return nil, "Không tìm thấy account số " .. currentAccount .. " trong danh sách"
        end
    else
        logger.error("Không thể mở file danh sách account: " .. accountListFile)
        return nil, "Không thể mở file danh sách account: " .. accountListFile
    end

    return accountName
end

-- Chỉnh sửa file ImportedBackups.plist để chạy account chỉ định
function changeAccount.changeAccount(accountName)
    local plistFile = output_folder .. "/ImportedBackups.plist"
    local success, file = pcall(io.open, plistFile, "r")
    if not success then
        logger.error("Không thể mở file ImportedBackups.plist")
        return false, "Không thể mở file ImportedBackups.plist"
    end

    local content = file:read("*all")
    file:close()

    -- Thay thế "name backup" bằng accountName
    local newContent = content:gsub("name backup", accountName)

    -- Tạo backup trước khi ghi đè
    backupFile(importedBackupsPlist, "_before_change")
    
    -- Ghi lại nội dung đã thay đổi vào file ImportedBackups.plist trong thư mục ADManager
    success, file = pcall(io.open, importedBackupsPlist, "w")
    if not success then
        logger.error("Không thể ghi file ImportedBackups.plist")
        return false, "Không thể ghi file ImportedBackups.plist"
    end

    file:write(newContent)
    file:close()
    logger.debug("Đã cập nhật tên account thành: " .. accountName)
    return true
end

-- Mở ứng dụng ADManager
function changeAccount.openADManager()
    local bundleID = config.admanager.bundle_id
    
    logger.info("Đang mở Apps Manager")
    
    -- Đóng app nếu đang chạy để mở lại từ đầu
    if appIsRunning(bundleID) then
        closeApp(bundleID)
        mSleep(2000)
    end
    
    -- Mở ứng dụng ADManager
    local openResult = runApp(bundleID)
    
    if not openResult then
        logger.error("Không thể mở Apps Manager")
        return false, "Không thể mở Apps Manager"
    end
    
    -- Đợi app khởi động
    mSleep(3000)
    
    -- Kiểm tra app có ở foreground không
    if not isFrontApp(bundleID) then
        logger.error("Apps Manager không ở foreground sau khi mở")
        return false, "Apps Manager không ở foreground sau khi mở"
    end
    
    return true
end

-- Tìm và bấm vào danh sách các ứng dụng
function changeAccount.clickAppsList()
    local coord = config.admanager.app_list_coord
    
    logger.debug("Bấm vào danh sách ứng dụng tại vị trí " .. coord[1] .. "," .. coord[2])
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
    
    -- Nút Restore thường nằm ở phía dưới màn hình - Sử dụng cấu hình
    local restoreX, restoreY = table.unpack(config.admanager.restore_button_coord)
    local accountX, accountY = table.unpack(config.admanager.account_select_coord)

    logger.debug("Chọn tài khoản tại vị trí " .. accountX .. "," .. accountY)
    tap(accountX, accountY)
    mSleep(3000)

    logger.debug("Bấm nút Restore tại vị trí " .. restoreX .. "," .. restoreY)
    tap(restoreX, restoreY)
    mSleep(1000)
    
    -- Lấy thông tin tài khoản hiện tại và tổng số tài khoản
    local currentAccount, totalAccounts = fileManager.getCurrentAccount()
    
    -- Kiểm tra trước khi tăng account để đảm bảo không vượt quá tổng số
    if currentAccount >= totalAccounts then
        logger.warning("Đã đến account cuối cùng: " .. currentAccount .. "/" .. totalAccounts)
        -- Không tăng account và trả về account hiện tại
        return true, currentAccount
    end
    
    -- Tăng số account ngay sau khi restore
    local newAccountNumber = currentAccount + 1
    logger.info("Tăng số account lên " .. newAccountNumber .. "/" .. totalAccounts)
    
    -- Cập nhật file currentbackup.txt sau khi tăng currentAccount
    local updateSuccess, _, updateError = fileManager.updateCurrentAccount(newAccountNumber, totalAccounts)
    if not updateSuccess then
        logger.error("Không thể cập nhật file currentbackup.txt: " .. (updateError or ""))
        -- Vẫn trả về account đã tăng mặc dù không lưu được file
        -- Ghi nhớ giá trị đã tăng để main.lua có thể sử dụng
        return true, newAccountNumber
    end

    -- Trả về trạng thái thành công và số account hiện tại đã tăng
    return true, newAccountNumber
end

-- Thực hiện đầy đủ quy trình chuyển đổi tài khoản TikTok
function changeAccount.switchTikTokAccount()
    closeApp(config.admanager.bundle_id)
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
    local restoreSuccess, newAccount = changeAccount.restoreAccount()
    if not restoreSuccess then
        return false, "Không thể thực hiện khôi phục dữ liệu"
    end
    
    return true, newAccount
end

-- Cập nhật file currentbackup.txt với cơ chế atomic và backup
function changeAccount.updateCurrentAccount(currentAccount, totalAccounts)
    -- Kiểm tra tham số
    if type(currentAccount) ~= "number" then
        logger.error("updateCurrentAccount: currentAccount phải là số, nhận được: " .. type(currentAccount))
        return false, "currentAccount phải là số"
    end
    
    if type(totalAccounts) ~= "number" then
        logger.error("updateCurrentAccount: totalAccounts phải là số, nhận được: " .. type(totalAccounts))
        return false, "totalAccounts phải là số"
    end
    
    -- Đảm bảo currentAccount không vượt quá totalAccounts
    if currentAccount > totalAccounts then
        logger.warning("updateCurrentAccount: currentAccount (" .. currentAccount .. ") vượt quá totalAccounts (" .. totalAccounts .. "), điều chỉnh")
        currentAccount = totalAccounts
    end
    
    -- Đảm bảo currentAccount không nhỏ hơn 1
    if currentAccount < 1 then
        logger.warning("updateCurrentAccount: currentAccount (" .. currentAccount .. ") nhỏ hơn 1, điều chỉnh")
        currentAccount = 1
    end
    
    local currentBackupFile = output_folder .. "/currentbackup.txt"
    local tempFile = currentBackupFile .. ".tmp"
    
    -- Tạo backup file hiện tại trước khi thay đổi
    local backupSuccess, backupPath = backupFile(currentBackupFile)
    if not backupSuccess then
        logger.warning("Không thể tạo backup cho currentbackup.txt: " .. (backupPath or ""))
        -- Tiếp tục mặc dù không backup được, ghi nhật ký để debug
    end
    
    -- Ghi vào file tạm trước để đảm bảo atomic operation
    local tempSuccess, tempFileHandle = pcall(io.open, tempFile, "w")
    if not tempSuccess or not tempFileHandle then
        logger.error("Không thể tạo file tạm để cập nhật currentbackup.txt")
        return false, "Không thể tạo file tạm"
    end
    
    -- Nội dung cần ghi
    local content = currentAccount .. "\n" .. totalAccounts
    
    -- Ghi nội dung vào file tạm
    local writeSuccess, writeError = pcall(function() 
        tempFileHandle:write(content)
        tempFileHandle:flush() -- Đảm bảo dữ liệu được ghi xuống đĩa
        tempFileHandle:close()
    end)
    
    if not writeSuccess then
        logger.error("Lỗi khi ghi vào file tạm: " .. tostring(writeError))
        -- Xóa file tạm nếu ghi lỗi
        os.remove(tempFile)
        return false, "Lỗi khi ghi vào file tạm: " .. tostring(writeError)
    end
    
    -- Di chuyển file tạm thành file thật - atomic operation
    local renameSuccess = os.rename(tempFile, currentBackupFile)
    
    if not renameSuccess then
        logger.error("Không thể di chuyển file tạm thành file thật")
        
        -- Cố gắng phương pháp thay thế bằng cách copy nội dung từ file tạm
        local copySuccess = false
        
        -- Thử đọc file tạm
        local tempReadFile = io.open(tempFile, "r")
        if tempReadFile then
            local tempContent = tempReadFile:read("*all")
            tempReadFile:close()
            
            -- Thử ghi vào file thật
            local finalFile = io.open(currentBackupFile, "w")
            if finalFile then
                finalFile:write(tempContent)
                finalFile:close()
                copySuccess = true
            end
        end
        
        -- Xóa file tạm
        os.remove(tempFile)
        
        if not copySuccess then
            -- Thử phục hồi từ backup
            if backupSuccess then
                local restoreSuccess, restoreError = restoreFromBackup(currentBackupFile, backupPath)
                if not restoreSuccess then
                    logger.error("Không thể phục hồi từ backup: " .. (restoreError or ""))
                else
                    logger.warning("Đã phục hồi file từ backup sau khi không thể cập nhật")
                end
            end
            
            return false, "Không thể cập nhật file currentbackup.txt"
        end
    end
    
    -- Xóa file tạm nếu vẫn còn (trường hợp rename thất bại nhưng copy thành công)
    if renameSuccess == false then
        os.remove(tempFile)
    end
    
    logger.debug("Đã cập nhật file currentbackup.txt: " .. currentAccount .. "/" .. totalAccounts)
    return true
end

-- Xuất các biến toàn cục để có thể truy cập từ bên ngoài
changeAccount.input_folder = input_folder
changeAccount.output_folder = output_folder
changeAccount.importedBackupsPlist = importedBackupsPlist

return changeAccount 