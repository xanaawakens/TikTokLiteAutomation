--[[
  error_handler.lua - Module xử lý lỗi cho ứng dụng TikTok Lite Automation
  
  Module này cung cấp các chức năng:
  - Định nghĩa các mã lỗi chuẩn
  - Hàm chuẩn hóa format lỗi
  - Hàm ghi nhật ký lỗi
  - Xử lý lỗi tập trung
]]

local logger = require("logger")
local errorHandler = {}

-- Các nhóm mã lỗi
errorHandler.ERROR_GROUP = {
    GENERAL = "GENERAL",      -- Lỗi chung
    FILE = "FILE",            -- Lỗi liên quan đến file
    NETWORK = "NETWORK",      -- Lỗi liên quan đến mạng
    UI = "UI",                -- Lỗi liên quan đến giao diện người dùng
    APP = "APP",              -- Lỗi liên quan đến ứng dụng
    ACCOUNT = "ACCOUNT",      -- Lỗi liên quan đến tài khoản
    CONFIG = "CONFIG",        -- Lỗi liên quan đến cấu hình
    PERMISSION = "PERMISSION" -- Lỗi liên quan đến quyền
}

-- Các mã lỗi chi tiết theo nhóm
errorHandler.ERROR_CODE = {
    -- Lỗi chung
    [errorHandler.ERROR_GROUP.GENERAL] = {
        UNKNOWN = "UNKNOWN_ERROR",
        INVALID_PARAM = "INVALID_PARAMETER",
        TIMEOUT = "TIMEOUT",
        NOT_IMPLEMENTED = "NOT_IMPLEMENTED",
        RUNTIME = "RUNTIME_ERROR",
        MEMORY = "MEMORY_ERROR"
    },
    
    -- Lỗi liên quan đến file
    [errorHandler.ERROR_GROUP.FILE] = {
        NOT_FOUND = "FILE_NOT_FOUND",
        CANNOT_READ = "CANNOT_READ_FILE",
        CANNOT_WRITE = "CANNOT_WRITE_FILE",
        INVALID_FORMAT = "INVALID_FILE_FORMAT",
        ACCESS_DENIED = "FILE_ACCESS_DENIED",
        ALREADY_EXISTS = "FILE_ALREADY_EXISTS"
    },
    
    -- Lỗi liên quan đến mạng
    [errorHandler.ERROR_GROUP.NETWORK] = {
        DISCONNECTED = "NETWORK_DISCONNECTED",
        TIMEOUT = "NETWORK_TIMEOUT",
        REQUEST_FAILED = "REQUEST_FAILED",
        INVALID_RESPONSE = "INVALID_RESPONSE"
    },
    
    -- Lỗi liên quan đến giao diện người dùng
    [errorHandler.ERROR_GROUP.UI] = {
        ELEMENT_NOT_FOUND = "UI_ELEMENT_NOT_FOUND",
        PATTERN_NOT_FOUND = "UI_PATTERN_NOT_FOUND",
        TAP_FAILED = "TAP_FAILED",
        SWIPE_FAILED = "SWIPE_FAILED",
        SCREEN_MISMATCH = "SCREEN_MISMATCH"
    },
    
    -- Lỗi liên quan đến ứng dụng
    [errorHandler.ERROR_GROUP.APP] = {
        NOT_INSTALLED = "APP_NOT_INSTALLED",
        LAUNCH_FAILED = "APP_LAUNCH_FAILED",
        NOT_RESPONDING = "APP_NOT_RESPONDING",
        CRASHED = "APP_CRASHED",
        VERSION_MISMATCH = "APP_VERSION_MISMATCH"
    },
    
    -- Lỗi liên quan đến tài khoản
    [errorHandler.ERROR_GROUP.ACCOUNT] = {
        NOT_FOUND = "ACCOUNT_NOT_FOUND",
        AUTH_FAILED = "AUTHENTICATION_FAILED",
        INVALID = "INVALID_ACCOUNT",
        LOCKED = "ACCOUNT_LOCKED",
        LIMIT_REACHED = "ACCOUNT_LIMIT_REACHED",
        SWITCH_FAILED = "ACCOUNT_SWITCH_FAILED"
    },
    
    -- Lỗi liên quan đến cấu hình
    [errorHandler.ERROR_GROUP.CONFIG] = {
        INVALID = "INVALID_CONFIG",
        MISSING = "MISSING_CONFIG",
        PARSE_ERROR = "CONFIG_PARSE_ERROR"
    },
    
    -- Lỗi liên quan đến quyền
    [errorHandler.ERROR_GROUP.PERMISSION] = {
        DENIED = "PERMISSION_DENIED",
        INSUFFICIENT = "INSUFFICIENT_PERMISSION"
    }
}

