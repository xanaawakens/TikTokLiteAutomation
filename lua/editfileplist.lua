require("TSLib")

-- Kiểm tra xem file tồn tại không
function fileExists(path)
   local file = io.open(path, "r")
   if file then
      file:close()
      return true
   end
   return false
end

-- Phương pháp thay thế: Sao chép file đến thư mục có quyền ghi, sửa ở đó
function copyEditCopy(plistPath, lineNumber, newContent)
   toast("Thử phương pháp sao chép và chỉnh sửa...")
   
   -- Kiểm tra file nguồn tồn tại
   if not fileExists(plistPath) then
      toast("Lỗi: File nguồn không tồn tại: " .. plistPath)
      return false
   end
   
   -- Thư mục có quyền ghi của TouchSprite
   local touchspriteDir = "/private/var/mobile/Media/TouchSprite/lua/"
   local filename = plistPath:match("([^/]+)$") -- Lấy tên file từ đường dẫn
   local tempPath = touchspriteDir .. filename .. ".temp"
   
   -- Tạo bản sao file
   toast("Đang sao chép file...")
   local cmd = "cp \"" .. plistPath .. "\" \"" .. tempPath .. "\" 2>&1"
   local result = os.execute(cmd)
   
   if result ~= 0 and result ~= true then
      toast("Lỗi: Không thể sao chép file")
      return false
   end
   
   -- Kiểm tra file đã sao chép
   if not fileExists(tempPath) then
      toast("Lỗi: Không tìm thấy file đã sao chép")
      return false
   end
   
   toast("Đã sao chép file thành công")
   
   -- Kiểm tra xem file là dạng nhị phân hay văn bản
   local f = io.open(tempPath, "r")
   local firstBytes = f:read(10)
   f:close()
   
   -- Phát hiện định dạng nhị phân
   local isBinary = false
   for i = 1, #firstBytes do
      local byte = string.byte(firstBytes:sub(i,i))
      if byte < 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
         isBinary = true
         break
      end
   end
   
   local editSuccess = false
   
   if isBinary then
      toast("Phát hiện file plist dạng nhị phân")
      -- Chuyển đổi từ nhị phân sang XML
      cmd = "plutil -convert xml1 \"" .. tempPath .. "\" 2>&1"
      result = os.execute(cmd)
      
      if result ~= 0 and result ~= true then
         toast("Lỗi: Không thể chuyển đổi từ nhị phân sang XML")
      else
         toast("Đã chuyển đổi file sang XML thành công")
         -- Chỉnh sửa file XML
         editSuccess = editPlistLine(tempPath, lineNumber, newContent)
         
         if editSuccess then
            -- Chuyển trở lại định dạng nhị phân
            cmd = "plutil -convert binary1 \"" .. tempPath .. "\" 2>&1"
            result = os.execute(cmd)
            
            if result ~= 0 and result ~= true then
               toast("Cảnh báo: Không thể chuyển về định dạng nhị phân")
            else
               toast("Đã chuyển về định dạng nhị phân thành công")
            end
         end
      end
   else
      -- Chỉnh sửa file văn bản thông thường
      editSuccess = editPlistLine(tempPath, lineNumber, newContent)
   end
   
   if editSuccess then
      toast("Đã chỉnh sửa file thành công, đang cố gắng sao chép trở lại...")
      -- Cố gắng sao chép file đã sửa trở lại vị trí gốc
      cmd = "cp \"" .. tempPath .. "\" \"" .. plistPath .. "\" 2>&1"
      result = os.execute(cmd)
      
      if result ~= 0 and result ~= true then
         toast("Lỗi: Không thể sao chép file trở lại vị trí gốc")
         toast("File đã chỉnh sửa có tại: " .. tempPath)
         return false
      else
         toast("Đã sao chép file trở lại vị trí gốc thành công")
         -- Xóa file tạm
         os.remove(tempPath)
         return true
      end
   else
      toast("Lỗi: Không thể chỉnh sửa file tạm")
      -- Xóa file tạm
      os.remove(tempPath)
      return false
   end
end

