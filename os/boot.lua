assert(http, "NekOS requires http enabled in ComputerCraft config")

local BASE = "/os"
local _loaded = {}

function require(mod)
  if _loaded[mod] then return _loaded[mod] end
  local paths = { BASE .. "/" .. mod .. ".lua", "/lib/" .. mod .. ".lua" }
  for _, p in ipairs(paths) do
    if fs.exists(p) then
      local fn = assert(loadfile(p))
      local r = fn()
      _loaded[mod] = r ~= nil and r or true
      return _loaded[mod]
    end
  end
  error("module not found: " .. mod, 2)
end

local function ensureDirs()
  for _, d in ipairs({ "/os/apps", "/apps", "/data", "/lib" }) do
    if not fs.exists(d) then fs.makeDir(d) end
  end
end

ensureDirs()

local kernel = require("kernel")
_loaded["kernel"] = kernel
kernel.boot()
