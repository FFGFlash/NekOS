local caps = {}
local _kernel, _loader, _resolver, _pkgman

function caps.init(kernel, loader, resolver, pkgman)
  _kernel = kernel
  _loader = loader
  _resolver = resolver
  _pkgman = pkgman
end

function caps.buildEnv(proc, requestedCaps)
  local env = {}

  for k, v in pairs(_loader.SAFE_GLOBALS) do env[k] = v end

  env.__kernel = caps._buildKernelPrimitives(proc)

  for _, cap in ipairs(requestedCaps or {}) do
    local ok, err = caps._injectCap(env, proc, cap)
    if not ok then
      return nil, "capability error [" .. cap .. "]: " .. tostring(err)
    end
  end

  env.load = function(chunk, chunkName, mode, altEnv)
    if altEnv and altEnv ~= env then
      error("load: foreign environment not permitted", 2)
    end
    return load(chunk, chunkName, mode or "bt", env)
  end

  env.require = caps._makeRequire(env, proc)

  setmetatable(env, {
    __index = function(_, k)
      error("undefined global '" .. tostring(k) .. "' - is it in your capabilities list?", 2)
    end,
    __newindex = function(t, k, v)
      rawset(t, k, v)
    end,
  })

  return env
end

function caps._buildKernelPrimitives(proc)
  local kp = {}

  kp.pid = proc.pid
  kp.name = proc.name

  kp.send = function(toPid, msg)
    assert(type(toPid) == "number", "send: toPid must be a number")
    assert(type(msg) == "table", "send: msg must be a table")
    return _kernel.deliver(proc.pid, toPid, msg)
  end

  kp.call = function(toPid, msg)
    assert(type(toPid) == "number", "send: toPid must be a number")
    assert(type(msg) == "table", "send: msg must be a table")
    local reqId = proc.pid .. "_" .. tostring(proc._callSeq or 0)
    proc._callSeq = (proc._callSeq or 0) + 1
    msg._reqId = reqId
    msg._replyTo = proc.pid
    _kernel.deliver(proc.pid, toPid, msg)
    while true do
      for i, m in ipairs(proc.inbox) do
        if m._isReply and m._reqId == reqId then
          table.remove(proc.inbox, i)
          if m._error then error(m._error, 2) end
          return m._result
        end
      end
      coroutine.yield("__ipc")
    end
  end

  kp.recv = function()
    if #proc.inbox > 0 then return table.remove(proc.inbox, 1) end
    while true do
      coroutine.yield("__ipc")
      if #proc.inbox > 0 then return table.remove(proc.inbox, 1) end
    end
  end

  kp.yield = coroutine.yield

  kp.spawn = function(name, path, childCaps)
    return _kernel.spawn(name, path, childCaps)
  end

  kp.kill = function(pid)
    _kernel.kill(pid, "killed by " .. proc.name)
  end

  kp.services = function()
    local out = {}
    for k, v in pairs(_kernel._registry) do out[k] = v end
    return out
  end

  return kp
end

function caps._injectCap(env, proc, cap)
  if cap == "native" then
    env.native = {
      term = term,
      fs = fs,
      http = http,
      os = os,
      peripheral = peripheral,
      redstone = redstone,
      colors = colors,
      colours = colours,
      keys = keys,
      coroutine = coroutine,
      print = print,
      read = read,
      write = write,
    }
    return true
  end

  if cap == "pkgman" then
    env.pkgman = {
      install = function(r, v) return _pkgman.install(r, v) end,
      remove = function(n, v) return _pkgman.remove(n, v) end,
      update = function(n, v) return _pkgman.update(n, v) end,
      list = function() return _pkgman.list() end,
      info = function(n, v) return _pkgman.info(n, v) end,
      launch = function(n, v, a) return _pkgman.launch(n, v, a) end,
      checkUpdate = function(n) return _pkgman.checkUpdate(n) end,
    }
    return true
  end

  if cap == "process" then
    env.process = {
      list = function()
        local out = {}
        for pid, p in pairs(_kernel._procs) do
          out[#out + 1] = { pid = pid, name = p.name, version = p.version }
        end
        return out
      end,
      spawn = function(name, path, childCaps)
        return _kernel.spawn(name, path, childCaps)
      end,
      kill = function(pid)
        _kernel.kill(pid, "killed by " .. proc.name)
      end,
    }
    return true
  end

  local resolved, err = _resolver.resolve(cap, _pkgman)
  if not resolved then return false, err end

  local cacheKey = resolved.isSystem and resolved.name or
      (resolved.user .. "/" .. resolved.repo .. "@" .. resolved.version)
  local cachedAPI = _kernel._moduleCache[cacheKey]

  if not cachedAPI then
    local manifestPath = resolved.path .. "/manifest.json"
    local manifest
    if fs.exists(manifestPath) then
      local h = fs.open(manifestPath, "r")
      local raw = h.readAll(); h.close()
      local ok, m = pcall(textutils.unserialiseJSON, raw)
      manifest = (ok and type(m) == "table") and m or nil
    end
    if not manifest then
      return false, "cannot read manifest for " .. cacheKey
    end

    local capAPI, loadErr = caps._loadCapabilityModule(resolved, manifest)
    if not capAPI then return false, loadErr end

    _kernel._moduleCache[cacheKey] = capAPI
    cachedAPI = capAPI
  end

  env[resolved.name] = cachedAPI
  return true
end

function caps._loadCapabilityModule(resolved, manifest)
  local entrypoint = manifest.entrypoint or "main.lua"
  local path = resolved.path .. "/" .. entrypoint

  local capProc = {
    pid = -1,
    name = resolved.name,
    version = resolved.version,
    appDir = resolved.path,
    inbox = {},
    _callSeq = 0,
  }

  local capEnv, envErr = caps.buildEnv(capProc, manifest.capabilities or {})
  if not capEnv then return nil, envErr end

  local publicAPI, callbacks, loadErr = _loader.loadModule(path, capEnv)
  if not publicAPI then return nil, loadErr end

  if callbacks.main then
    local bgPid = _kernel.spawnCallback(resolved.name, resolved.version, callbacks.main, capEnv)
    _kernel.registerService(resolved.name, resolved.version, bgPid)
  end

  return publicAPI
end

local requireCache = {}

function caps._makeRequire(env, proc)
  return function(mod)
    local key = (proc.name or "?") .. ":" .. mod
    if requireCache[key] then return requireCache[key] end
    local rel = mod:gsub("%.", "/")
    local appBase = proc.appDir or ""
    local paths = {
      appBase ~= "" and (appBase .. "/" .. rel .. ".lua") or nil,
      "/os/" .. rel .. ".lua",
      "/lib/" .. rel .. ".lua",
    }

    for _, p in ipairs(paths) do
      if p and fs.exists(p) then
        local h = fs.open(p, "r"); local code = h.readAll(); h.close()
        local fn, err = load(code, "@" .. p, "bt", env)
        if not fn then error("require " .. mod .. ": " .. err, 2) end
        local r = fn()
        requireCache[key] = r ~= nil and r or true
        return requireCache[key]
      end
    end
    error("module not found: " .. mod, 2)
  end
end

return caps
