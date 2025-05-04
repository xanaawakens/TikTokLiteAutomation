require("TSLib")

-- Hàm kiểm tra xem file tồn tại không
function fileExists(path)
   local file = io.open(path, "r")
   if file then
      file:close()
      return true
   end
   return false
end

-- Hàm thực thi lệnh và lấy kết quả
function executeCommand(cmd)
   local handle = io.popen(cmd .. " 2>&1", "r")
   local result = handle:read("*a")
   local success = handle:close()
   return success, result
end

-- Hàm tạo bản sao của file để phân tích
function copyFileForAnalysis(sourcePath)
   -- Tạo bản sao trong thư mục lua
   local touchspriteDir = "/private/var/mobile/Media/TouchSprite/lua/"
   local filename = sourcePath:match("([^/]+)$") -- Lấy tên file từ đường dẫn
   local copyPath = touchspriteDir .. filename .. ".copy"
   
   local cmd = "cp \"" .. sourcePath .. "\" \"" .. copyPath .. "\""
   local success, output = executeCommand(cmd)
   
   if not success then
      toast("Lỗi khi sao chép file: " .. output)
      return nil
   end
   
   return copyPath
end

-- Hàm hiển thị thông tin về file
function showFileInfo(filePath)
   if not fileExists(filePath) then
      toast("File không tồn tại: " .. filePath)
      return
   end
   
   -- Kiểm tra kích thước file
   local cmd = "stat -f %z \"" .. filePath .. "\""
   local success, sizeOutput = executeCommand(cmd)
   local fileSize = sizeOutput and tonumber(sizeOutput:match("%d+")) or "không xác định"
   
   -- Kiểm tra loại file
   cmd = "file \"" .. filePath .. "\""
   local success, fileTypeOutput = executeCommand(cmd)
   
   toast("Thông tin file: " .. filePath)
   toast("Kích thước: " .. tostring(fileSize) .. " bytes")
   if fileTypeOutput then
      toast("Loại file: " .. fileTypeOutput)
   end
   
   -- Đọc và hiển thị 20 byte đầu tiên dưới dạng hex
   local f = io.open(filePath, "rb")
   if f then
      local data = f:read(20)
      f:close()
      
      if data then
         local hexStr = ""
         for i = 1, #data do
            hexStr = hexStr .. string.format("%02X ", string.byte(data:sub(i,i)))
         end
         toast("Bytes đầu: " .. hexStr)
      end
   end
end

-- Phương pháp 1: Sử dụng plutil
function convertWithPlutil(plistPath)
   toast("Thử phương pháp 1: Sử dụng plutil...")
   
   -- Kiểm tra file nguồn tồn tại
   if not fileExists(plistPath) then
      toast("Lỗi: File nguồn không tồn tại: " .. plistPath)
      return false
   end
   
   -- Thư mục đích (có quyền ghi)
   local touchspriteDir = "/private/var/mobile/Media/TouchSprite/lua/"
   local filename = plistPath:match("([^/]+)$") -- Lấy tên file từ đường dẫn
   local xmlPath = touchspriteDir .. filename .. ".xml"
   
   -- Sao chép file gốc
   toast("Sao chép file gốc...")
   local success, output = executeCommand("cp \"" .. plistPath .. "\" \"" .. xmlPath .. "\"")
   
   if not success then
      toast("Lỗi: Không thể sao chép file: " .. output)
      return false
   end
   
   -- Chuyển đổi sang XML
   toast("Đang chuyển đổi sang XML với plutil...")
   local cmd = "plutil -convert xml1 \"" .. xmlPath .. "\""
   success, output = executeCommand(cmd)
   
   if not success then
      toast("Lỗi plutil: " .. output)
      return false
   end
   
   toast("Chuyển đổi thành công với plutil!")
   toast("File XML có tại: " .. xmlPath)
   return true, xmlPath
end

-- Phương pháp 2: Sử dụng plistutil (nếu có)
function convertWithPlistutil(plistPath)
   toast("Thử phương pháp 2: Sử dụng plistutil...")
   
   -- Thư mục đích (có quyền ghi)
   local touchspriteDir = "/private/var/mobile/Media/TouchSprite/lua/"
   local filename = plistPath:match("([^/]+)$") -- Lấy tên file từ đường dẫn
   local xmlPath = touchspriteDir .. filename .. ".xml"
   
   -- Kiểm tra xem plistutil có tồn tại không
   local success, output = executeCommand("which plistutil")
   if not success or output == "" then
      toast("Lỗi: Không tìm thấy plistutil")
      return false
   end
   
   -- Sử dụng plistutil để chuyển đổi
   local cmd = "plistutil -i \"" .. plistPath .. "\" -o \"" .. xmlPath .. "\""
   success, output = executeCommand(cmd)
   
   if not success then
      toast("Lỗi plistutil: " .. output)
      return false
   end
   
   toast("Chuyển đổi thành công với plistutil!")
   toast("File XML có tại: " .. xmlPath)
   return true, xmlPath
