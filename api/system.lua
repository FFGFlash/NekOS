local System = api(1, {
  {
    type = "choice",
    options = {
      install = {},
      reset = {},
      update = {},
      settings = {
        { type = "choice", options = {
          set = {
            { type = "setting", name = "setting", required = true },
            { name = "value", required = true }
          },
          get = {
            { type = "setting", name = "setting", required = true }
          }
        } }
      }
    }
  }
})

function System:execute(actions, ...)
  local args = {...}
  if action == "settings" then
    local subaction = table.remove(args, 1)
    if subaction == "get" then
      print(self.get(table.unpack(args)))
      return
    elseif subaction == "set" then
      print(self.get(table.unpack(args)))
      return
    end
  elseif action == "install" then
    print(self:install())
    return
  elseif action == "reset" then
    print(self:reset())
    return
  elseif action == "update" then
    print(self:update())
    return
  end
  self:printUsage()
end

function System:constructor()
  self.define("nekos.initialized", { description="Determines if the system is initialized.", default=false, type="boolean" })
  self.define("nekos.auto_update", { description="Determines if the system should auto update.", defaults=true, type="boolean" })
  self.get()
  self.set()
end

function System:reset()
  self.set("nekos.initialized", false)
  self:install()
end

function System:install()
  return github:download("FFGFlash", "NekOS", "/")
end

function System:update()
  
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
end

function System.get(key)
  settings.load("/NekOS/.settings")
  if key then
    return settings.get(key)
  end
end

System:call(...)
return System
