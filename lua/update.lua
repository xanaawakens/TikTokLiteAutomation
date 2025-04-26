--[[
  update.lua - Tự động cập nhật script từ GitHub
  
  Script này sẽ tải xuống:
  - Tất cả các file Lua từ GitHub về thư mục /private/var/mobile/Media/TouchSprite/lua
  - Tất cả các file ảnh từ thư mục res về /private/var/mobile/Media/TouchSprite/res
]]

require("TSLib")
-- Không dùng các thư viện này vì không có trong TouchSprite
-- require("socket")
-- require("http")
-- require("ltn12")

-- Cấu hình
local config = {
    -- Thông tin GitHub
    github = {
        owner = "xanaawakens",             -- Tên người dùng GitHub
        repo = "TikTokLiteAutomation",  -- Tên repository
        branch = "master",                -- Nhánh (thường là main hoặc master)
    },
    
    -- Đường dẫn trên thiết bị
    paths = {
        lua = "/private/var/mobile/Media/TouchSprite/lua/",
        res = "/private/var/mobile/Media/TouchSprite/res/",
    },
    
    -- Danh sách file cần tải xuống
    files = {
        lua = {
            "main.lua",
            "config.lua",
            "utils.lua",
            "rewards_live.lua",
            -- Thêm các file lua khác nếu cần
        },
        res = {
            "popupMission.png",
            -- Thêm các file ảnh khác nếu cần
        }
    }
}

-- Hàm tạo thư mục nếu chưa tồn tại
local function ensureDirectoryExists(path)
    local success = os.execute("mkdir -p " .. path)
    return success
end

-- Hàm tải file từ GitHub
local function downloadFileFromGitHub(owner, repo, branch, path, targetPath)
    local rawURL = string.format("https://raw.githubusercontent.com/%s/%s/%s/%s", 
                                owner, repo, branch, path)
    
    toast("Đang tải: " .. path)
    
    -- Sử dụng hàm httpGet của TouchSprite thay vì http.request
    local code, data = httpGet(rawURL)
    
    -- Kiểm tra kết quả
    if code == 200 then
        -- Ghi file xuống thiết bị
        local file = io.open(targetPath, "wb")
        if file then
            file:write(data)
            file:close()
            toast("Tải thành công: " .. path)
            return true
        else
            toast("Lỗi: Không thể ghi file " .. targetPath)
            return false
        end
    else
        toast("Lỗi: Không thể tải file " .. path .. " (HTTP " .. tostring(code) .. ")")
        return false
    end
end

-- Hàm chính để cập nhật tất cả các file
local function updateAllFiles()
    local githubConfig = config.github
    local success = true
    
    -- Tạo thư mục nếu chưa tồn tại
    ensureDirectoryExists(config.paths.lua)
    ensureDirectoryExists(config.paths.res)
    
    -- Tải các file Lua
    for _, filename in ipairs(config.files.lua) do
        local remotePath = "lua/" .. filename
        local localPath = config.paths.lua .. filename
        
        local fileSuccess = downloadFileFromGitHub(
            githubConfig.owner,
            githubConfig.repo,
            githubConfig.branch,
            remotePath,
            localPath
        )
        
        if not fileSuccess then
            success = false
        end
        mSleep(500) -- Đợi một chút để tránh gửi quá nhiều request
    end
    
    -- Tải các file ảnh
    for _, filename in ipairs(config.files.res) do
        local remotePath = "res/" .. filename
        local localPath = config.paths.res .. filename
        
        local fileSuccess = downloadFileFromGitHub(
            githubConfig.owner,
            githubConfig.repo,
            githubConfig.branch,
            remotePath,
            localPath
        )
        
        if not fileSuccess then
            success = false
        end
        mSleep(500) -- Đợi một chút để tránh gửi quá nhiều request
    end
    
    return success
end

-- Hàm main
function main()
    -- Hiển thị thông báo bắt đầu
    toast("Bắt đầu cập nhật từ GitHub...")
    
    -- Thực hiện cập nhật
    local success = updateAllFiles()
    
    -- Hiển thị kết quả
    if success then
        dialog("Cập nhật thành công!", "Thông báo")
    else
        dialog("Cập nhật thất bại! Một số file không thể tải xuống.", "Cảnh báo")
    end
end

-- Chạy chương trình
main()
