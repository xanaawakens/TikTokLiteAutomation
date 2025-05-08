--[[
  file_manager.lua - Module quản lý file cho ứng dụng TikTok Lite Automation
  
  Module này cung cấp các chức năng:
  - Đọc và ghi file an toàn với cơ chế atomic để tránh mất dữ liệu
  - Tự động tạo backup trước khi thực hiện các thao tác nguy hiểm
  - Xử lý lỗi và retry cho các thao tác file quan trọng
  - Quản lý nhất quán đường dẫn và thư mục
]]

require("TSLib")
local utils = require("utils")
local logger = require("logger")

local fileManager = {}

-- Các đường dẫn mặc định
fileManager.paths = {
    base = "/private/var/mobile/Media/TouchSprite/lua",
    backup = "/private/var/mobile/Media/TouchSprite/lua/backups",
    logs = "/private/var/mobile/Media/TouchSprite/logs",
    screenshots = "/private/var/mobile/Media/TouchSprite/screenshots",
    admanager = "/private/var/mobile/Library/ADManager"
}

-- Các file quan trọng
fileManager.files = {
    account_list = fileManager.paths.base .. "/account_list.txt",
    current_account = fileManager.paths.base .. "/currentbackup.txt",
    analysis = fileManager.paths.base .. "/analysis.txt",
    imported_backups = fileManager.paths.admanager .. "/ImportedBackups.plist"
}

-- Đảm bảo thư mục tồn tại
function fileManager.ensureDirectoryExists(dirPath)
    local command = "mkdir -p \"" .. dirPath .. "\" 2>/dev/null"
    local success = os.execute(command)
    
    if not success then
        logger.warning("Không thể tạo thư mục: " .. dirPath)
    end
    
    return success
end

-- Kiểm tra thư mục tồn tại
function fileManager.directoryExists(dirPath)
    local command = "[ -d \"" .. dirPath .. "\" ] && echo 1 || echo 0"
    local handle = io.popen(command)
    
    if not handle then
        return false
    end
    
    local result = handle:read("*a")
    handle:close()
    
    return result:match("1") ~= nil
end

