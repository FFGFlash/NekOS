local Data = api(1)

function Data:execute() end

function Data:constructor(root)
  self.__index = self
  root = root or "/"
  local inst = setmetatable({ root = root }, self)
  return inst
end

function Data:require(path)
  return require(self.root.."/"..path)
end

function Data:move(old, new, force)
  force = force or false
  if force then fs.delete(self.root.."/"..new) end
  local success,err = pcall(function() fs.move(self.root.."/"..old, self.root.."/"..new) end)
  if not success then return false,err end
  return true
end

function Data:save(path, data, isJson)
  isJson = isJson or false
  local success,err = pcall(function() data = isJson and json:stringify(data) or textutils.serialize(data, { compact = true }) end)
  if not success then return false,err end
  local file = fs.open(self.root.."/"..path, "w")
  file.write(data)
  file.close()
  return true
end

function Data:load(path)
  local manager,super = {
    file = path,
    path = self.root.."/"..path,
    data = {},
    json = false
  },self

  function manager:__call()
    if not rawget(self, "exists")(self) then return false,"File not found." end
    local file = fs.open(rawget(self, "path"), "r")
    local raw = file.readAll()
    file.close()
    local data = {}
    local success,err = pcall(function() data = textutils.unserialize(raw) end)
    if not success then return false,err end
    if not data then
      local success,err = pcall(function() data = json:parse(raw) end)
      if not success then return false,err
      elseif not data then return false,"Couldn't read file."
      end
      rawset(self, "json", true)
    end
    rawset(self, "data", data)
    return true
  end

  function manager:__index(key)
    return rawget(self, "data")[key] or rawget(self, key)
  end

  function manager:__newindex(key, value)
    rawget(self, "data")[key] = value
  end

  function manager:exists()
    return fs.exists(rawget(self, "path"))
  end

  function manager:save(path)
    local success,err = super:save(self.file, rawget(self, "data"), rawget(self, "json"))
    if not success then return false,err end
    if path and path ~= self.file then return super:move(self.file, path, true) end
    return true
  end

  return setmetatable(manager, manager), manager()
end

Data:call(...)
return Data