-- Thử sử dụng phương pháp IO Lua truyền thống
function editPlistLine(plistPath, lineNumber, newContent)
   -- Kiểm tra file tồn tại
   if not fileExists(plistPath) then
      toast("Lỗi: File không tồn tại: " .. plistPath)
      return false
   end
   
   local file = io.open(plistPath, "r")
   if not file then 
      toast("Lỗi: Không thể mở file để đọc")
      return false 
   end
   
   -- Đọc nội dung file
   local lines = {}
   local i = 1
   for line in file:lines() do
      lines[i] = line
      i = i + 1
   end
   file:close()
   
   -- Hiển thị thông tin về file
   toast("Đã đọc file thành công: " .. #lines .. " dòng")
   
   -- Kiểm tra số dòng
   if lineNumber > #lines then 
      toast("Lỗi: Số dòng vượt quá số dòng trong file (" .. #lines .. " dòng)")
      return false 
   end
   
   -- Lưu giá trị cũ và thay đổi nội dung
   local oldContent = lines[lineNumber]
   lines[lineNumber] = newContent
   
   -- Thử tạo file tạm để kiểm tra quyền ghi
   local tempPath = plistPath .. ".temp"
   local tempFile = io.open(tempPath, "w")
   if not tempFile then
      toast("Lỗi: Không có quyền ghi vào thư mục này")
      return false
   end
   tempFile:close()
   os.remove(tempPath)
   
   -- Ghi file
   file = io.open(plistPath, "w")
   if not file then 
      toast("Lỗi: Không thể mở file để ghi")
      return false 
   end
   
   for i, line in ipairs(lines) do
      file:write(line .. "\n")
   end
   file:close()
   
   toast("Chỉnh sửa dòng " .. lineNumber .. " thành công")
   toast("Đã thay đổi: '" .. oldContent .. "' thành '" .. newContent .. "'")
   return true
end

-- Sử dụng plutil command nếu plist là dạng nhị phân
function editPlistWithPlutil(plistPath, keyPath, newValue)
   toast("Thử chỉnh sửa plist với plutil...")
   
   -- Kiểm tra file tồn tại
   if not fileExists(plistPath) then
      toast("Lỗi: File không tồn tại: " .. plistPath)
      return false
   end
   
   -- Backup file gốc
   local backupPath = plistPath .. ".backup"
   local cmd = "cp \"" .. plistPath .. "\" \"" .. backupPath .. "\" 2>&1"
   local result = os.execute(cmd)
   
   if result ~= 0 and result ~= true then
      toast("Lỗi: Không thể tạo backup file")
      return false
   end
   
   -- Sử dụng plutil để sửa file plist
   cmd = "plutil -replace \"" .. keyPath .. "\" -string \"" .. newValue .. "\" \"" .. plistPath .. "\" 2>&1"
   result = os.execute(cmd)
   
   if result ~= 0 and result ~= true then
      toast("Lỗi: Không thể sửa file plist với plutil")
      
      -- Restore từ backup nếu thất bại
      os.execute("cp \"" .. backupPath .. "\" \"" .. plistPath .. "\"")
      os.execute("rm \"" .. backupPath .. "\"")
      
      return false
   end
   
   -- Xóa file backup
   os.execute("rm \"" .. backupPath .. "\"")
   
   toast("Chỉnh sửa plist thành công với plutil")
   return true
end

-- Sử dụng defaults command (cách khác)
function editPlistWithDefaults(plistPath, domain, key, newValue)
   toast("Thử chỉnh sửa plist với defaults...")
   
   -- Kiểm tra file tồn tại
   if not fileExists(plistPath) then
      toast("Lỗi: File không tồn tại: " .. plistPath)
      return false
   end
   
   -- Sử dụng defaults để sửa file plist
   local cmd = "defaults write \"" .. domain .. "\" \"" .. key .. "\" \"" .. newValue .. "\" 2>&1"
   local result = os.execute(cmd)
   
   if result ~= 0 and result ~= true then
      toast("Lỗi: Không thể sửa file plist với defaults")
      return false
   end
   
   toast("Chỉnh sửa plist thành công với defaults")
   return true
end

-- Thông tin về các file đang xử lý
local filePaths = {
   "/private/var/mobile/Library/ADManager/ImportedBackups.plist"
}

-- Kiểm tra tất cả các file có thể
for _, path in ipairs(filePaths) do
   if fileExists(path) then
      toast("Tìm thấy file: " .. path)
      
      -- Thử phương pháp 1: IO Lua
      toast("Phương pháp 1: IO Lua")
      local result1 = editPlistLine(path, 198, "edit by lua")
      
      if result1 then
         toast("Đã hoàn thành chỉnh sửa file plist: " .. path)
      else
         toast("Không thể chỉnh sửa với IO Lua, thử phương pháp khác...")
         
         -- Thử phương pháp 2: plutil
         toast("Phương pháp 2: plutil")
         local result2 = editPlistWithPlutil(path, "Key", "edit by lua plutil")
         
         if result2 then
            toast("Đã hoàn thành chỉnh sửa file plist với plutil")
         else
            -- Thử phương pháp 3: defaults
            toast("Phương pháp 3: defaults")
            local domain = "com.touchsprite.admanager"
            local result3 = editPlistWithDefaults(path, domain, "ImportedKey", "edit by lua defaults")
            
            if result3 then
               toast("Đã hoàn thành chỉnh sửa file plist với defaults")
            else
               -- Thử phương pháp 4: Sao chép, chỉnh sửa, sao chép lại
               toast("Tất cả phương pháp trực tiếp thất bại, thử phương pháp cuối cùng...")
               local result4 = copyEditCopy(path, 198, "edit by lua copy method")
               
               if result4 then
                  toast("Đã hoàn thành chỉnh sửa file plist với phương pháp sao chép")
               else
                  toast("Tất cả các phương pháp chỉnh sửa đều thất bại")
                  toast("Khả năng cao là thiết bị không có quyền jailbreak hoặc không có quyền truy cập")
                  toast("Bạn cần sử dụng Filza hoặc công cụ có quyền cao hơn để chỉnh sửa file này")
               end
            end
         end
      end
   else
      toast("File không tồn tại: " .. path)
   end
end

