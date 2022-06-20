function Completions.app(text, space)
  return Completions.choice(text, app:getApps(), space)
end

local App = api(2, {{
  type = "choice",
  options = {
    install = {
      { name = "user", required = true },
      { name = "repo", required = true }
    },
    uninstall = {
      { type = "app", name = "app", required = true }
    },
    update = {
      { type = "app", name = "app", required = true }
    },
    execute = {
      { type = "app", name = "app", required = true },
      { name = "args..." }
    }
  }
}})

function App:execute(action, ...)
  local s, e = false, "Invalid Action"
  if action == "install" then
    s, e = self:install(...)
    if s then print(s) end
  elseif action == "uninstall" then
    s, e = self:uninstall(...)
    if s then print(s) end
  elseif action == "update" then
    s, e = self:update(...)
    if s then print(s) end
  elseif action == "execute" then
    s, e = self:execute(...)
    if s then print(s) end
  end
  if not s then
    print(e)
    self:printUsage()
  end
end

function App:constructor()
  self.Data = data("/NekOS/Apps")
  self.Instances = {}
  self.Apps = system:load(".apps")

  for _, app in pairs(self:getApps()) do
    local descriptor, exists = self:getDescriptor(app)
    if not exists then
      self:uninstall(app)
    else
      if not self.Apps[name] then
        self.Apps[name] = { 1, 2, false }
      end
      self.Apps[name][3] = descriptor.hidden or false
    end
  end

  function self:constructor()
    local app = { Running = false }
    app.__index = app

    function app:__call(id, ...)
      local inst = setmetatable({ Id = id, Path = "/NekOS/Apps/"..id, EventHandler = events(), Data = data("/NekOS/AppData/"..id) }, self)
      inst:connect("terminate", inst.stop)
      inst:constructor(...)
      return inst
    end

    function app:start()
      self.Running = true
      while self.Running do
        self:draw()
        self.EventHandler()
      end
    end

    function app:stop()
      self.Running = false
      self:emit("stop")
    end

    function app:emit(event, ...)
      return self.EventHandler:emit(event, ...)
    end

    function app:connect(event, callback, this)
      return self.EventHandler:connect(event, function(...)
        callback(this or self, ...)
      end)
    end

    function app:disconnect(callback)
      return self.EventHandler:disconnect(callback)
    end

    function app:disconnectAll(event)
      return self.EventHandler:disconnectAll(event)
    end

    function app:load(path)
      return self.Data:load(path)
    end

    function app:save(path, data)
      return self.Data:save(path, data)
    end

    function app:require(path)
      return self.Data:require(self.Id.."/"..path)
    end

    function app:list(dir, recursive)
      return path.list(self.Path.."/"..dir, recursive)
    end

    function app:setInterval(callback, time, ...)
      local token = os.startTimer(time)
      local conn = self:connect("timer", function(a, f)
        if f ~= token then return end
        callback(a, ...)
        token = os.startTimer(time)
      end)
      return { Token = token, Conn = conn }
    end

    function app:clearInterval(interval)
      os.cancelTimer(interval.Token)
      self:disconnect(interval.Conn)
    end

    function app:constructor() end
    function app:draw() end

    return setmetatable(app, app)
  end
end

function App:load(path)
  return self.Data:load(path)
end

function App:save(path, data)
  return self.Data:save(path, data)
end

function App:require(path)
  return self.Data:require(path)
end

function App:getApps()
  return fs.dirs("/NekOS/Apps")
end

function App:getMeta(app)
  return self:load(app.."/.manifest")
end

function App:getDescriptor(app)
  return self:load(app.."/app.json")
end

function App:install(user, repo)
  local s, e = github:downlaod(user, repo, "/NekOS/Apps/")
  if not s then return false, e end
  local descriptor, exists = self:getDescriptor(repo)
  if not exists then
    fs.delete("/NekOS/Apps/"..repo)
    return false, "Descriptor not found"
  end
  self.Apps[repo] = { 1, 2, descriptor.hidden or false }
  return true
end

function App:uninstall(app)
  self.Apps[app] = nil
  if not fs.exists("/NekOS/Apps/"..app) then return false, "App doesn't exist." end
  fs.delete("/NekOS/Apps/"..app)
  return true
end

function App:update(app)
  local meta, exists = self:getMeta(app)
  if not exists then return false, "App not found." end
  local newMeta = github:getRepo(meta.owner.login, meta.name)
  if meta.updated_at == newMeta.updated_at then return false, "App up to date." end
  return self:install(meta.owner.login, meta.name)
end

function App:execute(app, ...)
  local descriptor, exists = self:getDescriptor(app)
  if not exists then return false, "App not found." end
  if not descriptor["local"] then
    local s, e = self:update(app)
    if not s then return false, e end
    descriptor()
  end
  local app = self:require(app.."/"..descriptor.main)(app, ...)
  return app:start() or true
end

App:call(...)
return App