-- Kiểm tra file tồn tại
function fileManager.fileExists(filePath)
    local file = io.open(filePath, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

-- Lấy danh sách file trong thư mục
function fileManager.listFiles(dirPath, pattern)
    -- Đảm bảo thư mục tồn tại
    if not fileManager.directoryExists(dirPath) then
        return false, nil, "Thư mục không tồn tại: " .. dirPath
    end
    
    -- Lệnh liệt kê file
    local command = "ls -la \"" .. dirPath .. "\" 2>/dev/null"
    local handle = io.popen(command)
    
    if not handle then
        return false, nil, "Không thể thực hiện lệnh ls"
    end
    
    local result = handle:read("*a")
    handle:close()
    
    -- Danh sách file
    local files = {}
    
    -- Phân tích kết quả để lấy tên file
    for line in result:gmatch("[^\r\n]+") do
        -- Bỏ qua dòng đầu tiên và dòng chứa "." và ".."
        if not line:match("^total") and not line:match(" %.$") and not line:match(" %.%.$") then
            -- Mẫu ls -la thường có định dạng: 
            -- drwxr-xr-x  2 user group   4096 Apr 22 10:34 filename
            
            local isDir = line:match("^d") ~= nil
            
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
                
                -- Lọc theo pattern nếu có
                if not pattern or fileName:match(pattern) then
                    table.insert(files, {
                        name = fileName,
                        isDirectory = isDir,
                        path = dirPath .. "/" .. fileName
                    })
                end
            end
        end
    end
    
    return true, files, nil
end

-- Tạo backup file
function fileManager.backupFile(filePath, suffix)
    -- Kiểm tra file tồn tại
    if not fileManager.fileExists(filePath) then
        return false, nil, "File không tồn tại: " .. filePath
    end
    
    -- Đảm bảo thư mục backup tồn tại
    fileManager.ensureDirectoryExists(fileManager.paths.backup)
    
    -- Tạo tên file backup
    local fileName = filePath:match("([^/]+)$")
    if not fileName then
        return false, nil, "Không thể xác định tên file từ đường dẫn"
    end
    
    suffix = suffix or os.date("_%Y%m%d_%H%M%S")
    local backupFileName = fileName .. suffix
    local backupPath = fileManager.paths.backup .. "/" .. backupFileName
    
    -- Đọc nội dung file gốc
    local success, content, error = fileManager.readFile(filePath)
    if not success then
        return false, nil, "Không thể đọc file gốc: " .. (error or "")
    end
    
    -- Ghi nội dung vào file backup
    local writeSuccess, _, writeError = fileManager.writeFile(backupPath, content, false)
    if not writeSuccess then
        return false, nil, "Không thể ghi file backup: " .. (writeError or "")
    end
    
    logger.debug("Đã tạo bản sao lưu: " .. backupPath)
    return true, backupPath, nil
end

-- Phục hồi file từ backup
function fileManager.restoreFromBackup(originalPath, backupPath)
    -- Kiểm tra file backup tồn tại
    if not fileManager.fileExists(backupPath) then
        return false, nil, "File backup không tồn tại: " .. backupPath
    end
    
    -- Đọc nội dung file backup
    local success, content, error = fileManager.readFile(backupPath)
    if not success then
        return false, nil, "Không thể đọc file backup: " .. (error or "")
    end
    
    -- Ghi nội dung vào file gốc
    local writeSuccess, _, writeError = fileManager.writeFile(originalPath, content, false)
    if not writeSuccess then
        return false, nil, "Không thể phục hồi file: " .. (writeError or "")
    end
    
    logger.info("Đã phục hồi file " .. originalPath .. " từ " .. backupPath)
    return true, nil, nil
end

-- Đọc file với cơ chế retry
function fileManager.readFile(filePath, defaultContent)
    -- Chuyển đổi các đường dẫn viết tắt
    if filePath:sub(1, 1) ~= "/" then
        if fileManager.files[filePath] then
            filePath = fileManager.files[filePath]
        else
            filePath = fileManager.paths.base .. "/" .. filePath
        end
    end
    
    return utils.readFileSafely(filePath, defaultContent)
end

-- Ghi file với cơ chế atomic và backup tự động
function fileManager.writeFile(filePath, content, backupFirst)
    -- Chuyển đổi các đường dẫn viết tắt
    if filePath:sub(1, 1) ~= "/" then
        if fileManager.files[filePath] then
            filePath = fileManager.files[filePath]
        else
            filePath = fileManager.paths.base .. "/" .. filePath
        end
    end
    
    -- Mặc định là tạo backup trước khi ghi đè
    if backupFirst == nil then
        backupFirst = true
    end
    
    -- Fix: Đảm bảo chỉ truyền đúng 3 tham số cho writeFileAtomic
    return utils.writeFileAtomic(filePath, content, backupFirst)
end

-- Lấy tài khoản hiện tại và tổng số tài khoản
function fileManager.getCurrentAccount()
    local defaultContent = "1\n1" -- Mặc định là tài khoản 1/1
    local success, content, error = fileManager.readFile(fileManager.files.current_account, defaultContent)
    
    if not success then
        logger.error("Không thể đọc file current_account: " .. (error or ""))
        return 1, 1
    end
    
    -- Phân tích nội dung
    local currentAccount = 1
    local totalAccounts = 1
    
    -- Đọc dòng đầu tiên - số account hiện tại
    local line1 = content:match("^([^\r\n]+)")
    if line1 then
        currentAccount = tonumber(line1) or 1
    end
    
    -- Đọc dòng thứ hai - tổng số account
    local line2 = content:match("\n([^\r\n]+)")
    if line2 then
        totalAccounts = tonumber(line2) or 1
    end
    
    -- Kiểm tra và điều chỉnh giá trị
    if currentAccount < 1 then currentAccount = 1 end
    if totalAccounts < 1 then totalAccounts = 1 end
    if currentAccount > totalAccounts then currentAccount = totalAccounts end
    
    return currentAccount, totalAccounts
end

-- Cập nhật tài khoản hiện tại
function fileManager.updateCurrentAccount(currentAccount, totalAccounts)
    -- Kiểm tra tham số
    if type(currentAccount) ~= "number" then
        return false, nil, "currentAccount phải là số"
    end
    
    if type(totalAccounts) ~= "number" then
        return false, nil, "totalAccounts phải là số"
    end
    
    -- Điều chỉnh giá trị
    if currentAccount < 1 then currentAccount = 1 end
    if totalAccounts < 1 then totalAccounts = 1 end
    if currentAccount > totalAccounts then currentAccount = totalAccounts end
    
    -- Tạo nội dung
    local content = currentAccount .. "\n" .. totalAccounts
    
    -- Ghi file
    return fileManager.writeFile(fileManager.files.current_account, content, true)
end

-- Lấy tên tài khoản hiện tại
function fileManager.getAccountName()
    -- Lấy số tài khoản hiện tại
    local currentAccount, _ = fileManager.getCurrentAccount()
    
    -- Đọc danh sách tài khoản
    local success, content, error = fileManager.readFile(fileManager.files.account_list)
    if not success then
        return false, nil, "Không thể đọc danh sách tài khoản: " .. (error or "")
    end
    
    -- Tìm tên tài khoản ứng với số hiện tại
    for line in content:gmatch("[^\r\n]+") do
        local number, name = line:match("(%d+):%s*(.+)")
        if number and tonumber(number) == currentAccount and name then
            return true, name, nil
        end
    end
    
    return false, nil, "Không tìm thấy tài khoản số " .. currentAccount .. " trong danh sách"
end

-- Cập nhật danh sách tài khoản từ thư mục ADManager
function fileManager.updateAccountList()
    -- Lấy danh sách file .adbk từ thư mục ADManager
    local success, files, error = fileManager.listFiles(fileManager.paths.admanager, "%.adbk$")
    
    if not success then
        return false, nil, "Không thể lấy danh sách file từ ADManager: " .. (error or "")
    end
    
    -- Lọc và tạo danh sách account
    local accounts = {}
    for _, fileInfo in ipairs(files) do
        if not fileInfo.isDirectory and fileInfo.name:match("%.adbk$") then
            local nameWithoutExt = fileInfo.name:gsub("%.adbk$", "")
            table.insert(accounts, nameWithoutExt)
        end
    end
    
    -- Sắp xếp danh sách tài khoản
    table.sort(accounts)
    
    -- Lấy thông tin tài khoản hiện tại để giữ nguyên
    local currentAccount, _ = fileManager.getCurrentAccount()
    
    -- Tạo nội dung file account_list.txt
    local content = ""
    for i, accountName in ipairs(accounts) do
        content = content .. i .. ": " .. accountName .. "\n"
    end
    
    -- Ghi danh sách vào file
    local writeSuccess, _, writeError = fileManager.writeFile(fileManager.files.account_list, content, true)
    if not writeSuccess then
        return false, nil, "Không thể ghi danh sách tài khoản: " .. (writeError or "")
    end
    
    -- Cập nhật file currentbackup.txt, giữ nguyên số account hiện tại
    local updateSuccess, _, updateError = fileManager.updateCurrentAccount(currentAccount, #accounts)
    if not updateSuccess then
        return false, nil, "Không thể cập nhật thông tin tài khoản hiện tại: " .. (updateError or "")
    end
    
    logger.info("Đã cập nhật danh sách " .. #accounts .. " tài khoản")
    return true, accounts, nil
end

-- Ghi log kết quả thực thi
function fileManager.logResult(account, accountName, success, reason)
    local outputFile = fileManager.files.analysis
    
    -- Tạo nội dung log
    local currentTime = os.date("%Y-%m-%d %H:%M:%S")
    local status = success and "successfully" or "failed"
    
    -- Thông tin cơ bản luôn được ghi
    local logEntry = account .. ":" .. accountName .. " " .. status .. " " .. currentTime
    
    -- Nếu failed, ghi chi tiết hơn về lỗi
    if not success then
        -- Kiểm tra kiểu dữ liệu của reason để tránh lỗi concatenate
        local reasonStr = ""
        if reason == nil then
            reasonStr = "Unknown error"
        elseif type(reason) == "table" then
            reasonStr = "Error object (table)"
            -- Có thể bổ sung xử lý chi tiết hơn cho table ở đây nếu cần
        else
            reasonStr = tostring(reason)
        end
        
        -- Thêm dòng mới và thụt lề để dễ đọc
        logEntry = logEntry .. "\n    ERROR: " .. reasonStr
        
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
        local ssFolder = fileManager.paths.screenshots
        
        -- Tạo thư mục nếu chưa tồn tại
        fileManager.ensureDirectoryExists(ssFolder)
        
        local ssFilename = account .. "_" .. timestamp .. ".png"
        screenshotPath = ssFolder .. "/" .. ssFilename
        
        -- Chụp ảnh màn hình
        snapshot(screenshotPath, 0, 0, _G.SCREEN_WIDTH, _G.SCREEN_HEIGHT)
        
        -- Thêm đường dẫn ảnh vào log
        logEntry = logEntry .. "\n    SCREENSHOT: " .. screenshotPath .. "\n"
    else
        -- Nếu thành công, chỉ thêm lý do
        -- Cũng cần kiểm tra kiểu dữ liệu khi thành công
        if reason ~= nil then
            if type(reason) == "table" then
                logEntry = logEntry .. ": Success object"
            else
                logEntry = logEntry .. ": " .. tostring(reason)
            end
        end
    end
    
    -- Fix: Đảm bảo file tồn tại trước khi ghi
    if not fileManager.fileExists(outputFile) then
        -- Tạo file mới nếu chưa tồn tại
        local newFileSuccess, _, newFileError = fileManager.writeFile(outputFile, "", false)
        if not newFileSuccess then
            logger.error("Không thể tạo file analysis.txt: " .. tostring(newFileError or ""))
            return false
        end
    end
    
    -- Đọc nội dung hiện tại của file
    local readSuccess, existingContent, readError = fileManager.readFile(outputFile, "")
    if not readSuccess then
        logger.error("Không thể đọc nội dung hiện tại của file analysis.txt: " .. tostring(readError or ""))
        return false
    end
    
    -- Thêm log mới vào nội dung hiện tại 
    local newContent = existingContent .. logEntry .. "\n"
    
    -- Fix: Ghi vào file kết quả với tham số đúng (chỉ 3 tham số)
    local writeSuccess, _, writeError = fileManager.writeFile(outputFile, newContent, false)
    if not writeSuccess then
        logger.error("Không thể ghi kết quả vào file analysis.txt: " .. tostring(writeError or "") .. 
                     " (Đường dẫn: " .. outputFile .. ")")
        return false
    end
    
    logger.info("Đã ghi log thành công vào file analysis.txt")
    return true
end

-- Cập nhật tên tài khoản trong file ImportedBackups.plist
function fileManager.updateAccountName(accountName)
    -- Đảm bảo tham số hợp lệ
    if type(accountName) ~= "string" or accountName == "" then
        return false, nil, "Tên tài khoản không hợp lệ"
    end
    
    -- Đọc nội dung file plist template
    local templatePath = fileManager.paths.base .. "/ImportedBackups.plist"
    if not fileManager.fileExists(templatePath) then
        return false, nil, "Không tìm thấy file template ImportedBackups.plist"
    end
    
    local success, content, error = fileManager.readFile(templatePath)
    if not success then
        return false, nil, "Không thể đọc file template ImportedBackups.plist: " .. tostring(error or "")
    end
    
    -- Thay thế "name backup" bằng accountName
    local newContent = content:gsub("name backup", accountName)
    
    -- Đường dẫn đến thư mục đích
    local targetDir = "/private/var/mobile/Library/ADManager"
    local targetPath = targetDir .. "/ImportedBackups.plist"
    
    -- Đảm bảo thư mục đích tồn tại
    if not fileManager.directoryExists(targetDir) then
        local success, _, error = fileManager.ensureDirectoryExists(targetDir)
        if not success then
            return false, nil, "Không thể tạo thư mục đích: " .. tostring(error or "")
        end
    end
    
    -- Ghi nội dung đã chỉnh sửa vào vị trí đích
    local writeSuccess, _, writeError = fileManager.writeFile(targetPath, newContent, true)
    if not writeSuccess then
        return false, nil, "Không thể ghi vào file ImportedBackups.plist ở thư mục đích: " .. tostring(writeError or "")
    end
    
    logger.debug("Đã tạo file ImportedBackups.plist với tên tài khoản: " .. accountName)
    return true, targetPath, nil
end

-- Khởi tạo mô-đun
function fileManager.init()
    -- Đảm bảo các thư mục quan trọng tồn tại
    fileManager.ensureDirectoryExists(fileManager.paths.base)
    fileManager.ensureDirectoryExists(fileManager.paths.backup)
    fileManager.ensureDirectoryExists(fileManager.paths.logs)
    fileManager.ensureDirectoryExists(fileManager.paths.screenshots)
    
    -- Kiểm tra và đảm bảo các file quan trọng có thể ghi
    local analysisFile = fileManager.files.analysis
    if not fileManager.fileExists(analysisFile) then
        -- Tạo file analysis.txt nếu chưa tồn tại
        local success, _, error = fileManager.writeFile(analysisFile, "", false)
        if not success then
            logger.warning("Không thể tạo file analysis.txt: " .. tostring(error or ""))
        else
            logger.debug("Đã tạo file analysis.txt")
        end
    else
        -- Kiểm tra quyền ghi vào file
        local testFile = io.open(analysisFile, "a")
        if testFile then
            testFile:close()
            logger.debug("File analysis.txt tồn tại và có thể ghi")
        else
            logger.warning("File analysis.txt tồn tại nhưng không thể ghi")
        end
    end
    
    logger.info("Đã khởi tạo file_manager")
    return true
end

-- Khởi tạo tự động khi load module
fileManager.init()

return fileManager 