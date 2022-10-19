function Completions.path(text, space)
  return Completions.choice(text, system:getPath(), space)
end

function Completions.startup(text, space)
  return Completions.choice(text, system:getStartup(), space)
end

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
      },
      path = {
        { type = "choice", options = {
          get = {},
          set = {
            { name = "path", required = true }
          },
          add = {
            { name = "path", required = true }
          },
          remove = {
            { type = "path", name = "path", required = true }
          }
        } }
      },
      startup = {
        { type = "choice", options = {
          get = {},
          add = {
            { name = "command", required = true }
          },
          remove = {
            { type = "startup", name = "command", required = true }
          }
        } }
      }
    }
  }
})

function System:execute(args, action, ...)
  local a = {...}
  local s, e = false, "Invalid Action"
  if action == "settings" then
    local subaction = table.remove(a, 1)
    if subaction == "get" then
      s, e = self:get(table.unpack(a))
    elseif subaction == "set" then
      s, e = self:set(table.unpack(a))
    elseif subaction == "info" then
      s, e = self:info(table.unpack(a))
      if s then
        print(string.format("Type: %s Default: %s Value: %s\n%s", s.type, tostring(s.default), tostring(s.value), s.description))
        return
      end
    end
  elseif action == "path" then
    local subaction = table.remove(a, 1)
    if subaction == "get" then
      print(table.concat(self:getPath(), ":"))
      return
    elseif subaction == "set" then
      s, e = self:setPath(table.unpack(a))
    elseif subaction == "add" then
      s, e = self:addPath(table.unpack(a))
    elseif subaction == "remove" then
      s, e = self:removePath(table.unpack(a))
    end
  elseif action == "install" then
    s, e = self:install()
  elseif action == "reset" then
    s, e = self:reset()
  elseif action == "update" then
    s, e = self:update()
  end
  print(e)
  if not s then
    self:printUsage()
  end
end

function System:constructor()
  self.Data = data("/")

  self:define("nekos.initialized", { description="Determines if the system is initialized.", default=false, type="boolean" })
  self:define("nekos.auto_update", { description="Determines if the system should auto update.", default=true, type="boolean" })

  self:define("nekos.missing_icon", { description="Path to the fallback icon for applications.", default="/Images/missing.nfp", type="string" })

  self:define("nekos.text_color", { description="System text color.", default="white", type="string" })
  self:define("nekos.background_color", { description="System background color.", default="gray", type="string" })
  self:define("nekos.completion_color", { description="System autocomplete color.", default="lightGray", type="string" })

  local s = self:info("lua.autocomplete")
  self:define("lua.autocomplete", { description="[WARNING] NekOS does not support lua autocompletion\n"..s.description, default=false, type=s.type })

  s = self:info("edit.autocomplete")
  self:define("edit.autocomplete", { description="[WARNING] NekOS does not support edit autocompletion\n"..s.description, default=false, type=s.type })

  if not self:get("nekos.initialized") then
    self:set("nekos.initialized", true)
    self:set("lua.autocomplete", false)
    self:set("edit.autocomplete", false)
  end
end

function System:save(path, data)
  return self.Data:save(path, data)
end

function System:load(path)
  return self.Data:load(path)
end

function System:getManifest()
  return self:load(".manifest")
end

function System:reset()
  self.set("nekos.initialized", false)
  local s, e = self:install()
  return s, s and "System reset" or e
end

function System:install()
  local s, e = github:download("FFGFlash", "NekOS", "/", nil, nil, true)
  return s, s and "System installed" or e
end

function System:update()
  local manifest = self:getManifest()
  local newManifest, e = github:getRepo("FFGFlash", "NekOS")
  if not newManifest then return false, e end
  if manifest.updated_at == newManifest.updated_at then return false, "System up to date" end
  local s, e = self:install()
  return s, s and "System updated" or e
end

function System:startup()
  local s = self:getStartup()
  for i,c in ipairs(s) do shell.openTab(c) end
end

function System:getStartup()
  return self:load(".startup")
end

function System:addStartup(command, index)
  local s = self:getStartup()
  table.insert(s, index, command)
  local s, e = s:save()
  return s, s and "Successfully added startup command" or e
end

function System:removeStartup(command)
  local s = self:getStartup()
  local index = table.find(s, command)
  if not index then return false, "Command not found" end
  table.remove(s, index)
  local s, e = s:save()
  return s, s and "Successfully removed startup command" or e
end

function System:getPath()
  return string.split(shell.path(), ":")
end

function System:addPath(path, index)
  local p = self:getPath()
  if table.find(p, path) then return false, "Path already exists" end
  table.insert(p, index, path)
  local s, e = self:setPath(p)
  return s, s and "Successfully modified system path" or e
end

function System:removePath(path)
  local p = self:getPath()
  local index = table.find(p, path)
  if not index then return false, "Path not found" end
  table.remove(p, index)
  local s, e = self:setPath(p)
  return s, s and "Successfully modified system path" or e
end

function System:setPath(path)
  local t = type(path)
  if t ~= "string" and t ~= "table" then return false, "Invalid path type" end
  shell.setPath(t == "string" and path or table.concat(path, ":"))
  return true, "Successfully set system path"
end

function System:define(key, options)
  settings.define(key, options)
end

function System:set(key, value)
  if key then
    settings.set(key, value)
  end
  settings.save("/.settings")
  return true
end

function System:info(key)
  if not key then return false,"No key provided" end
  return settings.getDetails(key)
end

function System:get(key)
  settings.load("/.settings")
  if key then
    return settings.get(key)
  end
  return true
end

function System:getColor(key)
  local info = self:info(key)
  if info.type ~= "string" then return nil end
  return colors[info.value] or colors[info.default]
end

function System:getColorBlit(key)
  return colors.toBlit(self:getColor(key))
end

function System:getUser()
  return self:load(".user")
end

System:call(...)
return System
