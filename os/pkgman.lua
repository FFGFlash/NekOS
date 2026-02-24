local pkgman = {}
local _kernel

local GH_API = "https://api.github.com"
local USER_APPS_DIR = "/apps"
local USER_DATA_DIR = "/data"
local PKG_DB = "/os/packages.json"
local UA = "NekOS/1.0"

function pkgman.db()
  if not fs.exists(PKG_DB) then return {} end
  local h = fs.open(PKG_DB, "r"); local raw = h.readAll(); h.close()
  local ok, db = pcall(textutils.unserialiseJSON, raw)
  return (ok and type(db) == "table") and db or {}
end

local function saveDB(db)
  local h = fs.open(PKG_DB, "w")
  h.write(textutils.serialiseJSON(db)); h.close()
end

local function log(m)
  if _kernel then _kernel._klog("[pm] " .. m) else print("[pm] " .. m) end
end

local function ghGet(url)
  local r = http.get(url, { ["User-Agent"] = UA, ["Accept"] = "application/vnd.github+json" })
  if not r then return nil, "HTTP failed: " .. url end
  local code = r.getResponseCode(); local body = r.readAll(); r.close()
  if code ~= 200 then return nil, "GitHub HTTP " .. code end
  local ok, data = pcall(textutils.unserialiseJSON, body)
  if not ok or type(data) ~= "table" then return nil, "JSON parse error" end
  return data
end

local function download(url)
  local r = http.get(url, { ["User-Agent"] = UA, ["Accept"] = "application/octet-stream" })
  if not r then return nil, "download failed: " .. url end
  local b = r.readAll(); r.close();
  return b
end

local function writeFile(path, data)
  local dir = fs.getDir(path)
  if not fs.exists(dir) then fs.makeDir(dir) end
  local h = fs.open(path, "w")
  if not h then return false, "write failed: " .. path end
  h.write(data); h.close()
  return true
end

local function splitRepo(repo)
  return repo:match("^([^/]+)/(.+)$")
end

function pkgman.readManifest(user, repo, version)
  local path = USER_APPS_DIR .. "/" .. user .. "/" .. repo .. "/" .. version .. "/manifest.json"
  if not fs.exists(path) then return nil end
  local h = fs.open(path, "r"); local raw = h.readAll(); h.close()
  local ok, m = pcall(textutils.unserialiseJSON, raw)
  return (ok and type(m) == "table") and m or nil
end

