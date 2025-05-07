-- File main.lua - File chạy chính của ứng dụng TikTok Lite Automation
-- Mô tả: File này là điểm khởi đầu của ứng dụng, quản lý luồng chạy chính và gọi các module
-- Tạo bởi: Script đã được cấu trúc lại từ mã nguồn gốc

require("TSLib")

-- Khởi tạo các biến toàn cục để lưu trữ kích thước màn hình
-- Đặt ở đầu file để đảm bảo các biến này được khởi tạo trước khi các module khác được load
_G.SCREEN_WIDTH, _G.SCREEN_HEIGHT = getScreenSize()
nLog("Khởi tạo kích thước màn hình: " .. _G.SCREEN_WIDTH .. "x" .. _G.SCREEN_HEIGHT)

-- Yêu cầu các module cần thiết
local changeAccount = require("change_account")
local autoTiktok = require("auto_tiktok")

-- Hàm chính quản lý luồng chạy của ứng dụng
local function main()
    -- Lấy danh sách tài khoản từ thư mục
    changeAccount.getAllFilesInFolder(changeAccount.input_folder)
    
    -- Lấy thông tin tài khoản hiện tại và tổng số tài khoản
    local currentAccount, totalAccounts = changeAccount.getCurrentAccount()
    
    -- Chạy từ account hiện tại đến hết
    while currentAccount <= totalAccounts do
        ::continue_loop::
        -- Đóng tất cả ứng dụng trước khi chuyển account
        closeApp("*",1)
        mSleep(3000)
        
        -- Lấy tên account và thực hiện chuyển đổi
        local accountName, nameError = changeAccount.getAccountName()
        if not accountName then
            autoTiktok.logResult(currentAccount, "unknown", false, nameError or "Không thể lấy tên account")
            toast("Không thể lấy tên account")
            return false
        end
        
        local success, changeError = changeAccount.changeAccount(accountName)
        if not success then
            autoTiktok.logResult(currentAccount, accountName, false, changeError or "Không thể chuyển account")
            toast("Không thể chuyển sang account " .. currentAccount)
            return false
        end
        
        toast("Đang chuyển sang account " .. currentAccount)
        mSleep(1500)
        
        -- Chuyển account trong TikTok
        local switchSuccess, switchError = changeAccount.switchTikTokAccount()
        if not switchSuccess then
            autoTiktok.logResult(currentAccount, accountName, false, switchError or "Không thể chuyển tài khoản TikTok")
            toast("Không thể chuyển tài khoản TikTok: " .. (switchError or ""))
            -- Tăng số account và tiếp tục thay vì dừng hẳn
            currentAccount = currentAccount + 1
            local updateSuccess = changeAccount.updateCurrentAccount(currentAccount, totalAccounts)
            goto continue_loop -- Chuyển sang account tiếp theo
        end
        
        mSleep(1500)
        
        -- Cập nhật file currentbackup.txt trước khi chạy automation
        local updateSuccess, updateError = changeAccount.updateCurrentAccount(currentAccount, totalAccounts)
        if not updateSuccess then
            autoTiktok.logResult(currentAccount, accountName, false, updateError or "Không thể cập nhật file currentbackup.txt")
            toast("Không thể cập nhật file currentbackup.txt")
            return false
        end
        
        mSleep(7000)
        
        -- Chạy automation cho account hiện tại
        toast("Đang chạy account thứ " .. currentAccount .. "/" .. totalAccounts)
        mSleep(1000)
        
        local result, reason = autoTiktok.runTikTokLiteAutomation()
        autoTiktok.logResult(currentAccount, accountName, result, reason or (result and "Hoàn thành nhiệm vụ" or "Lỗi không xác định"))
        
        mSleep(3000)
        closeApp("*",1)
        
        -- Tăng số account sau khi chạy xong
        -- (Đã được xử lý trong changeAccount.restoreAccount() - không cần tăng ở đây để tránh tăng 2 lần)
        -- currentAccount = currentAccount + 1
        
        -- Cập nhật file currentbackup.txt sau khi tăng currentAccount
        -- (Đã được xử lý trong changeAccount.restoreAccount() - không cần cập nhật ở đây)
        -- local finalUpdateSuccess, finalUpdateError = changeAccount.updateCurrentAccount(currentAccount, totalAccounts)
        -- if not finalUpdateSuccess then
        --     autoTiktok.logResult("ERROR", "", false, "Không thể cập nhật file currentbackup.txt sau khi chạy account " .. (currentAccount-1))
        --     toast("Không thể cập nhật file currentbackup.txt")
        --     return false
        -- end
        
        -- Đọc lại số account hiện tại từ file (đã được cập nhật trong restoreAccount)
        currentAccount, totalAccounts = changeAccount.getCurrentAccount()
    end
    
    -- Reset currentAccount về 1 và cập nhật file
    local resetSuccess, resetError = changeAccount.updateCurrentAccount(1, totalAccounts)
    if not resetSuccess then
        toast("Không thể reset currentAccount về 1")
        return false
    end
    
    toast("Đã chạy xong tất cả " .. totalAccounts .. " account và reset về account 1")
    return true
end

-- Khởi động ứng dụng 
local function startApplication()
    toast("Đang khởi động TikTok Lite Automation...")
    mSleep(2000)
    
    -- Gọi hàm main
    local success = main()
    
    if success then
        toast("Quá trình tự động hóa kết thúc thành công")
    else
        toast("Quá trình tự động hóa kết thúc với lỗi")
    end
    
    mSleep(3000)
    return success
end

-- Khởi chạy ứng dụng
startApplication()
