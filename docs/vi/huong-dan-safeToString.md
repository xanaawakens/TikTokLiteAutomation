# Hướng dẫn sử dụng hàm safeToString và cách tránh lỗi circular dependency

## Giới thiệu

Tài liệu này mô tả cách sử dụng hàm `safeToString` và cách tránh lỗi "too many C levels" do phụ thuộc vòng tròn (circular dependency) trong dự án TikTok Lite Automation.

## Vấn đề đã khắc phục

Dự án đã gặp phải hai lỗi chính:

1. **"attempt to concatenate a table value"**: Xảy ra khi cố gắng nối chuỗi với giá trị là bảng (table) trong file `auto_tiktok.lua` (dòng 133, 170, 186)

2. **"too many C levels (limit is 200)"**: Xảy ra khi có quá nhiều cuộc gọi hàm đệ quy do phụ thuộc vòng tròn giữa các module, cụ thể là khi `logger` sử dụng `utils.safeToString` và `utils` lại sử dụng `logger`.

## Giải pháp

### 1. Hàm safeToString đơn giản

```lua
function utils.safeToString(value)
    if value == nil then
        return "nil"
    elseif type(value) == "string" then
        return value
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    elseif type(value) == "table" then
        -- Không dùng pcall và đệ quy phức tạp để tránh lỗi stack overflow
        return "{table}"
    elseif type(value) == "function" then
        return "{function}"
    elseif type(value) == "userdata" or type(value) == "thread" then
        return "{" .. type(value) .. "}"
    else
        return "{unknown type: " .. type(value) .. "}"
    end
end
```

### 2. Tạo phiên bản safeToString cục bộ trong mỗi module

Mỗi module có nhu cầu sử dụng `safeToString` nhưng không muốn phụ thuộc vào `utils` nên tạo phiên bản cục bộ:

```lua
-- Thêm vào đầu file logger.lua, error_handler.lua, rewards_live.lua, auto_tiktok.lua
local function safeToString(value)
    if value == nil then
        return "nil"
    elseif type(value) == "string" then
        return value
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    elseif type(value) == "table" then
        return "{table}"
    elseif type(value) == "function" then
        return "{function}"
    elseif type(value) == "userdata" or type(value) == "thread" then
        return "{" .. type(value) .. "}"
    else
        return "{unknown type: " .. type(value) .. "}"
    end
end
```

### 3. Loại bỏ cuộc gọi logger trong các hàm utils

Comment các dòng gọi logger trong các hàm tiện ích để tránh phụ thuộc vòng tròn:

```lua
-- Ví dụ trong hàm retryOperation
-- Thay:
-- logger.debug("Thử lại lần " .. attempt .. "/" .. maxRetries)
-- Bằng:
-- -- logger.debug("Thử lại lần " .. attempt .. "/" .. maxRetries)
```

## Cách sử dụng

### 1. Cách ghép nối chuỗi an toàn

```lua
-- Thay vì:
local message = "Kết quả: " .. result

-- Hãy sử dụng:
local message = "Kết quả: " .. safeToString(result)
```

### 2. Khi ghi log

```lua
-- Thay vì:
logger.info("Đã nhận dữ liệu: " .. data)

-- Hãy sử dụng:
logger.info("Đã nhận dữ liệu: " .. safeToString(data))
```

### 3. Khi tạo thông báo lỗi

```lua
-- Thay vì:
local errorObj = errorHandler.createError(ERROR.VALIDATION, "Dữ liệu không hợp lệ: " .. data)

-- Hãy sử dụng:
local errorObj = errorHandler.createError(ERROR.VALIDATION, "Dữ liệu không hợp lệ: " .. safeToString(data))
```

## Cách tránh phụ thuộc vòng tròn (circular dependency)

### 1. Nguyên tắc phụ thuộc một chiều

Các module cần tuân theo thứ tự phụ thuộc này:

```
config.lua  →  utils.lua  →  logger.lua  →  error_handler.lua  →  Các module nghiệp vụ
```

### 2. Sử dụng phiên bản safeToString cục bộ

Mỗi module cần `safeToString` nên có phiên bản riêng thay vì phụ thuộc vào `utils`.

### 3. Tránh gọi logger trong utils

Các hàm tiện ích cơ bản không nên gọi logger. Nếu cần log, hãy sử dụng tham số để bật/tắt ghi log:

```lua
function someUtilFunction(param, shouldLog)
    if shouldLog then
        -- Ghi log nếu cần
    end
    -- Xử lý nghiệp vụ
end
```

### 4. Sử dụng tham số "suppress" cho logger

```lua
-- Khi không cần hiển thị thông báo
logger.debug("Thông tin debug", true) -- suppress = true
```

## Lưu ý khi sửa đổi mã nguồn

1. Không sử dụng `pcall()` hoặc các hàm phức tạp trong `safeToString`
2. Không sử dụng đệ quy sâu khi chuyển đổi bảng thành chuỗi
3. Luôn kiểm tra kiểu dữ liệu trước khi xử lý
4. Ưu tiên sử dụng phiên bản cục bộ của `safeToString` trong các module cốt lõi
5. Khi gặp lỗi "too many C levels", tìm các vòng lặp phụ thuộc và cắt đứt chúng

## Cách triển khai safeToString nâng cao (khi cần)

Nếu cần chuyển đổi bảng chi tiết hơn, có thể sử dụng phiên bản này (lưu ý: chỉ sử dụng sau khi đã khắc phục vấn đề phụ thuộc vòng tròn):

```lua
function utils.advancedToString(value, maxDepth, visited)
    maxDepth = maxDepth or 2 -- Giới hạn độ sâu
    visited = visited or {}  -- Phát hiện tham chiếu vòng
    
    if type(value) ~= "table" then
        return utils.safeToString(value)
    end
    
    if maxDepth <= 0 then
        return "{...}" -- Đã vượt quá độ sâu cho phép
    end
    
    if visited[value] then
        return "{circular}"  -- Phát hiện tham chiếu vòng
    end
    
    visited[value] = true
    
    -- Xử lý bảng (chú ý kiểm tra độ sâu và tham chiếu vòng)
    -- Chi tiết triển khai phụ thuộc vào nhu cầu cụ thể
end
```

## Mẫu test để kiểm tra

```lua
local values = {
    nil,                       -- nil
    "string",                  -- chuỗi
    123,                       -- số
    true,                      -- boolean
    {a = 1, b = 2},            -- bảng đơn giản
    {nest = {more = {deep = true}}}, -- bảng lồng nhau
    function() end,            -- hàm
    coroutine.create(function() end) -- thread
}

for _, v in ipairs(values) do
    print(safeToString(v))
end
```

Nếu gặp vấn đề khi sử dụng các hàm này, vui lòng tham khảo mã nguồn đầy đủ trong các module hoặc liên hệ với team phát triển. 