-- Cache để tìm kiếm nhanh mã lỗi
local errorCodeLookup = {}

-- Khởi tạo cache tìm kiếm mã lỗi
local function initErrorCodeLookup()
    for group, codes in pairs(errorHandler.ERROR_CODE) do
        for name, code in pairs(codes) do
            errorCodeLookup[code] = {group = group, name = name}
        end
    end
end

-- Tạo đối tượng lỗi chuẩn
function errorHandler.createError(code, message, details)
    if not errorCodeLookup[code] then
        -- Sử dụng mã lỗi không xác định nếu mã lỗi không hợp lệ
        code = errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.GENERAL].UNKNOWN
    end
    
    local errorInfo = errorCodeLookup[code]
    
    return {
        code = code,
        group = errorInfo.group,
        name = errorInfo.name,
        message = message or "Không có thông tin lỗi",
        details = details,
        timestamp = os.time()
    }
end

-- Tạo thông báo lỗi đầy đủ từ đối tượng lỗi
function errorHandler.formatError(err)
    if type(err) == "string" then
        -- Nếu chỉ là chuỗi, tạo đối tượng lỗi
        err = errorHandler.createError(
            errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.GENERAL].UNKNOWN,
            err
        )
    elseif type(err) ~= "table" or not err.code then
        -- Nếu không phải đối tượng lỗi
        err = errorHandler.createError(
            errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.GENERAL].UNKNOWN,
            tostring(err)
        )
    end
    
    local result = "[" .. err.code .. "] " .. err.message
    
    if err.details then
        if type(err.details) == "string" then
            result = result .. "\nChi tiết: " .. err.details
        elseif type(err.details) == "table" then
            result = result .. "\nChi tiết:\n"
            for k, v in pairs(err.details) do
                result = result .. "  - " .. tostring(k) .. ": " .. tostring(v) .. "\n"
            end
        end
    end
    
    return result
end

-- Ghi nhật ký lỗi
function errorHandler.logError(err, moduleName, suppress)
    if type(err) == "string" then
        -- Tạo đối tượng lỗi nếu chỉ là chuỗi
        err = errorHandler.createError(
            errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.GENERAL].UNKNOWN, 
            err
        )
    end
    
    local errorMsg = errorHandler.formatError(err)
    
    if moduleName then
        errorMsg = "[" .. moduleName .. "] " .. errorMsg
    end
    
    logger.error(errorMsg, suppress)
    
    return errorMsg
end

-- Xử lý lỗi với callback
function errorHandler.handleError(err, callback, moduleName, suppress)
    local errorMsg = errorHandler.logError(err, moduleName, suppress)
    
    if callback and type(callback) == "function" then
        pcall(callback, err, errorMsg)
    end
    
    return errorMsg
end

-- Kiểm tra và xử lý lỗi từ kết quả trả về
function errorHandler.checkResult(success, result, errorData, moduleName, suppress)
    if not success then
        local errObj
        
        if type(errorData) == "string" then
            -- Tạo đối tượng lỗi từ chuỗi
            errObj = errorHandler.createError(
                errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.GENERAL].UNKNOWN,
                errorData
            )
        elseif type(errorData) == "table" and errorData.code then
            -- Đã là đối tượng lỗi
            errObj = errorData
        else
            -- Tạo lỗi mặc định
            errObj = errorHandler.createError(
                errorHandler.ERROR_CODE[errorHandler.ERROR_GROUP.GENERAL].UNKNOWN,
                "Lỗi không xác định"
            )
        end
        
        return errorHandler.logError(errObj, moduleName, suppress)
    end
    
    return nil
end

-- Khởi tạo module
function errorHandler.init()
    initErrorCodeLookup()
    logger.info("Đã khởi tạo error_handler")
    return true
end

-- Khởi tạo khi load module
errorHandler.init()

return errorHandler 