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
]]

local config = {
    -- Thông tin ứng dụng
    app = {
        bundle_id = "com.ss.iphone.ugc.tiktok.lite",  -- Bundle ID của TikTok Lite
        name = "TikTok Lite",                         -- Tên hiển thị
        version = "1.0.0"                             -- Phiên bản kịch bản
    },
    
    -- Cài đặt thời gian (đơn vị: giây)
    timing = {
        launch_wait = 6,           -- Thời gian chờ sau khi mở app
        check_timeout = 10,        -- Thời gian tối đa để kiểm tra app đã mở
        tap_delay = 0.5,           -- Độ trễ sau mỗi lần tap
        swipe_delay = 1,           -- Độ trễ sau mỗi lần vuốt
        video_watch_time = 15,     -- Thời gian xem mỗi video
        reward_check_interval = 60 -- Thời gian giữa các lần kiểm tra phần thưởng
    },
    
    -- Cài đặt độ chính xác (đơn vị: %)
    accuracy = {
        color_similarity = 90,     -- Độ tương đồng màu sắc
        image_similarity = 85      -- Độ tương đồng hình ảnh
    },
    
    -- Ma trận màu để kiểm tra các phần tử
    -- Format: {x, y, color_hex}
    tiktok_matrix = {
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
    
    -- Ma trận màu để kiểm tra nút xem live
    live_matrix = {
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

    -- Ma trận màu để kiểm tra đã load xong màn hình xem live
    in_live_matrix = {
        {588, 1250, 0xff83b4},
        {614, 1250, 0xff94bf},
        {617, 1274, 0xef517b},
        {613, 1286, 0xfdd5e9},
        {601, 1287, 0xff528b},
        {591, 1286, 0xffeaf0},
        {582, 1265, 0xff75b3},
        {602, 1274, 0xf34676}
    },

    reward_button_matrix_1 = {
        {46, 578, 0xff9e00},
        {80, 581, 0xfe8302},
        {101, 616, 0xff8500},
        {80, 641, 0xff8300},
        {42, 643, 0xffd700},
        {38, 631, 0xff8300}
    },

    reward_button_matrix_2 = {
        {56, 589, 0xffce00},
        {75, 591, 0xffce00},
        {90, 621, 0xffce00},
        {50, 616, 0xff9300},
        {52, 600, 0xff9300},
        {63, 603, 0xffe865},
        {67, 608, 0xff9300}
    },

    claim_button_matrix = {
        {249, 704, 0xfd0010}, {247, 702, 0xffffff}, {240, 699, 0xffffff},
        {233, 709, 0xffffff}, {241, 718, 0xffffff}, {247, 714, 0xffffff},
        {248, 710, 0xfd0010}, {518, 707, 0xfd0010}, {507, 707, 0xffffff},
        {517, 714, 0xffffff}, {511, 718, 0xffffff}, {508, 716, 0xffffff},
        {507, 713, 0xfd0010}
    },

    complete_button_matrix = {
        {97, 1215, 0xf1f1f2}, {187, 1231, 0xf1f1f2}, {282, 1236, 0xf1f1f2},
        {311, 1224, 0xb0b0b4}, {311, 1232, 0xd6d6d9}, {349, 1229, 0xb0b0b4},
        {374, 1230, 0xb0b0b4}, {393, 1220, 0xeeeeef}, {423, 1240, 0xb0b0b4},
        {430, 1232, 0xb0b0b4}
    },
    
    
    -- Vùng tìm kiếm các phần tử
    -- Format: {x1, y1, x2, y2}
    search_regions = {
        live_button = {0, 0, 200, 200},       -- Vùng tìm nút xem live
        tiktok_loaded = {0, 1200, 750, 1350},  -- Vùng tìm thanh điều hướng dưới cùng
        reward_button = {0, 0, 375, 1350}       -- Vùng tìm nút phần thưởng (nửa màn hình bên trái)
    },
    
    -- Tọa độ các phần tử giao diện
    ui = {
        -- Tabs
        tab_home = {375, 1270},    -- Tab For You
        tab_discover = {500, 1270}, -- Tab Discover
        tab_me = {650, 1270},      -- Tab Profile
        
        -- Buttons
        button_rewards = {375, 600}, -- Nút phần thưởng
        button_watch_ads = {375, 800}, -- Nút xem quảng cáo
        
        -- Swipe để xem video tiếp theo
        swipe = {
            start_x = 375,
            start_y = 700,
            end_x = 375,
            end_y = 200,
            duration = 500         -- milliseconds
        }
    },
    
    -- Màu sắc dùng để kiểm tra
    colors = {
        reward_button = 0xFF5050,    -- Màu nút phần thưởng
        available_reward = 0x00AA00, -- Màu khi có phần thưởng khả dụng
        ad_close_button = 0xFFFFFF   -- Màu nút đóng quảng cáo
    },
    
    -- Đường dẫn lưu trữ
    paths = {
        screenshots = "/var/mobile/Media/TouchSprite/screenshots/", -- Đường dẫn ảnh chụp màn hình
        logs = "/var/mobile/Media/TouchSprite/logs/"  -- Đường dẫn lưu file log
    },
    
    -- Cài đặt ghi log
    logging = {
        enabled = true,           -- Bật/tắt ghi log
        level = "info",           -- Mức độ ghi log (debug, info, warn, error)
        save_to_file = true,      -- Lưu log vào file
        show_on_screen = true     -- Hiển thị log trên màn hình
    },

    -- Thêm vào phần cấu hình mới cho ADManager
    -- Cài đặt cho ADManager và chuyển tài khoản
    admanager = {
        bundle_id = "com.tigisoftware.ADManager",  -- Bundle ID của ADManager
        app_list_coord = {377, 1278},              -- Tọa độ để bấm vào danh sách app
        restore_button_coord = {378, 1138},        -- Tọa độ nút Restore AppData
        tiktok_icon = "tiktok_lite_icon.png",      -- Tên file icon TikTok Lite
        backup_numbers = {1, 2, 3, 4, 5},          -- Các số backup mặc định
        max_backup_number = 50                     -- Số backup tối đa
    }
}

-- Trả về đối tượng cấu hình
return config
