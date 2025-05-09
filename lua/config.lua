--[[
  config.lua - Cấu hình cho kịch bản TikTok Lite Automation
  
  File này chứa các thông số cấu hình cho kịch bản, bao gồm:
  - Thông tin ứng dụng
  - Cài đặt thời gian
  - Cài đặt độ chính xác
  - Ma trận màu kiểm tra
  - Vùng tìm kiếm
  - Tọa độ giao diện
  - Màu sắc kiểm tra
  - Đường dẫn lưu trữ
  - Cài đặt ghi log
  - Đường dẫn hình ảnh popup (đã tập trung hóa)
  - Tọa độ đóng popup (đã tập trung hóa)
]]

-- Lấy kích thước màn hình để tính toán tọa độ tương đối
-- Lấy kích thước màn hình một lần và lưu trữ toàn cục
_G.SCREEN_WIDTH, _G.SCREEN_HEIGHT = getScreenSize()

-- Hàm tính toán tọa độ theo tỷ lệ màn hình
local function scaleCoord(x, y, baseWidth, baseHeight)
    baseWidth = baseWidth or 750   -- Chiều rộng màn hình chuẩn (iPhone)
    baseHeight = baseHeight or 1334 -- Chiều cao màn hình chuẩn cho tọa độ
    
    local scaledX, scaledY
    
    -- Kiểm tra và tính toán scaledX chỉ khi x không phải nil
    if x ~= nil then
        scaledX = math.floor(x * (_G.SCREEN_WIDTH / baseWidth))
    end
    
    -- Kiểm tra và tính toán scaledY chỉ khi y không phải nil
    if y ~= nil then
        scaledY = math.floor(y * (_G.SCREEN_HEIGHT / baseHeight))
    end
    
    return scaledX, scaledY
end

