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
    run = {
      { type = "app", name = "app", required = true },
      { name = "args..." }
    }
  }
}})

function App:execute(action, ...)
  local s, e = false, "Invalid Action"
  if action == "install" then
    s, e = self:install(...)
  elseif action == "uninstall" then
    s, e = self:uninstall(...)
  elseif action == "update" then
    s, e = self:update(...)
  elseif action == "run" then
    s, e = self:run(...)
  end
  print(e)
  if not s then
    self:printUsage()
  end
end

function App:constructor()
  self.Data = data("/Apps")
  self.Instances = {}
  self.Apps = system:load(".apps")

  if not fs.exists("/Apps") then
    fs.mkdir("/Apps")
  end

  for _, app in ipairs(self:getApps()) do
    local descriptor, exists = self:getDescriptor(app)
    if not exists then
      self:uninstall(app)
    else
      if not self.Apps[app] then
        self.Apps[app] = { 1, 2, false }
      end
      self.Apps[app][3] = descriptor.hidden or false
    end
  end

  function self:constructor()
    local app = { Running = false }
    app.__index = app

    function app:__call(id, ...)
      local inst = setmetatable({ Id = id, Path = "/Apps/"..id, EventHandler = events(), Data = data("/AppData/"..id) }, self)
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
      return App.Data:require(self.Id.."/"..path)
    end

    function app:list(dir, recursive)
      return path.list(self.Path.."/"..dir, recursive)
    end

    function app:setInterval(callback, time, this, ...)
      local args = { ... }
      local token = os.startTimer(time)
      local conn = self:connect("timer", function(a, f)
        if f ~= token then return end
        callback(a, table.unpack(args))
        token = os.startTimer(time)
      end, this)
      return { Token = token, Conn = conn }
    end

    function app:setTimeout(callback, time, this, ...)
      local args = { ... }
      local token = os.startTimer(time)
      local conn = self:connect("timer", function(a, f)
        if f ~= token then return end
        callback(a, table.unpack(args))
        self:disconnect(conn)
      end, this)
      return { Token = token, Conn = conn }
    end

    function app:clearInterval(interval)
      os.cancelTimer(interval.Token)
      self:disconnect(interval.Conn)
    end

    function app:clearTimeout(...)
      self:clearInterval(...)
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
  return fs.dirs("/Apps")
end

function App:getMeta(app)
  return self:load(app.."/.manifest")
end

function App:getDescriptor(app)
  return self:load(app.."/app.json")
end

function App:install(user, repo)
  local s, e = github:download(user, repo, "/Apps/")
  if not s then return false, e end
  local descriptor, exists = self:getDescriptor(repo)
  if not exists then
    fs.delete("/Apps/"..repo)
    return false, "Descriptor Not Found"
  end
  self.Apps[repo] = { 1, 2, descriptor.hidden or false }
  self.Apps:save()
  return true, "Install Complete"
end

function App:uninstall(app)
  self.Apps[app] = nil
  self.Apps:save()
  if not fs.exists("/Apps/"..app) then return false, "App Not Found" end
  fs.delete("/Apps/"..app)
  return true, "Uninstall Complete"
end

function App:checkForUpdate(app)
  local meta, exists = self:getMeta(app)
  if not exists then return false, "App Not Found" end
  local newMeta = github:getRepo(meta.owner.login, meta.name)
  if meta.updated_at == newMeta.updated_at then return false, "No Update Found" end
  return newMeta, "Found an Update"
end

function App:update(app)
  local update, e = self:checkForUpdate(app)
  if not update then return false, e end
  local s, e = self:install(update.owner.login, update.name)
  return s, s and "Update Complete" or e
end

function App:run(app, ...)
  local descriptor, exists = self:getDescriptor(app)
  if not exists then return false, "App Not Found" end
  if not descriptor["local"] then
    local s, e = self:update(app)
    if not s then return false, e end
    descriptor()
  end
  local name = string.match(fs.getName(descriptor.main), "([^\.]+)")
  local app = self:require(app.."/"..name)(app, ...)
  return app:start() or true
end

App:call(...)
return App
