require("TSLib")

local input_folder = "/private/var/mobile/Library/ADManager"
local output_folder = "/private/var/mobile/Media/TouchSprite/lua"

-- Hàm lấy danh sách tất cả các file trong thư mục và ghi vào file
function getAllFilesInFolder(folderPath)
    local files = {}
    local outputFile = output_folder .. "/account_list.txt"
    
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
    
    -- Ghi danh sách vào file
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
    
    return files
end

getAllFilesInFolder(input_folder)