local config = {
    -- Thông tin về cấu hình và phiên bản
    meta = {
        version = "2.0.0",           -- Phiên bản của file cấu hình (removed backward compatibility)
        base_width = 750,            -- Chiều rộng màn hình chuẩn cho tọa độ
        base_height = 1334,          -- Chiều cao màn hình chuẩn cho tọa độ
        screen_width = _G.SCREEN_WIDTH, -- Chiều rộng màn hình thực tế
        screen_height = _G.SCREEN_HEIGHT, -- Chiều cao màn hình thực tế
    },
    
    -- Thông tin ứng dụng
    app = {
        bundle_id = "com.ss.iphone.ugc.tiktok.lite",  -- Bundle ID của TikTok Lite
        name = "TikTok Lite",                         -- Tên hiển thị
        version = "1.0.0"                             -- Phiên bản kịch bản
    },
    
    limits = {
        account_runtime = 99999999,     -- Thời gian tối đa chạy cho một tài khoản (giây) - effectively no limit
        total_runtime = 99999999,      -- Thời gian tối đa chạy cho tất cả tài khoản (giây) - effectively no limit
        max_accounts = 50,         -- Số tài khoản tối đa được xử lý
        claim_attempts = 100,      -- Số lần claim tối đa cho một tài khoản
        max_live_streams = 5,      -- Số live stream tối đa xem cho một tài khoản
        max_failures = 3           -- Số lần thất bại tối đa trước khi bỏ qua tài khoản
    },
    
    -- Cài đặt thời gian (đơn vị: giây)
    timing = {
        -- Timing chung
        launch_wait = 6,           -- Thời gian chờ sau khi mở app
        check_timeout = 10,        -- Thời gian tối đa để kiểm tra app đã mở
        tap_delay = 0.5,           -- Độ trễ sau mỗi lần tap
        swipe_delay = 1,           -- Độ trễ sau mỗi lần vuốt
        video_watch_time = 15,     -- Thời gian xem mỗi video
        reward_check_interval = 60, -- Thời gian giữa các lần kiểm tra phần thưởng
        
        -- Timing cho điểm danh hàng ngày
        mission_tab_search = 2,    -- Thời gian chờ trước khi tìm tab nhiệm vụ
        scroll_delay = 0.5,        -- Thời gian chờ sau mỗi lần cuộn
        
        -- Timing cho rewards_live.lua
        live_button_search = 2.5,  -- Thời gian chờ trước khi tìm nút live
        ui_stabilize = 1.5,        -- Thời gian chờ UI ổn định sau khi thực hiện thao tác
        action_verification = 3,   -- Thời gian chờ để xác minh một hành động
        claim_check_interval = 1,  -- Thời gian giữa các lần kiểm tra nút claim (giảm từ 3s xuống 1s)
        reward_click_wait = 8,     -- Thời gian chờ sau khi bấm nút phần thưởng
        reward_popup_interval = 3, -- Thời gian giữa các lần kiểm tra popup phần thưởng
        
        -- Timing cho quá trình claim
        claim_tap_delay = 0.5,     -- Thời gian chờ sau khi tap vào nút claim (giảm xuống)
        after_claim_delay = 1,     -- Thời gian chờ sau khi claim thành công (giảm từ 2s xuống 1s)
        popup_check_after_claim = 5, -- Thời gian chờ trước khi kiểm tra popup sau claim
        
        -- Timing cho utils.lua
        popup_detection = 5,       -- Thời gian tối đa để tìm kiếm popup (giây)
        popup_check_delay = 0.2,   -- Thời gian giữa các lần kiểm tra popup (giây)
        after_popup_close = 1,     -- Thời gian chờ sau khi đóng popup (giây)
        swipe_step_delay = 0.005,  -- Độ trễ giữa các bước vuốt (giây)
        app_close_wait = 3,        -- Thời gian chờ sau khi đóng app (giây)
        find_color_timeout = 5     -- Thời gian tối đa tìm kiếm mẫu màu (giây)
    },
    
    -- Cài đặt chung
    general = {
        check_ui_after_launch = false,  -- Kiểm tra UI sau khi mở app
        retry_on_failure = true,        -- Thử lại khi gặp lỗi
        max_retry_count = 3,            -- Số lần thử lại tối đa
        log_to_file = true,             -- Ghi log ra file
        auto_scale_coords = true,       -- Tự động điều chỉnh tọa độ theo kích thước màn hình
        debug_mode = false,             -- Chế độ debug
        take_screenshots = false        -- Chụp ảnh màn hình khi gặp lỗi
    },
    
    -- Cài đặt độ chính xác (đơn vị: %)
    accuracy = {
        color_similarity = 90,     -- Độ tương đồng màu sắc
        image_similarity = 85      -- Độ tương đồng hình ảnh
    },
    
    -- Ma trận màu kiểm tra các phần tử
    -- Tất cả các ma trận màu đều được nhóm trong một bảng riêng
    color_patterns = {
        -- Ma trận màu kiểm tra TikTok đã load xong
        tiktok_loaded = {
            {203, 1303, 0xbbbbbb},
            {204, 1307, 0xc0c0c0},
            {204, 1310, 0xc0c0c0},
            {205, 1300, 0xb9b9b9},
            {206, 1305, 0xbfbfbf},
            {375, 1303, 0xff0050},
            {375, 1307, 0xff0050},
            {376, 1303, 0xff0050},
            {376, 1307, 0xff0050},
            {545, 1303, 0xc2c2c2},
            {545, 1307, 0xc2c2c2}
        },
        
        -- Ma trận màu kiểm tra nút xem live
        live_button = {
            {48, 61, 0xf0f0f0},
            {49, 62, 0xffffff},
            {51, 64, 0xffffff},
            {53, 67, 0xffffff},
            {56, 68, 0xffffff},
            {58, 66, 0xffffff},
            {60, 64, 0xffffff},
            {62, 63, 0xffffff},
            {62, 62, 0xffffff},
            {53, 105, 0xffffff}
        },
        
        -- Ma trận màu kiểm tra đã load xong màn hình xem live
        in_live_screen = {
            {588, 1250, 0xff83b4},
            {614, 1250, 0xff94bf},
            {617, 1274, 0xef517b},
            {613, 1286, 0xfdd5e9},
            {601, 1287, 0xff528b},
            {591, 1286, 0xffeaf0},
            {582, 1265, 0xff75b3},
            {602, 1274, 0xf34676}
        },
        
        -- Ma trận màu cho nút phần thưởng (màu 1)
        reward_button_1 = {
            {46, 578, 0xff9e00},
            {80, 581, 0xfe8302},
            {101, 616, 0xff8500},
            {80, 641, 0xff8300},
            {42, 643, 0xffd700},
            {38, 631, 0xff8300}
        },
    
        -- Ma trận màu cho nút phần thưởng (màu 2)
        reward_button_2 = {
            {56, 589, 0xffce00},
            {75, 591, 0xffce00},
            {90, 621, 0xffce00},
            {50, 616, 0xff9300},
            {52, 600, 0xff9300},
            {63, 603, 0xffe865},
            {67, 608, 0xff9300}
        },

        -- Ma trận check xem  đã trong phần thưởng hay chưa
        in_reward_screen = {
            {704, 738, 0xfffdee},
            {704, 737, 0xffeb74},
            {706, 738, 0xfff8d0},
            {708, 738, 0xfff2a6},
            {715, 740, 0xffee8b},
            {715, 742, 0xffffff},
            {723, 745, 0xffed80},
            {726, 751, 0xffffff},
            {730, 751, 0xffeb74},
            {729, 757, 0xffffff}            
        },
    
        -- Ma trận màu cho nút claim
        claim_button = {
            {249, 704, 0xfd0010},
            {247, 702, 0xffffff},
            {240, 699, 0xffffff},
            {233, 709, 0xffffff},
            {241, 718, 0xffffff},
            {247, 714, 0xffffff},
            {248, 710, 0xfd0010},
            {518, 707, 0xfd0010},
            {507, 707, 0xffffff},
            {517, 714, 0xffffff},
            {511, 718, 0xffffff},
            {508, 716, 0xffffff},
            {507, 713, 0xfd0010}
        },

        watch_live_button = {
            {295,697,0xfd2634},
            {296,698,0xffffff},
            {301,718,0xffffff},
            {301,719,0xfd0010},
            {307,697,0xfd2634},
            {314,719,0xfd0010},
            {319,698,0xffffff},
            {319,697,0xfd2634}
        },
    
        -- Ma trận màu cho nút complete
        complete_button = {
            {97, 1215, 0xf1f1f2},
            {187, 1231, 0xf1f1f2},
            {282, 1236, 0xf1f1f2},
            {311, 1224, 0xb0b0b4},
            {311, 1232, 0xd6d6d9},
            {349, 1229, 0xb0b0b4},
            {374, 1230, 0xb0b0b4},
            {393, 1220, 0xeeeeef},
            {423, 1240, 0xb0b0b4},
            {430, 1232, 0xb0b0b4}
        },

        -- Ma trận màu cho nút điểm danh hằng ngày
        daily_check_button = {
            {518, 800, 0xe83128},
            {520, 799, 0xfefafa},
            {534, 797, 0xffffff},
            {536, 795, 0xe83128},
            {527, 797, 0xe83128},
            {523, 815, 0xffffff},
            {520, 816, 0xe83128},
            {659, 799, 0xe83128},
            {659, 802, 0xffffff},
            {643, 815, 0xffffff}
        },
        matrix_check_send_gift = {
            {   71, 1074, 0xffffff},
            {   71, 1073, 0xa6a6a6},
            {   58, 1077, 0x858585},
            {   71, 1082, 0x858585},
            {   71, 1081, 0xf4f4f4},
            {  334, 1072, 0xffffff},
            {  335, 1073, 0xa2a2a2},
            {  338, 1092, 0xe6e6e6},
            {  339, 1091, 0x858585},
            {  345, 1073, 0xa2a2a2},
        },

        maxtrix_send_gift_button = {
            {   86,  938, 0xff2b6c},
            {   86,  937, 0xffffff},
            {   77,  938, 0xffffff},
            {   77,  946, 0xffffff},
            {   77,  945, 0xff3774},
            {  126,  933, 0xff2b6c},
            {  126,  934, 0xffffff},
            {  126,  949, 0xffffff},
            {  126,  950, 0xff004f},
            {  123,  949, 0xff77a1},
        }
    },
    
    -- Vùng tìm kiếm các phần tử
    -- Format: {x1, y1, x2, y2}
    search_regions = {
        live_button = {0, 0, 200, 200},       -- Vùng tìm nút xem live
        tiktok_loaded = {0, 1200, 750, 1350},  -- Vùng tìm thanh điều hướng dưới cùng
        bottom_tabs = {0, 1200, 750, 1350},   -- Vùng tìm các tab dưới cùng
        reward_button = {0, 0, 375, 1350}       -- Vùng tìm nút phần thưởng (nửa màn hình bên trái)
    },
    
    -- Tọa độ các phần tử giao diện
    ui = {
        -- Tabs
        tab_home = {scaleCoord(375, 1270)},    -- Tab For You
        tab_mission = {scaleCoord(219, 1265)}, -- Tab Mission
        tab_me = {scaleCoord(650, 1270)},      -- Tab Profile
        
        -- Buttons
        button_rewards = {scaleCoord(375, 600)}, -- Nút phần thưởng
        button_watch_ads = {scaleCoord(375, 800)}, -- Nút xem quảng cáo
        popup_close = {scaleCoord(400, 1267)}, -- Nút đóng popup Add Friends
        
        -- Swipe để xem video tiếp theo
        swipe = {
            start_x = scaleCoord(375, nil),
            start_y = scaleCoord(nil, 700),
            end_x = scaleCoord(375, nil),
            end_y = scaleCoord(nil, 200),
            duration = 500         -- milliseconds
        }
    },
    
    -- Màu sắc dùng để kiểm tra
    colors = {
        reward_button = 0xFF5050,    -- Màu nút phần thưởng
        available_reward = 0x00AA00, -- Màu khi có phần thưởng khả dụng
        ad_close_button = 0xFFFFFF   -- Màu nút đóng quảng cáo
    },
    
    -- -- Đường dẫn lưu trữ
    -- paths = {
    --     screenshots = "/var/mobile/Media/TouchSprite/screenshots/", -- Đường dẫn định chụp màn hình
    --     logs = "/var/mobile/Media/TouchSprite/logs/",  -- Đường dẫn lưu file log
    --     output = "/var/mobile/Media/TouchSprite/output/" -- Đường dẫn lưu kết quả
    -- },
    
    -- Cài đặt ghi log
    logging = {
        enabled = true,           -- Bật/tắt ghi log
        level = "info",           -- Mức ghi log (debug, info, warn, error)
        save_to_file = true,      -- Lưu log vào file
        show_on_screen = true,    -- Hiển thị log trên màn hình
        log_file_format = "tiktok_lite_%Y%m%d_%H%M%S.log", -- Định dạng tên file log
        rotate_logs = true,       -- Tự động xoay vòng file log
        max_log_files = 10        -- Số file log tối đa lưu trữ
    },

    -- Thêm vào phần cấu hình mới cho ADManager
    -- Cài đặt cho ADManager và chuyển tài khoản
    admanager = {
        bundle_id = "com.tigisoftware.ADManager",  -- Bundle ID của ADManager
        app_list_coord = {scaleCoord(377, 1278)},  -- Tọa độ để bấm vào danh sách app
        restore_button_coord = {scaleCoord(378, 1138)}, -- Tọa độ nút Restore AppData
        backup_numbers = {1, 2, 3, 4, 5},          -- Các số backup mặc định
        max_backup_number = 50,                    -- Số backup tối đa
        account_select_coord = {scaleCoord(356, 478)}, -- Tọa độ để chọn tài khoản
    },

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
}


-- Cập nhật config.timing để thêm các giá trị bị hardcode
config.timing.popup_check_interval = config.timing.popup_check_delay or 0.2  -- Thời gian giữa các lần kiểm tra popup

-- Trả về đối tượng cấu hình
return config
