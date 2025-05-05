local ts = require("ts")

-- GitHub repository information
local repoOwner = "xanaawakens"
local repoName = "TikTokLiteAutomation"
local branch = "master"

-- Target directories on iPhone
local luaTargetDir = "/private/var/mobile/Media/TouchSprite/lua"
local resTargetDir = "/private/var/mobile/Media/TouchSprite/res"

-- Logging function
local function nLog(text)
    if ts.log then
        ts.log(text)
    else
        print(text)
    end
end

-- Function to create directory
local function makeDirectory(path)
    os.execute("mkdir -p '" .. path .. "'")
end

-- Function to parse JSON response
local function parseJSON(jsonStr)
    -- Basic JSON parser for array of objects
    local result = {}
    local items = {}
    
    -- Strip outer brackets and split by objects
    local content = string.match(jsonStr, "%[(.-)%]")
    if not content then return {} end
    
    -- Split by objects (each starting with '{')
    local pos = 1
    local depth = 0
    local start = nil
    
    while pos <= #content do
        local c = string.sub(content, pos, pos)
        
        if c == '{' then
            if depth == 0 then start = pos end
            depth = depth + 1
        elseif c == '}' then
            depth = depth - 1
            if depth == 0 and start then
                local obj = string.sub(content, start, pos)
                table.insert(items, obj)
                start = nil
            end
        end
        
        pos = pos + 1
    end
    
    -- Extract name and type from each object
    for _, item in ipairs(items) do
        local name = string.match(item, '"name"%s*:%s*"([^"]+)"')
        local type = string.match(item, '"type"%s*:%s*"([^"]+)"')
        local download_url = string.match(item, '"download_url"%s*:%s*"([^"]*)"')
        
        if name and type == "file" then
            table.insert(result, {name = name, download_url = download_url})
        end
    end
    
    return result
end

-- Function to get files from GitHub API
local function getFilesFromGitHubAPI(folderPath)
    local files = {}
    local apiUrl = "https://api.github.com/repos/" .. repoOwner .. "/" .. repoName .. "/contents/" .. folderPath
    
    if branch and branch ~= "master" and branch ~= "main" then
        apiUrl = apiUrl .. "?ref=" .. branch
    end
    
    nLog("Fetching file list from API: " .. apiUrl)
    
    local tempFile = os.tmpname() or "/tmp/github_api.json"
    
    -- Set headers for GitHub API (to avoid rate limits)
    local headers = {
        ["User-Agent"] = "TikTokLiteAutomation-Updater",
        ["Accept"] = "application/vnd.github.v3+json"
    }
    
    -- Download JSON from GitHub API
    local code, msg = ts.tsDownload(tempFile, apiUrl, {["tstab"] = 1, ["mode"] = true, ["headers"] = headers})
    
    if code ~= 200 then
        nLog("Failed to access GitHub API: " .. (msg or "Unknown error") .. " (Code: " .. code .. ")")
        return files
    end
    
    -- Read the JSON content
    local f = io.open(tempFile, "r")
    if not f then
        nLog("Failed to open downloaded JSON file")
        return files
    end
    
    local content = f:read("*all")
    f:close()
    os.remove(tempFile)
    
    -- Parse JSON response
    local items = parseJSON(content)
    
    -- Add all files, regardless of extension
    for _, item in ipairs(items) do
        local fileName = item.name
        
        -- Chỉ thêm các mục có type là file (bỏ qua thư mục)
        if item.name then
            table.insert(files, fileName)
        end
    end
    
    nLog("Found " .. #files .. " files in " .. folderPath)
    for i, file in ipairs(files) do
        nLog("  " .. i .. ". " .. file)
    end
    
    return files
end

-- Function to download a file from GitHub
local function downloadFile(path, targetPath)
    local url = "https://raw.githubusercontent.com/" .. repoOwner .. "/" .. repoName .. "/" .. branch .. "/" .. path

    -- Ensure directory exists
    local dirPath = string.match(targetPath, "(.*)/[^/]*$")
    if dirPath then
        makeDirectory(dirPath)
    end

    -- Download file using tsDownload
    nLog("Downloading: " .. path .. " to " .. targetPath)
    local code, msg = ts.tsDownload(targetPath, url, {["tstab"] = 1, ["mode"] = true})
    if code == 200 then
        nLog("Downloaded: " .. targetPath)
        return true
    else
        nLog("Download failed: " .. targetPath .. " - " .. msg)
        return false
    end
end

-- Process directory using GitHub API file listing
local function processDirectory(sourceDir, targetDir)
    nLog("Processing directory: " .. sourceDir)

    -- Get files from GitHub API
    local files = getFilesFromGitHubAPI(sourceDir)

    if #files == 0 then
        nLog("No files found for directory: " .. sourceDir)
        return 0, 0
    end

    local filesProcessed = 0
    local filesSucceeded = 0

    for _, fileName in ipairs(files) do
        filesProcessed = filesProcessed + 1
        local filePath = sourceDir .. "/" .. fileName
        local targetPath = targetDir .. "/" .. fileName
        if downloadFile(filePath, targetPath) then
            filesSucceeded = filesSucceeded + 1
        end
    end

    return filesProcessed, filesSucceeded
end

-- Main execution
function main()
    nLog("Starting download from GitHub repository: " .. repoOwner .. "/" .. repoName)

    -- Download lua directory
    local luaProcessed, luaSucceeded = processDirectory("lua", luaTargetDir)
    nLog("Lua directory: Downloaded " .. luaSucceeded .. "/" .. luaProcessed .. " files")

    -- Download res directory
    local resProcessed, resSucceeded = processDirectory("res", resTargetDir)
    nLog("Res directory: Downloaded " .. resSucceeded .. "/" .. resProcessed .. " files")
    
    nLog("Download complete")

    dialog("Download complete! Lua: " .. luaSucceeded .. "/" .. luaProcessed .. " files, Res: " .. resSucceeded .. "/" .. resProcessed .. " files", 0)
end

-- Run main function
main() 