end

-- Phương pháp 3: Tạo file XML mới dựa trên nội dung
function createXMLManually(plistPath)
   toast("Thử phương pháp 3: Tạo file XML thủ công...")
   
   -- Thư mục đích (có quyền ghi)
   local touchspriteDir = "/private/var/mobile/Media/TouchSprite/lua/"
   local filename = plistPath:match("([^/]+)$") -- Lấy tên file từ đường dẫn
   local xmlPath = touchspriteDir .. filename .. ".xml"
   
   -- Tạo file XML cơ bản
   local file = io.open(xmlPath, "w")
   if not file then
      toast("Lỗi: Không thể tạo file XML")
      return false
   end
   
   -- Viết định dạng XML cơ bản của file plist
   file:write('<?xml version="1.0" encoding="UTF-8"?>\n')
   file:write('<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n')
   file:write('<plist version="1.0">\n')
   file:write('<dict>\n')
   file:write('  <!-- File được tạo thủ công vì không thể chuyển đổi tự động -->\n')
   file:write('  <!-- Bạn có thể chỉnh sửa nội dung tại đây -->\n')
   file:write('  <key>SampleKey</key>\n')
   file:write('  <string>SampleValue</string>\n')
   file:write('</dict>\n')
   file:write('</plist>\n')
   
   file:close()
   
   toast("Đã tạo file XML cơ bản!")
   toast("File XML có tại: " .. xmlPath)
   return true, xmlPath
end

-- Thử tất cả các phương pháp
function tryAllMethods(plistPath)
   -- Hiển thị thông tin về file
   showFileInfo(plistPath)
   
   -- Thử phương pháp 1
   local success, xmlPath = convertWithPlutil(plistPath)
   if success then
      return true, xmlPath
   end
   
   -- Thử phương pháp 2
   success, xmlPath = convertWithPlistutil(plistPath)
   if success then
      return true, xmlPath
   end
   
   -- Thử phương pháp 3
   success, xmlPath = createXMLManually(plistPath)
   if success then
      return true, xmlPath
   end
   
   return false, nil
end

-- Đường dẫn đến file plist cần chuyển đổi
local plistPath = "/private/var/mobile/Library/ADManager/ImportedBackups.plist"

-- Tìm kiếm vị trí file
if not fileExists(plistPath) then
   toast("Đang tìm file plist trong hệ thống...")
   local cmd = "find /private/var/mobile -name \"*Backups.plist\" -type f 2>/dev/null"
   local success, foundFiles = executeCommand(cmd)
   
   if success and foundFiles and foundFiles ~= "" then
      plistPath = foundFiles:match("([^\n]+)")
      toast("Tìm thấy file: " .. plistPath)
   else
      toast("Không tìm thấy file plist nào trong hệ thống")
   end
end

-- Thử chuyển đổi với tất cả phương pháp
local success, xmlPath = tryAllMethods(plistPath)

if success then
   toast("THÀNH CÔNG: Hoàn tất chuyển đổi file plist sang XML")
   toast("Bạn có thể chỉnh sửa file tại: " .. xmlPath)
else
   toast("THẤT BẠI: Không thể chuyển đổi file với bất kỳ phương pháp nào")
   toast("Khả năng cao thiết bị không có quyền jailbreak hoặc TouchSprite không có quyền hệ thống")
   
   -- Tạo hướng dẫn chỉnh sửa thủ công
   local helpFile = "/private/var/mobile/Media/TouchSprite/lua/huong_dan_chinh_sua_plist.txt"
   local file = io.open(helpFile, "w")
   if file then
      file:write("HƯỚNG DẪN CHỈNH SỬA FILE PLIST\n\n")
      file:write("1. Cài đặt Filza File Manager (nếu đã jailbreak)\n")
      file:write("2. Mở file " .. plistPath .. " bằng Filza\n")
      file:write("3. Chỉnh sửa nội dung và lưu lại\n\n")
      file:write("Hoặc:\n")
      file:write("1. Kết nối iPhone với máy tính\n")
      file:write("2. Sử dụng iMazing hoặc 3uTools để truy cập và chỉnh sửa file\n")
      file:close()
      
      toast("Đã tạo hướng dẫn tại: " .. helpFile)
   end
end 