local function validateManifest(m)
  assert(type(m.name) == "string" and #m.name > 0, "missing 'name'")
  assert(type(m.version) == "string" and #m.version > 0, "missing 'version'")
  assert(type(m.capabilities) == "table", "missing 'capabilities'")

  local resolver = require("resolver")

  if m.minOSVersion then
    assert(resolver.checkOSVersion(m.minOSVersion),
      "requires NekOS >= " .. m.minOSVersion .. " (running " .. resolver.NEKOS_VERSION .. ")")
  end
end

local function hasNative(caps)
  for _, c in ipairs(caps) do if c == "native" then return true end end
  return false
end

function pkgman.install(repo, tag)
  local user, repoName = splitRepo(repo)
  if not user then return false, "invalid repo: " .. tostring(repo) end

  local apiURL = tag
      and (GH_API .. "/repos/" .. repo .. "/releases/tags/" .. tag)
      or (GH_API .. "/repos/" .. repo .. "/releases/latest")

  log("fetch " .. repo .. (tag and ("@" .. tag) or " (latest)"))
  local release, err = ghGet(apiURL)
  if not release then return false, err end

  local mAsset
  for _, a in ipairs(release.assets or {}) do
    if a.name == "manifest.json" then
      mAsset = a; break
    end
  end
  if not mAsset then return false, "release missing manifest.json" end

  local mRaw, mErr = download(mAsset.browser_download_url)
  if not mRaw then return false, mErr end

  local ok, manifest = pcall(textutils.unserialiseJSON, mRaw)
  if not ok or type(manifest) ~= "table" then return false, "bad manifest.json" end

  local vOk, vErr = pcall(validateManifest, manifest)
  if not vOk then return false, "invalid manifest: " .. vErr end

  local version = manifest.version
  local db = pkgman.db()

  if db[repo] and db[repo][version] then
    return false, repo .. "@" .. version .. " already installed"
  end

  if hasNative(manifest.capabilities) then
    log("WARN: " .. repo .. "@" .. version .. " requests 'native' (full CC API access)")
  end

  local appDir = USER_APPS_DIR .. "/" .. user .. "/" .. repoName .. "/" .. version
  if not fs.exists(appDir) then fs.makeDir(appDir) end

  log("installing " .. repo .. "@" .. version)
  for _, asset in ipairs(release.assets or {}) do
    if asset.name:match("%.lua$") or asset.name == "manifest.json" then
      log("  down " .. asset.name)
      local data, dlErr = download(asset.browser_download_url)
      if not data then return false, "download " .. asset.name .. ": " .. dlErr end
      local w, wErr = writeFile(appDir .. "/" .. asset.name, data)
      if not w then return false, wErr end
    end
  end

  local dataDir = USER_DATA_DIR .. "/" .. user .. "/" .. repoName .. "/" .. version
  if not fs.exists(dataDir) then fs.makeDir(dataDir) end

  db[repo] = db[repo] or {}
  db[repo][version] = {
    name = manifest.name,
    entrypoint = manifest.entrypoint or "main.lua",
    capabilities = manifest.capabilities,
    installedAt = os.epoch("utc"),
    releaseTag = release.tag_name,
    hasNative = hasNative(manifest.capabilities),
    minOSVersion = manifest.minOSVersion,
  }
  saveDB(db)
  log("installed " .. repo .. "@" .. version .. " done")
  return true
end

function pkgman.remove(repo, version)
  local user, repoName = splitRepo(repo)
  if not user then return false, "invalid repo: " .. tostring(repo) end

  local db = pkgman.db()
  if not db[repo] then return false, repo .. " not installed" end

  if version then
    if not db[repo][version] then
      return false, repo .. "@" .. version .. " not installed"
    end
    local dir = USER_APPS_DIR .. "/" .. user .. "/" .. repoName .. "/" .. version
    if fs.exists(dir) then fs.delete(dir) end
    db[repo][version] = nil
    if not next(db[repo]) then db[repo] = nil end
  else
    local dir = USER_APPS_DIR .. "/" .. user .. "/" .. repoName
    if fs.exists(dir) then fs.delete(dir) end
    db[repo] = nil
  end

  saveDB(db)
  log("removed " .. repo .. (version and ("@" .. version) or " (all versions)"))
  return true
end

function pkgman.update(repo, targetVersion)
  local db = pkgman.db()
  if not db[repo] then return false, repo .. " not installed" end
  return pkgman.install(repo, targetVersion)
end

function pkgman.list()
  local db  = pkgman.db()
  local out = {}
  for repo, versions in pairs(db) do
    for version, entry in pairs(versions) do
      out[#out + 1] = {
        repo         = repo,
        name         = entry.name,
        version      = version,
        entrypoint   = entry.entrypoint,
        capabilities = entry.capabilities,
        hasNative    = entry.hasNative,
      }
    end
  end
  table.sort(out, function(a, b)
    if a.repo ~= b.repo then return a.repo < b.repo end
    return a.version < b.version
  end)
  return out
end

function pkgman.info(repo, version)
  local db = pkgman.db()
  if not db[repo] then return nil end
  if version then return db[repo][version] end
  return db[repo]
end

function pkgman.launch(repo, version, args)
  local user, repoName = splitRepo(repo)
  if not user then return false, "invalid repo: " .. tostring(repo) end

  local db = pkgman.db()
  if not db[repo] then return false, repo .. " not installed" end

  -- Resolve to best version if not pinned
  if not version then
    local resolver = require("resolver")
    version = resolver.bestInstalledVersion(user, repoName)
  end
  if not version then return false, "no installed version of " .. repo end

  local entry = db[repo][version]
  if not entry then return false, repo .. "@" .. version .. " not installed" end

  local path = USER_APPS_DIR .. "/" .. user .. "/" .. repoName
      .. "/" .. version .. "/" .. entry.entrypoint
  if not fs.exists(path) then return false, "entry point not found: " .. path end

  local pid, err = _kernel.spawn(
    entry.name or repo, path, entry.capabilities, version, args
  )
  return pid ~= nil, pid or err
end

function pkgman.checkUpdate(repo)
  local db = pkgman.db()
  if not db[repo] then return nil, repo .. " not installed" end

  local rel, err = ghGet(GH_API .. "/repos/" .. repo .. "/releases/latest")
  if not rel then return nil, err end

  if not db[repo][rel.tag_name] then
    return rel.tag_name
  end
  return nil
end

function pkgman.init(kernel)
  _kernel = kernel
  for _, d in ipairs({ USER_APPS_DIR, USER_DATA_DIR, "/os", "/lib" }) do
    if not fs.exists(d) then fs.makeDir(d) end
  end
end

return pkgman
