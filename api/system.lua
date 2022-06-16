local System = api(0, {
  { "choice", { "install", "reset", "update" }}
})

function System:execute(action, ...) end

function System:constructor()
  self.define("nekos.initialized", { description="Determines if the system is initialized.", default=false, type="boolean" })
  self.define("nekos.auto_update", { description="Determines if the system should auto update.", defaults=true, type="boolean" })
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
