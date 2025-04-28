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

-- Function to extract file names from GitHub HTML page
local function extractFilesFromGitHubHTML(folderPath)
    local files = {}
    local githubUrl = "https://github.com/" .. repoOwner .. "/" .. repoName .. "/tree/" .. branch .. "/" .. folderPath
    local tempFile = os.tmpname() or "/tmp/github_page.html"
    
    nLog("Fetching file list from: " .. githubUrl)
    
    -- Download the GitHub page
    local code, msg = ts.tsDownload(tempFile, githubUrl)
    if code ~= 200 then
        nLog("Failed to download GitHub page: " .. msg)
        return files
    end
    
    -- Read the HTML content
    local f = io.open(tempFile, "r")
    if not f then
        nLog("Failed to open downloaded HTML file")
        return files
    end
    
    local content = f:read("*all")
    f:close()
    os.remove(tempFile)
    
    -- Pattern to match file entries in GitHub HTML
    local pattern = folderPath .. "/([^\"]+)%.lua"
    
    -- Extract all matches
    for fileName in string.gmatch(content, pattern) do
        if fileName ~= "" and not string.match(fileName, "/") then
            files[#files + 1] = fileName .. ".lua"
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

-- Process directory using automatic file listing
local function processDirectory(sourceDir, targetDir)
    nLog("Processing directory: " .. sourceDir)
    
    -- Get files from GitHub HTML page
    local files = extractFilesFromGitHubHTML(sourceDir)
    
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