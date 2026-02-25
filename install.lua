local REPO   = "ffgflash/nekos"
local GH_API = "https://api.github.com"
local GH_RAW = "https://raw.githubusercontent.com"
local UA     = "nekos-installer/1.0"

local function log(msg, col)
  local prev = term.getTextColor()
  term.setTextColor(col or colors.white)
  print(msg)
  term.setTextColor(prev)
end

local function ok(msg) log("  [ok] " .. msg, colors.lime) end
local function info(msg) log("  [..] " .. msg, colors.cyan) end
local function warn(msg) log("  [!!] " .. msg, colors.yellow) end
local function fail(msg) log("  [xx] " .. msg, colors.red) end

local function get(url)
  info("GET " .. url)
  local r = http.get(url .. "?ts=" .. os.epoch(), { ["User-Agent"] = UA })
  if not r then return nil, "request failed" end
  local code = r.getResponseCode()
  local body = r.readAll()
  r.close()
  if code ~= 200 then return nil, "HTTP " .. code end
  return body
end

local function getJSON(url)
  local body, err = get(url)
  if not body then return nil, err end
  local ok2, data = pcall(textutils.unserialiseJSON, body)
  if not ok2 or type(data) ~= "table" then return nil, "JSON parse error" end
  return data
end

local function writeFile(path, data)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local h = fs.open(path, "w")
  if not h then return false, "cannot open for write: " .. path end
  h.write(data)
  h.close()
  return true
end

term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.yellow)
print("================================")
print("      nekos installer")
print("================================")
term.setTextColor(colors.white)
print("")

assert(http, "HTTP must be enabled. Set http.enabled=true in ComputerCraft config.")

info("Fetching latest release from " .. REPO .. " …")
local release, err = getJSON(GH_API .. "/repos/" .. REPO .. "/releases/latest")
if not release then
  fail("Could not fetch release info: " .. tostring(err))
  error("Aborting.")
end

local tag = release.tag_name
log("Found release: " .. tag, colors.lime)
print("")

local assetMap = {}
for _, asset in ipairs(release.assets or {}) do
  assetMap[asset.name] = asset.browser_download_url
end

local function installAssets()
  local installed = 0
  local failed    = 0

  for assetName, url in pairs(assetMap) do
    -- Derive destination path from asset name.
    -- Accept any file under os/ subtree.
    local dest
    if assetName:match("^os/") then
      dest = "/" .. assetName
    else
      -- Top-level files (e.g. startup.lua)
      dest = "/" .. assetName
    end

    local body, dlErr = get(url)
    if not body then
      warn("Failed to download " .. assetName .. ": " .. tostring(dlErr))
      failed = failed + 1
    else
      local w, wErr = writeFile(dest, body)
      if w then
        ok(dest)
        installed = installed + 1
      else
        warn("Failed to write " .. dest .. ": " .. tostring(wErr))
        failed = failed + 1
      end
    end
  end

  return installed, failed
end

local OS_FILES = {
  -- core
  { src = "startup.lua",                   dst = "/startup.lua" },
  { src = "os/boot.lua",                   dst = "/os/boot.lua" },
  { src = "os/kernel.lua",                 dst = "/os/kernel.lua" },
  { src = "os/caps.lua",                   dst = "/os/caps.lua" },
  { src = "os/loader.lua",                 dst = "/os/loader.lua" },
  { src = "os/resolver.lua",               dst = "/os/resolver.lua" },
  { src = "os/pkgman.lua",                 dst = "/os/pkgman.lua" },
  { src = "os/shell.lua",                  dst = "/os/shell.lua" },
  -- system apps
  { src = "os/apps/event/main.lua",        dst = "/os/apps/event/main.lua" },
  { src = "os/apps/event/manifest.json",   dst = "/os/apps/event/manifest.json" },
  { src = "os/apps/display/main.lua",      dst = "/os/apps/display/main.lua" },
  { src = "os/apps/display/manifest.json", dst = "/os/apps/display/manifest.json" },
  { src = "os/apps/fs/main.lua",           dst = "/os/apps/fs/main.lua" },
  { src = "os/apps/fs/manifest.json",      dst = "/os/apps/fs/manifest.json" },
  { src = "os/apps/network/main.lua",      dst = "/os/apps/network/main.lua" },
  { src = "os/apps/network/manifest.json", dst = "/os/apps/network/manifest.json" },
}

local function installFromSource(branch)
  branch          = branch or "main"
  local base      = GH_RAW .. "/" .. REPO .. "/" .. branch
  local installed = 0
  local failed    = 0

  for _, entry in ipairs(OS_FILES) do
    local url         = base .. "/" .. entry.src
    local body, dlErr = get(url)
    if not body then
      warn("Failed " .. entry.src .. ": " .. tostring(dlErr))
      failed = failed + 1
    else
      local w, wErr = writeFile(entry.dst, body)
      if w then
        ok(entry.dst)
        installed = installed + 1
      else
        warn("Write failed " .. entry.dst .. ": " .. tostring(wErr))
        failed = failed + 1
      end
    end
  end

  return installed, failed
end

local installed, failed

if next(assetMap) then
  info("Installing from release assets …")
  print("")
  installed, failed = installAssets()
else
  warn("Release has no assets — falling back to source tree (" .. tag .. ")")
  print("")
  installed, failed = installFromSource(tag)
end

for _, d in ipairs({ "/os", "/os/apps", "/apps", "/data", "/lib" }) do
  if not fs.exists(d) then
    fs.makeDir(d)
    ok("mkdir " .. d)
  end
end

print("")
if failed == 0 then
  log("Installed " .. installed .. " files successfully.", colors.lime)
else
  log("Installed " .. installed .. " files; " .. failed .. " failed.", colors.yellow)
  warn("You may need to re-run the installer or install missing files manually.")
end

print("")
if failed == 0 then
  log("nekos " .. tag .. " is ready.", colors.yellow)
  log("Rebooting in 3 seconds …", colors.gray)
  sleep(3)
  os.reboot()
else
  log("Fix the errors above, then run: os.reboot()", colors.red)
end
