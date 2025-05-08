# Xử lý Popup trong TikTok Lite Automation

## Tổng quan

Kịch bản TikTok Lite Automation được thiết kế để tự động xử lý các popup thường xuất hiện trong quá trình sử dụng ứng dụng. Các popup này có thể ảnh hưởng đến quá trình tự động hóa nếu không được xử lý đúng cách.

## Các loại popup được xử lý

1. **Popup "Add Friends"** - Xuất hiện sau khi mở ứng dụng
2. **Popup nâng cấp phần thưởng** - Xuất hiện sau khi claim phần thưởng
3. **Popup nhiệm vụ** - Xuất hiện trong quá trình sử dụng
4. **Popup tổng quát** - Các popup khác có thể xuất hiện

## Cơ chế xử lý popup

### 1. Nhận diện popup

Popup được nhận diện bằng cách sử dụng hình ảnh mẫu và thuật toán so khớp hình ảnh (image matching). Các hình ảnh mẫu được định nghĩa với các tên file tương ứng:

- `popupAddFriends.png` - Hình ảnh popup Add Friends
- `popup1.png` - Hình ảnh popup tổng quát
- `popup2.png` - Hình ảnh popup nâng cấp phần thưởng
- `popupMission.png` - Hình ảnh popup nhiệm vụ

### 2. Đóng popup

Sau khi nhận diện được popup, kịch bản sẽ thực hiện một trong hai phương pháp đóng popup:

- **Tap vào vị trí cụ thể** - Sử dụng tọa độ đã cấu hình trong `config.popup_close`
- **Vuốt màn hình** - Đối với các popup không có nút đóng rõ ràng

### 3. Kiểm tra và đóng popup "Add Friends"

Popup "Add Friends" thường xuất hiện sau khi mở ứng dụng TikTok Lite. Để xử lý popup này, chúng ta sử dụng hàm `utils.checkAndCloseAddFriendsPopup()` trong hàm `initializeApp()`:

```lua
-- Khởi tạo và mở ứng dụng TikTok Lite
local function initializeApp()
    -- Mở TikTok Lite
    local success, error = utils.openTikTokLite(false)
    
    if not success then
        return false, "Không thể mở TikTok Lite: " .. safeToString(error or "")
    end
    
    mSleep(3000)
    
    -- Kiểm tra và đóng popup Add Friends nếu xuất hiện
    local popupClosed, popupError = utils.checkAndCloseAddFriendsPopup()
    if popupClosed then
        logger.info("Đã đóng popup Add Friends sau khi mở ứng dụng")
        -- Đợi một chút sau khi đóng popup
        mSleep(config.timing.after_popup_close * 1000)
    end
    
    return true, nil
end
```

## Cấu hình xử lý popup

Cấu hình cho việc xử lý popup được định nghĩa trong file `config.lua`:

```lua
-- Đường dẫn hình ảnh
images = {
    -- Popup images
    popup = {
        add_friends = "popupAddFriends.png",
        general = "popup1.png",
        reward = "popup2.png",
        mission = "popupMission.png"
    }
},

-- Tọa độ đóng popup
popup_close = {
    add_friends = {scaleCoord(90, 1270)},  -- Tọa độ đóng popup Add Friends
    reward = {scaleCoord(357, 1033)},      -- Tọa độ đóng popup Reward
    mission = {scaleCoord(375, 1059)},     -- Tọa độ đóng popup Mission
    general = nil                          -- Sử dụng vuốt thay vì tọa độ cụ thể
}
```

## Hướng dẫn tùy chỉnh

### Thêm popup mới

1. Chụp ảnh màn hình popup cần xử lý
2. Lưu ảnh với tên phù hợp (không cần thêm đường dẫn thư mục)
3. Thêm tên file hình ảnh vào `config.images.popup`
4. Xác định tọa độ nút đóng và thêm vào `config.popup_close`
5. Sử dụng hàm `utils.checkAndClosePopupByImage()` để xử lý popup

### Điều chỉnh tọa độ nút đóng

Nếu tọa độ nút đóng không chính xác (do kích thước màn hình khác nhau), bạn có thể điều chỉnh trong `config.popup_close`. 