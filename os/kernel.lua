local kernel = {}

local procs = {}
local nextPid = 1

local registry = {}

local moduleCache = {}

kernel._procs = procs
kernel._registry = registry
kernel._moduleCache = moduleCache

function kernel.boot()
  term.clear(); term.setCursorPos(1, 1)
  term.setTextColor(colors.yellow)
  print("[NekOS] microkernel booting...")
  term.setTextColor(colors.white)

  local loader = require("loader")
  local resolver = require("resolver")
  local caps_mod = require("caps")
  local pkgman = require("pkgman")

  pkgman.init(kernel)
  caps_mod.init(kernel, loader, resolver, pkgman)

  kernel._pkgman = pkgman
  kernel._caps_mod = caps_mod
  kernel._loader = loader

  local bootCaps = { "event", "display", "fs", "network" }
  for _, cap in ipairs(bootCaps) do
    local ok, err = caps_mod._injectCap({}, { pid = -99, name = "_boot", inbox = {}, _callSeq = 0 }, cap)
    if not ok then klog("WARN: boot cap failed: " .. cap .. " / " .. tostring(err)) end
  end

  kernel.spawnApp("shell", "/os/shell.lua", { "event", "display", "fs", "network", "pkgman", "process" })

  kernel._loop()
end

function kernel.spawnApp(name, path, requestedCaps, version, args)
  local caps_mod = kernel._caps_mod
  local loader = kernel._loader

  local pid = nextPid; nextPid = nextPid + 1
  local proc = {
    pid = pid,
    name = name,
    version = version,
    appDir = fs.getDir(path),
    co = nil,
    filter = nil,
    inbox = {},
    dead = false,
    _callSeq = 0,
  }
  procs[pid] = proc

  local env, envErr = caps_mod.buildEnv(proc, requestedCaps)
  if not env then
    klog("ERROR env for " .. name .. ": " .. tostring(envErr))
    procs[pid] = nil
    return nil, envErr
  end

  local publicAPI, callbacks, loadErr = loader.loadModule(path, env)
  if not publicAPI or not callbacks then
    klog("ERROR load " .. name .. ": " .. tostring(loadErr))
    procs[pid] = nil
    return nil, loadErr
  end

  if callbacks.main then
    proc.co = coroutine.create(function()
      callbacks.main(table.unpack(args or {}))
    end)
    klog("spawned [" .. pid .. "] " .. name .. (version and ("@" .. version) or "")
      .. " caps=" .. table.concat(requestedCaps or {}, ","))
    resume(proc)
  else
    klog("loaded (no main) [" .. pid .. "] " .. name)
    procs[pid] = nil
  end

  return pid, publicAPI
end

function kernel.spawnCallback(name, version, mainFn, env)
  local pid = nextPid; nextPid = nextPid + 1
  local proc = {
    pid = pid,
    name = name,
    version = version,
    co = coroutine.create(mainFn),
    filter = nil,
    inbox = {},
    dead = false,
    _callSeq = 0,
  }
  procs[pid] = proc
  klog("spawned service [" .. pid .. "] " .. name .. (version and ("@" .. version) or ""))
  resume(proc)
  return pid
end

function kernel.registerService(name, version, pid)
  local key = name .. "@" .. (version or "")
  registry[key] = pid
  registry[name] = pid
  klog("service: " .. key .. " -> pid " .. pid)
end

function kernel.kill(pid, reason)
  local p = procs[pid]
  if not p then return end

  if p._onUninstall then pcall(p._onUninstall) end

  p.dead = true
  procs[pid] = nil

  for k, v in pairs(registry) do
    if v == pid then registry[k] = nil end
  end

  klog("killed [" .. pid .. "] " .. p.name .. (reason and (" / " .. reason) or ""))
end

function kernel.deliver(fromPid, toPid, msg)
  local p = procs[toPid]
  if not p or p.dead then
    return false, "no such process: " .. tostring(toPid)
  end
  msg._from = fromPid
  table.insert(p.inbox, msg)
  if p.filter == "__ipc" or p.filter == nil then
    resume(p, "__ipc", msg)
  end
  return true
end

function kernel._loop()
  while true do
    local alive = {}
    for pid in pairs(procs) do alive[#alive + 1] = pid end
    if #alive == 0 then
      klog("all processes exited - halting"); break
    end

    local ev = table.pack(os.pullEventRaw())

    if ev[1] == "terminate" then
      klog("terminate received - shutdown")
      break
    end

    if ev[1] ~= "__ipc" then
      for _, pid in ipairs(alive) do
        local p = procs[pid]
        if p and not p.dead then
          if p.filter == nil or p.filter == ev[1] then
            resume(p, table.unpack(ev, 1, ev.n))
          end
        end
      end
    end
  end
end

function resume(proc, ...)
  local ok, val = coroutine.resume(proc.co, ...)
  if not ok then
    klog("CRASH [" .. proc.pid .. "] " .. proc.name .. ": " .. tostring(val))
    proc.dead = true
    procs[proc.pid] = nil
    return
  end
  if coroutine.status(proc.co) == "dead" then
    proc.dead = true
    procs[proc.pid] = nil
    klog("exited [" .. proc.pid .. "] " .. proc.name)
    return
  end
  proc.filter = val
end

function klog(msg)
  local text_color, bg_color = term.getTextColor(), term.getBackgroundColor()
  local cx, cy = term.getCursorPos()
  local _, h = term.getSize()
  term.setCursorPos(1, h)
  term.clearLine()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.gray)
  term.write("[K] " .. tostring(msg))
  term.setTextColor(text_color)
  term.setBackgroundColor(bg_color)
  term.setCursorPos(cx, cy)
end

kernel._klog = klog

kernel.spawn = kernel.spawnApp

return kernel
