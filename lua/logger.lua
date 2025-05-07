--[[
  logger.lua - Module quản lý log cho ứng dụng TikTok Lite Automation
  
  Module này cung cấp các chức năng:
  - Ghi log với nhiều cấp độ (debug, info, warning, error)
  - Hiển thị thông báo trên màn hình (toast)
  - Ghi log vào file
  - Bật/tắt logging dựa trên cấu hình
]]

local config = require("config")
-- Tạm thời bỏ dùng utils để tránh circular dependency
-- local utils = require("utils")  -- Thêm utils để sử dụng safeToString

local logger = {}

-- Thêm hàm safeToString đơn giản trong logger để tránh phụ thuộc vào utils
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

-- Các cấp độ log
logger.LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
    NONE = 5
}

-- Ánh xạ từ tên cấp độ sang giá trị số
local LEVEL_MAP = {
    debug = logger.LEVEL.DEBUG,
    info = logger.LEVEL.INFO,
    warning = logger.LEVEL.WARNING,
    error = logger.LEVEL.ERROR,
    none = logger.LEVEL.NONE
}

-- Thiết lập mặc định
local settings = {
    enabled = true,
    level = logger.LEVEL.INFO,
    showOnScreen = true,
    saveToFile = true,
    logFile = nil,
    logFilePath = "/private/var/mobile/Media/TouchSprite/logs/",
    logFileName = "tiktok_lite_%Y%m%d.log",
    timeFormat = "%Y-%m-%d %H:%M:%S"
}

-- Khởi tạo logger
function logger.init(options)
    -- Áp dụng cấu hình từ config.lua nếu có
    if config and config.logging then
        settings.enabled = config.logging.enabled or settings.enabled
        settings.level = LEVEL_MAP[config.logging.level or "info"] or settings.level
        settings.showOnScreen = config.logging.show_on_screen or settings.showOnScreen
        settings.saveToFile = config.logging.save_to_file or settings.saveToFile
        settings.logFilePath = config.paths and config.paths.logs or settings.logFilePath
        settings.logFileName = config.logging.log_file_format or settings.logFileName
        settings.timeFormat = config.logging.time_format or settings.timeFormat
    end
    
    -- Áp dụng cấu hình từ options nếu có
    if options then
        for k, v in pairs(options) do
            settings[k] = v
        end
    end
    
    -- Đảm bảo thư mục logs tồn tại
    if settings.saveToFile then
        os.execute("mkdir -p '"..settings.logFilePath.."'")
        
        -- Tạo tên file log
        local fileName = os.date(settings.logFileName)
        local logFilePath = settings.logFilePath .. fileName
        
        -- Mở file log
        settings.logFile = io.open(logFilePath, "a")
        
        if not settings.logFile then
            settings.saveToFile = false
            logger._log(logger.LEVEL.ERROR, "Không thể mở file log: " .. logFilePath)
        else
            logger._log(logger.LEVEL.INFO, "Đã mở file log: " .. logFilePath)
        end
    end
    
    return logger
end

-- Hàm ghi log nội bộ 
function logger._log(level, message, suppress)
    -- Skip logging completely if suppress is true
    if suppress then
        return
    end
    
    if not settings.enabled or level < settings.level then
        return
    end
    
    -- Tạo thời gian hiện tại 
    local timestamp = os.date(settings.timeFormat)
    
    -- Xác định chuỗi cấp độ
    local levelStr = "INFO"
    if level == logger.LEVEL.DEBUG then levelStr = "DEBUG"
    elseif level == logger.LEVEL.WARNING then levelStr = "WARNING"
    elseif level == logger.LEVEL.ERROR then levelStr = "ERROR"
    end
    
    -- Đảm bảo message là chuỗi an toàn - sử dụng hàm local safeToString thay vì utils.safeToString
    local safeMessage = safeToString(message)
    
    -- Tạo chuỗi log
    local logString = string.format("[%s] [%s] %s", timestamp, levelStr, safeMessage)
    
    -- Ghi vào console bằng nLog nếu có
    if type(nLog) == "function" then
        nLog(logString)
    end
    
    -- Hiển thị trên màn hình nếu cần
    if settings.showOnScreen and level >= logger.LEVEL.INFO then
        -- Giới hạn tin nhắn hiển thị 
        local displayMsg = safeMessage
        if #displayMsg > 60 then
            displayMsg = string.sub(displayMsg, 1, 57) .. "..."
        end
        
        -- Hiển thị toast
        if type(toast) == "function" then
            toast(displayMsg)
        end
    end
    
    -- Ghi vào file nếu được cấu hình
    if settings.saveToFile and settings.logFile then
        settings.logFile:write(logString .. "\n")
        settings.logFile:flush() -- Đảm bảo ghi ngay lập tức, tránh mất log khi crash
    end
end

-- Các hàm ghi log theo cấp độ
function logger.debug(message, suppress)
    logger._log(logger.LEVEL.DEBUG, message, suppress)
end

function logger.info(message, suppress)
    logger._log(logger.LEVEL.INFO, message, suppress)
end

function logger.warning(message, suppress)
    logger._log(logger.LEVEL.WARNING, message, suppress)
end

function logger.error(message, suppress)
    logger._log(logger.LEVEL.ERROR, message, suppress)
end

-- Đóng logger khi kết thúc
function logger.close()
    if settings.logFile then
        settings.logFile:close()
        settings.logFile = nil
    end
end

-- Thiết lập cấp độ log
function logger.setLevel(level)
    if type(level) == "string" then
        level = LEVEL_MAP[level:lower()] or settings.level
    end
    settings.level = level
end

-- Bật/tắt ghi log
function logger.setEnabled(enabled)
    settings.enabled = enabled == true
end

-- Bật/tắt hiển thị trên màn hình
function logger.setShowOnScreen(show)
    settings.showOnScreen = show == true
end

-- Hàm trợ giúp thay thế toast
function logger.toast(message, suppress)
    logger.info(message, suppress)
end

-- Tự động khởi tạo logger với cấu hình mặc định
logger.init()

return logger 