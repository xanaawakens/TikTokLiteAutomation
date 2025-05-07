# Tài liệu tham khảo module utils

## Giới thiệu

Module `utils.lua` cung cấp các hàm tiện ích cho toàn bộ ứng dụng TikTok Lite Automation. Module này là nền tảng cốt lõi và được sử dụng bởi hầu hết các module khác trong hệ thống.

## Các hàm chính

### 1. Chuyển đổi giá trị an toàn

#### `safeToString(value)`

Chuyển đổi bất kỳ giá trị nào thành chuỗi, kể cả khi giá trị là bảng, hàm, hoặc nil.

```lua
local tableValue = {key = "value"}
local safeStr = utils.safeToString(tableValue) -- Kết quả: "{table}"
```

**Lưu ý quan trọng**: 
- Không sử dụng logger trong hàm safeToString vì có thể gây ra lỗi phụ thuộc vòng tròn
- Phiên bản đơn giản đã được triển khai để tránh stack overflow
- Trong các module khác, nên tạo bản sao cục bộ của hàm này thay vì phụ thuộc vào utils

### 2. Kiểm tra tham số

#### `validateParam(param, paramName, paramType, isRequired, validValues)`

Kiểm tra tính hợp lệ của tham số.

```lua
local isValid, errMsg = utils.validateParam(x, "x", "number", true)
if not isValid then
    return false, errMsg
end
```

**Tham số**:
- `param`: Giá trị tham số cần kiểm tra
- `paramName`: Tên tham số để hiển thị trong thông báo lỗi
- `paramType`: Kiểu dữ liệu mong đợi của tham số
- `isRequired`: Boolean chỉ định tham số có bắt buộc hay không
- `validValues`: Bảng chứa các giá trị hợp lệ (tùy chọn)

### 3. Thực thi an toàn

#### `safeExecute(func, ...)`

Thực thi một hàm trong môi trường protected (pcall) để bắt lỗi.

```lua
local success, result, error = utils.safeExecute(tap, x, y)
if not success then
    return false, "Lỗi: " .. error
end
```

**Tham số**:
- `func`: Hàm cần thực thi an toàn
- `...`: Các tham số truyền cho hàm

**Giá trị trả về**:
- `success`: true nếu thành công, false nếu thất bại
- `result`: Kết quả của hàm nếu thành công, nil nếu thất bại
- `error`: Thông báo lỗi nếu thất bại, nil nếu thành công

### 4. Tìm kiếm mẫu màu

#### `findColorPattern(matrix, region, similarity)`

Tìm kiếm mẫu màu trong vùng màn hình.

```lua
local found, result, error = utils.findColorPattern(config.color_patterns.live_button, config.search_regions.live_button)
if found then
    -- Xử lý khi tìm thấy
end
```

**Tham số**:
- `matrix`: Ma trận chứa các điểm màu cần tìm
- `region`: Vùng màn hình cần tìm (tùy chọn)
- `similarity`: Độ tương đồng màu sắc (0-100, mặc định từ config)

#### `convertMatrixToOffsetString(matrix)`

Chuyển đổi ma trận màu thành chuỗi offset cho findMultiColorInRegionFuzzy.

```lua
local mainColor, mainX, mainY, offsetStr = utils.convertMatrixToOffsetString(matrix)
```

### 5. Tương tác ứng dụng

#### `openTikTokLite(verify)`

Mở ứng dụng TikTok Lite và đợi cho đến khi tải xong.

```lua
local success, error = utils.openTikTokLite(true)
if not success then
    return false, "Không thể mở TikTok Lite: " .. error
end
```

#### `isTikTokLiteInstalled()`

Kiểm tra TikTok Lite đã được cài đặt chưa.

```lua
local installed, error = utils.isTikTokLiteInstalled()
if not installed then
    return false, "TikTok Lite chưa được cài đặt"
end
```

#### `checkTikTokLoadedByColor()`

Kiểm tra TikTok Lite đã load xong chưa bằng mẫu màu.

```lua
local loaded, error = utils.checkTikTokLoadedByColor()
if not loaded then
    return false, "TikTok Lite chưa load xong"
end
```

#### `waitForScreen(colorOrImage, x, y, sim, timeout)`

Đợi màn hình hiển thị màu hoặc hình ảnh cụ thể.

```lua
local found, error = utils.waitForScreen(config.colors.live_button, 100, 200, 90, 5)
```

### 6. Thao tác màn hình

#### `tapWithConfig(x, y, description, customDelay)`

Thực hiện tap với độ trễ từ cấu hình.

```lua
local success, _, error = utils.tapWithConfig(100, 200, "nút live")
```

#### `swipeWithConfig(x1, y1, x2, y2, duration, description)`

Thực hiện vuốt với độ trễ từ cấu hình.

```lua
local success, _, error = utils.swipeWithConfig(100, 200, 100, 400, 0.5, "lên trên")
```

