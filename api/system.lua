local System = api(2, {
  {
    type = "choice",
    options = {
      install = {},
      reset = {},
      update = {},
      settings = {
        { type = "choice", options = {
          set = {
            { type = "setting", name = "setting" },
            { name = "value" }
          },
          get = {
            { type = "setting", name = "setting" }
          },
          info = {
            { type = "setting", name = "setting", required = true }
          }
        } }
      }
    }
  }
})

function System:execute(action, ...)
  local args = {...}
  local s, e = false, ""
  if action == "settings" then
    local subaction = table.remove(args, 1)
    if subaction == "get" then
      s, e = self.get(table.unpack(args))
      if s then print(s) end
    elseif subaction == "set" then
      s, e = self.get(table.unpack(args))
      if s then print(s) end
    elseif subaction == "info" then
      s, e = self.info(table.unpack(args))
      if s then
        print(string.format("Type: %s Default: %s Value: %s\n%s", s.type, tostring(s.default), tostring(s.value), s.description))
      end
    end
  elseif action == "install" then
    s, e = self:install()
    if s then print(s) end
  elseif action == "reset" then
    s, e = self:reset()
    if s then print(s) end
  elseif action == "update" then
    s, e = self:update()
    if s then print(s) end
  end
  if not s then
    print(e)
    self:printUsage()
  end
end

function System:constructor()
  self.data = data("/NekOS")

  self.define("nekos.initialized", { description="Determines if the system is initialized.", default=false, type="boolean" })
  self.define("nekos.auto_update", { description="Determines if the system should auto update.", default=true, type="boolean" })

  local s = self.info("lua.autocomplete")
  self.define("lua.autocomplete", { description="[WARNING] NekOS does not support lua autocompletion\n"..s.description, default=false, type=s.type })

  s = self.info("edit.autocomplete")
  self.define("edit.autocomplete", { description="[WARNING] NekOS does not support edit autocompletion\n"..s.description, default=false, type=s.type })

  if not self.get("nekos.initialized") then
    self.set("nekos.initialized", true)
    self.set("lua.autocomplete", false)
    self.set("edit.autocomplete", false)
  end
end

function System:save(path, data)
  return self.data:save(path, data)
end

function System:load(path)
  return self.data:load(path)
end

function System:getManifest()
  return self:load(".manifest")
end

function System:reset()
  self.set("nekos.initialized", false)
  return self:install()
end

function System:install()
  return github:download("FFGFlash", "NekOS", "/")
end

function System:update()
  local manifest = self:getManifest()
  local newManifest = github:getRepo("FFGFlash", "NekOS")
  if manifest.updated_at == newManifest.updated_at then return true end
  return self:install()
end

function System:getPath()
  return string.split(shell.path(), ":")
end

function System:addPath(path, index)
  local p = self:getPath()
  if table.find(p, path) then return false,"Already exists" end
  table.insert(p, index, path)
  return self:setPath(p)
end

function System:setPath(path)
  local t = type(path)
  if t ~= "string" and t ~= "table" then return false,"Invalid type" end
  shell.setPath(t == "string" and path or table.concat(path, ":"))
  return true
end

function System.define(key, options)
  settings.define(key, options)
end

function System.set(key, value)
  if key then
    settings.set(key, value)
  end
  settings.save("/NekOS/.settings")
  return true
end

function System.info(key)
  if not key then return false,"No key provided" end
  return settings.getDetails(key)
end

function System.get(key)
  settings.load("/NekOS/.settings")
  if key then
    return settings.get(key)
  end
  return true
end

System:call(...)
return System
