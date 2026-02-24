local resolver = {}

local SYS_APPS_DIR = "/os/apps"
local USER_APPS_DIR = "/apps"
local NEKOS_VERSION = "1.0.0"

function resolver.parse(cap)
  local user, repo, version = cap:match("^([^/@]+)/([^/@]+)@(.+)$")
  if user then
    return { system = false, user = user, repo = repo, version = version }
  end
  user, repo = cap:match("^([^/@]+)/([^/@]+)$")
  if user then
    return { system = false, user = user, repo = repo, version = nil }
  end
  return { system = true, name = cap }
end

function resolver.bestInstalledVersion(user, repo, wantVersion)
  local dir = USER_APPS_DIR .. "/" .. user .. "/" .. repo
  if not fs.exists(dir) or not fs.isDir(dir) then return nil end

  local versions = fs.list(dir)
  if #versions == 0 then return nil end

  if wantVersion then
    for _, v in ipairs(versions) do
      if v == wantVersion then return v end
    end
    return nil
  end

  table.sort(versions, resolver._semverGt)
  return versions[1]
end

function resolver.resolve(cap, pkgman)
  local parsed = resolver.parse(cap)

  if parsed.system then
    local path = SYS_APPS_DIR .. "/" .. parsed.name
    if not fs.exists(path) then
      return nil, "system capability not found: " .. parsed.name
    end
    return {
      name = parsed.name,
      user = nil,
      repo = nil,
      version = nil,
      path = path,
      isSystem = true,
    }
  end

  local user = parsed.user
  local repo = parsed.repo

  local version = resolver.bestInstalledVersion(user, repo, parsed.version)
  if not version then
    local ok, err = pkgman.install(user .. "/" .. repo, parsed.version)
    if not ok then
      return nil, "auto-install failed for " .. cap .. ": " .. tostring(err)
    end
    version = resolver.bestInstalledVersion(user, repo, parsed.version)
    if not version then
      return nil, "installed " .. cap .. " but no version directory found"
    end
  end

  local path = USER_APPS_DIR .. "/" .. user .. "/" .. repo .. "/" .. version

  local manifest = pkgman.readManifest(user, repo, version)
  local name = manifest and manifest.name or (user .. "/" .. repo)

  return {
    name = name,
    user = user,
    repo = repo,
    version = version,
    path = path,
    isSystem = false,
  }
end

function resolver.checkOSVersion(minVersion)
  if not minVersion then return true end
  return resolver._semverGte(NEKOS_VERSION, minVersion)
end

local function parseSemver(s)
  local ma, mi, pa = s:match("^v?(%d+)%.?(%d*)%.?(%d*)$")
  return tonumber(ma) or 0, tonumber(mi) or 0, tonumber(pa) or 0
end

function resolver._semverE(a, b)
  local ama, ami, apa = parseSemver(a)
  local bma, bmi, bpa = parseSemver(b)
  return ama == bma and ami == bmi and apa == bpa
end

function resolver._semverGt(a, b)
  local ama, ami, apa = parseSemver(a)
  local bma, bmi, bpa = parseSemver(b)
  if ama ~= bma then return ama > bma end
  if ami ~= bmi then return ami > bmi end
  return apa > bpa
end

function resolver._semverGte(a, b)
  local ama, ami, apa = parseSemver(a)
  local bma, bmi, bpa = parseSemver(b)
  if ama ~= bma then return ama > bma end
  if ami ~= bmi then return ami > bmi end
  if apa ~= bpa then return apa > bpa end
  return true
end

function resolver._semverLt(a, b)
  local ama, ami, apa = parseSemver(a)
  local bma, bmi, bpa = parseSemver(b)
  if ama ~= bma then return ama < bma end
  if ami ~= bmi then return ami < bmi end
  return apa < bpa
end

function resolver._semverLte(a, b)
  local ama, ami, apa = parseSemver(a)
  local bma, bmi, bpa = parseSemver(b)
  if ama ~= bma then return ama < bma end
  if ami ~= bmi then return ami < bmi end
  if apa ~= bpa then return apa < bpa end
  return true
end

resolver.NEKOS_VERSION = NEKOS_VERSION

return resolver
