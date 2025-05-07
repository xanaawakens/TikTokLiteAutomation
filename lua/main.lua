-- File main.lua - File chạy chính của ứng dụng TikTok Lite Automation
-- Mô tả: File này là điểm khởi đầu của ứng dụng, quản lý luồng chạy chính và gọi các module
-- Tạo bởi: Script đã được cấu trúc lại từ mã nguồn gốc

require("TSLib")

-- Khởi tạo các biến toàn cục để lưu trữ kích thước màn hình
-- Đặt ở đầu file để đảm bảo các biến này được khởi tạo trước khi các module khác được load
_G.SCREEN_WIDTH, _G.SCREEN_HEIGHT = getScreenSize()
-- Khởi tạo thời gian bắt đầu chạy script
_G.scriptStartTime = os.time()

local logger = require("logger")
logger.info("Khởi tạo kích thước màn hình: " .. _G.SCREEN_WIDTH .. "x" .. _G.SCREEN_HEIGHT)

-- Yêu cầu các module cần thiết
local changeAccount = require("change_account")
local autoTiktok = require("auto_tiktok")
local fileManager = require("file_manager") -- Thêm module quản lý file

-- Hàm chính quản lý luồng chạy của ứng dụng
local function main()
    -- Cập nhật danh sách tài khoản từ thư mục
    local listSuccess, _, listError = fileManager.updateAccountList()
    if not listSuccess then
        logger.error("Không thể cập nhật danh sách tài khoản: " .. (listError or ""))
        -- Vẫn tiếp tục vì có thể đã có danh sách cũ
    end
    
    -- Lấy thông tin tài khoản hiện tại và tổng số tài khoản
    local currentAccount, totalAccounts = fileManager.getCurrentAccount()
    
    -- Chạy từ account hiện tại đến hết
    while currentAccount <= totalAccounts do
        ::continue_loop::
        -- Đóng tất cả ứng dụng trước khi chuyển account
        closeApp("*",1)
        mSleep(3000)
        
        -- Lấy tên account
        local getNameSuccess, accountName, nameError = fileManager.getAccountName()
        if not getNameSuccess then
            fileManager.logResult(currentAccount, "unknown", false, nameError or "Không thể lấy tên account")
            logger.error("Không thể lấy tên account: " .. (nameError or ""))
            return false
        end
        
        -- Cập nhật tên account trong file ImportedBackups.plist
        local updateNameSuccess, _, updateNameError = fileManager.updateAccountName(accountName)
        if not updateNameSuccess then
            fileManager.logResult(currentAccount, accountName, false, updateNameError or "Không thể cập nhật tên account")
            logger.error("Không thể cập nhật tên account: " .. (updateNameError or ""))
            return false
        end
        
        mSleep(1500)
        
        -- Chuyển account trong TikTok
        local switchSuccess, switchResult = changeAccount.switchTikTokAccount()
        if not switchSuccess then
            fileManager.logResult(currentAccount, accountName, false, switchResult or "Không thể chuyển tài khoản TikTok")
            logger.error("Không thể chuyển tài khoản TikTok: " .. (switchResult or ""))
            
            -- Tăng số account và tiếp tục thay vì dừng hẳn
            if currentAccount < totalAccounts then
                currentAccount = currentAccount + 1
                local updateSuccess, _, updateError = fileManager.updateCurrentAccount(currentAccount, totalAccounts)
                if not updateSuccess then
                    logger.error("Không thể cập nhật file currentbackup.txt khi chuyển account: " .. (updateError or ""))
                    -- Vẫn tiếp tục với account đã tăng trong memory
                end
                logger.info("Chuyển sang account tiếp theo: " .. currentAccount .. "/" .. totalAccounts)
            else
                logger.warning("Đã đến account cuối cùng. Thử reset về account đầu tiên.")
                currentAccount = 1
                local updateSuccess, _, updateError = fileManager.updateCurrentAccount(currentAccount, totalAccounts)
                if not updateSuccess then
                    logger.error("Không thể reset về account đầu tiên: " .. (updateError or ""))
                    return false
                end
            end
            
            goto continue_loop -- Chuyển sang account tiếp theo
        end
        
        -- Nếu thành công và switchResult là số, cập nhật currentAccount
        if type(switchResult) == "number" then
            currentAccount = switchResult
            logger.debug("Cập nhật số account hiện tại thành: " .. currentAccount)
        end
        
        mSleep(1500)
        
        -- Cập nhật file currentbackup.txt trước khi chạy automation
        local updateSuccess, _, updateError = fileManager.updateCurrentAccount(currentAccount, totalAccounts)
        if not updateSuccess then
            fileManager.logResult(currentAccount, accountName, false, updateError or "Không thể cập nhật file currentbackup.txt")
            logger.error("Không thể cập nhật file currentbackup.txt: " .. (updateError or ""))
            return false
        end
        
        mSleep(7000)
        
        local result, reason = autoTiktok.runTikTokLiteAutomation()
        fileManager.logResult(currentAccount, accountName, result, reason or (result and "Hoàn thành nhiệm vụ" or "Lỗi không xác định"))
        
        mSleep(3000)
        closeApp("*",1)
        
        -- Kiểm tra lại tổng số account định kỳ (mỗi 5 account) để đảm bảo chính xác
        if currentAccount % 5 == 0 then
            local _, newTotalAccounts = fileManager.getCurrentAccount()
            if newTotalAccounts ~= totalAccounts then
                logger.info("Cập nhật tổng số account từ " .. totalAccounts .. " thành " .. newTotalAccounts)
                totalAccounts = newTotalAccounts
            end
        end
    end
    
    -- Reset currentAccount về 1 và cập nhật file
    local resetSuccess, _, resetError = fileManager.updateCurrentAccount(1, totalAccounts)
    if not resetSuccess then
        logger.error("Không thể reset currentAccount về 1: " .. (resetError or ""))
        return false
    end
    
    logger.info("Đã chạy xong tất cả " .. totalAccounts .. " account và reset về account 1")
    return true
end

-- Khởi động ứng dụng 
local function startApplication()
    logger.info("Đang khởi động TikTok Lite Automation...")
    mSleep(2000)
    
    -- Gọi hàm main
    local success = main()
    
    if success then
        logger.info("Quá trình tự động hóa kết thúc thành công")
    else
        logger.error("Quá trình tự động hóa kết thúc với lỗi")
    end
    
    -- Đóng logger
    logger.close()
    
    mSleep(3000)
    return success
end

-- Khởi chạy ứng dụng
startApplication()
