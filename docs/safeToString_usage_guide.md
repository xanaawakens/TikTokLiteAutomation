# Hướng dẫn sử dụng hàm safeToString và phòng tránh lỗi stack overflow

## Vấn đề đã khắc phục

### Lỗi "too many C levels"
Lỗi này xảy ra khi có quá nhiều cuộc gọi hàm lồng nhau, vượt quá giới hạn ngăn xếp (stack) của Lua (mặc định là 200 levels). Trong ứng dụng TikTok Lite Automation, lỗi này thường xuất hiện do:

1. **Phụ thuộc vòng tròn (Circular Dependencies)**: Các module gọi lẫn nhau tạo thành vòng lặp vô hạn.
2. **Đệ quy vô hạn**: Một hàm gọi chính nó mà không có điều kiện dừng.

### Nguyên nhân cụ thể
Trong mã nguồn hiện tại, lỗi xuất phát từ vòng lặp phụ thuộc:
- `utils.safeToString()` được sử dụng bởi `logger`
- `logger` được sử dụng trong các hàm tiện ích của `utils`
- Khi gặp lỗi, chuỗi gọi hàm vô tận sẽ xảy ra

## Giải pháp đã triển khai

### 1. Tạo phiên bản safeToString cục bộ trong mỗi module
Để cắt đứt sự phụ thuộc vòng tròn, chúng ta đã tạo một phiên bản safeToString đơn giản trong mỗi module:

```lua
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

### 2. Loại bỏ logger trong các hàm tiện ích
Đã tạm thời vô hiệu hóa các lệnh ghi log trong một số hàm tiện ích như:
- `utils.retryOperation()`
- `utils.readFileSafely()`
- `utils.writeFileAtomic()`
- `utils.isTikTokLiteInstalled()`

### 3. Đơn giản hóa hàm safeToString
Thay vì cố gắng chuyển đổi bảng thành chuỗi chi tiết (có thể dẫn đến đệ quy sâu), chúng ta đã đơn giản hóa bằng cách luôn trả về "{table}" cho các giá trị kiểu bảng.

## Các module được cập nhật

1. **utils.lua**: Chứa hàm safeToString gốc, đã đơn giản hóa và loại bỏ logger
2. **logger.lua**: Đã thêm safeToString cục bộ để tránh phụ thuộc vào utils
3. **error_handler.lua**: Đã thêm safeToString cục bộ để tránh phụ thuộc vào utils
4. **rewards_live.lua**: Đã thêm safeToString cục bộ và cập nhật tham chiếu
5. **auto_tiktok.lua**: Đã thêm safeToString cục bộ và cập nhật tham chiếu

## Hướng dẫn sử dụng

### Khi nào sử dụng safeToString
Sử dụng hàm safeToString trong các trường hợp sau:

1. **Ghép nối chuỗi với giá trị không rõ kiểu**: 
```lua
local message = "Kết quả: " .. safeToString(result)
```

2. **Ghi log thông tin lỗi**:
```lua
logger.error("Lỗi xảy ra: " .. safeToString(error))
```

3. **Xử lý kết quả trả về từ các API**:
```lua
local apiResult = someAPI.call()
logger.info("API trả về: " .. safeToString(apiResult))
```

### Lưu ý khi sử dụng logger

1. **Tránh gọi logger trong các hàm tiện ích cơ bản**:
   - Hàm safeToString
   - Hàm retryOperation
   - Các hàm I/O cơ bản

2. **Ưu tiên sử dụng suppress parameter**:
   - Truyền tham số `suppress=true` khi gọi các hàm logger trong vòng lặp hoặc hàm được gọi thường xuyên:
     ```lua
     logger.debug("Thông tin debug", true) -- Chỉ ghi vào file, không hiển thị
     ```

3. **Sử dụng cấu trúc điều kiện để tránh gọi logger không cần thiết**:
   ```lua
   if shouldLog then
       logger.info("Thông tin: " .. safeToString(data))
   end
   ```

### Cấu trúc phụ thuộc giữa các module

Để tránh lỗi circular dependency, hãy tuân thủ cấu trúc phụ thuộc sau:

```
config.lua  <--  utils.lua  <--  logger.lua  <--  error_handler.lua
                    ^                ^                ^
                    |                |                |
                    +----------------+----------------+
                               |
                   Các module nghiệp vụ khác
                   (rewards_live.lua, auto_tiktok.lua)
```

- Tránh để utils.lua phụ thuộc vào logger.lua
- Tránh để logger.lua phụ thuộc vào error_handler.lua

## Các cải tiến trong tương lai

1. **Triển khai hàm serialize đầy đủ**:
   - Có thể triển khai một hàm serialize đầy đủ để hiển thị nội dung của bảng nhưng cần xử lý:
     - Circular references (tham chiếu vòng)
     - Giới hạn độ sâu
     - Giới hạn độ dài output

2. **Cơ chế logging không đồng bộ**:
   - Xem xét triển khai cơ chế logging không đồng bộ để tránh tác động đến hiệu suất

3. **Kiểm tra kiểu dữ liệu tự động**:
   - Có thể áp dụng kiểm tra kiểu dữ liệu cho các tham số hàm quan trọng
   
## Kiểm tra lỗi

Nếu vẫn gặp lỗi "too many C levels", hãy thực hiện các bước sau:

1. Kiểm tra các module đã import utils.lua và logger.lua theo đúng thứ tự
2. Tìm các cuộc gọi logger trong các hàm tiện ích và vô hiệu hóa chúng
3. Kiểm tra tất cả các điểm sử dụng safeToString và chắc chắn rằng bạn đang sử dụng phiên bản cục bộ
4. Theo dõi stack trace để xác định điểm bắt đầu của vòng lặp vô hạn

## Kết luận

Việc tránh phụ thuộc vòng tròn và sử dụng safeToString đúng cách sẽ giúp cải thiện độ tin cậy của ứng dụng và tránh lỗi stack overflow. Luôn cẩn thận khi làm việc với các cấu trúc dữ liệu phức tạp và đảm bảo rằng các hàm không gọi lẫn nhau theo cách có thể dẫn đến vòng lặp vô hạn. 