#### `swipeNextVideo()`

Vuốt lên để xem video tiếp theo.

```lua
local success, _, error = utils.swipeNextVideo()
```

#### `getDeviceScreen()`

Lấy kích thước màn hình thiết bị.

```lua
local width, height = utils.getDeviceScreen()
```

### 7. Xử lý popup

#### `checkAndClosePopupByImage(imageName, clickCoords, swipeAction, timeout)`

Tìm và đóng popup bằng hình ảnh.

```lua
local closed, error = utils.checkAndClosePopupByImage(config.images.popup.general, config.popup_close.general, true)
```

#### `checkAndClosePopup()`

Kiểm tra và đóng popup ở vùng màn hình cụ thể.

```lua
local closed, error = utils.checkAndClosePopup()
```

#### `checkAndCloseAddFriendsPopup()`

Kiểm tra và đóng popup Add Friends khi mới mở app TikTok.

```lua
local closed, error = utils.checkAndCloseAddFriendsPopup()
```

#### `clickLiveWithPopupCheck(liveButtonX, liveButtonY)`

Bấm vào nút live sau khi kiểm tra popup.

```lua
local success, error = utils.clickLiveWithPopupCheck(100, 200)
```

### 8. Thử lại thao tác

#### `retryOperation(operationFunc, maxRetries, delayMs, retryCondition)`

Thử lại thao tác trong trường hợp thất bại.

```lua
local success, result, error = utils.retryOperation(
    function() 
        return findColor(0xFF0000, 0, 0, 100, 100) 
    end,
    3,   -- maxRetries
    500, -- delayMs
    function(result) return result == -1 end -- retryCondition
)
```

**Lưu ý quan trọng**:
- Không sử dụng logger trong hàm retryOperation để tránh lỗi phụ thuộc vòng tròn
- Khi cần thử lại thao tác trong I/O, hãy triển khai mã trực tiếp thay vì gọi hàm này

### 9. I/O an toàn

#### `writeFileAtomic(filePath, content, backupFirst)`

Ghi file an toàn với cơ chế atomic write.

```lua
local success, path, error = utils.writeFileAtomic("data.txt", "Nội dung", true)
```

#### `readFileSafely(filePath, defaultContent)`

Đọc file an toàn với cơ chế retry.

```lua
local success, content, error = utils.readFileSafely("data.txt", "Default content")
```

## Cách tránh vấn đề phụ thuộc vòng tròn

1. **Nguyên tắc phụ thuộc một chiều**:
   - Hàm cấp thấp không phụ thuộc vào hàm cấp cao
   - utils → logger → error_handler → modules nghiệp vụ

2. **Tránh gọi logger trong utils**:
   - Không gọi logger trong các hàm cơ bản của utils
   - Sử dụng các hàm cục bộ khi cần thiết
   - Comment các dòng log không quan trọng

3. **Sử dụng safeToString cục bộ**:
   - Tạo phiên bản safeToString cục bộ trong từng module
   - Không phụ thuộc vào utils.safeToString cho các module cốt lõi

4. **Kiểm tra lỗi sớm**:
   - Kiểm tra giá trị đầu vào trước khi xử lý
   - Trả về lỗi rõ ràng ngay khi gặp vấn đề

## Cách triển khai hàm safeToString tùy chỉnh

Nếu cần triển khai phiên bản safeToString phức tạp hơn, hãy lưu ý:

1. **Giới hạn độ sâu đệ quy**:
```lua
function utils.safeToString(value, maxDepth)
    maxDepth = maxDepth or 2  -- Giới hạn mặc định là 2
    
    if maxDepth < 0 then
        return "{...}"  -- Đã vượt quá độ sâu cho phép
    end
    
    -- Phần còn lại của hàm...
end
```

2. **Phát hiện tham chiếu vòng**:
```lua
function utils.safeToString(value, maxDepth, visited)
    visited = visited or {}
    
    if type(value) == "table" then
        if visited[value] then
            return "{circular}"  -- Đã thấy bảng này trước đó
        end
        visited[value] = true
        
        -- Phần còn lại của hàm...
    end
end
```

3. **Giới hạn kích thước chuỗi đầu ra**:
```lua
function utils.safeToString(value, maxDepth, visited, maxLength)
    maxLength = maxLength or 1000  -- Giới hạn mặc định là 1000 ký tự
    
    local result = ""
    -- Phần còn lại của hàm...
    
    if #result > maxLength then
        result = string.sub(result, 1, maxLength) .. "..."
    end
    
    return result
end
```

## Kết luận

Module utils.lua là thành phần cốt lõi của ứng dụng TikTok Lite Automation. Việc sử dụng đúng cách các hàm trong module này sẽ giúp tránh lỗi phụ thuộc vòng tròn và stack overflow, đồng thời đảm bảo ứng dụng hoạt động ổn định. 