_G.Completions = require("cc.shell.completion")

system:addPath("/NekOS/Api", 2)

local Api = {}
Api.__index = Api

function Api:load()
  local apis = {}
  for i,file in ipairs(fs.list("/NekOS/Api/")) do
    local name = string.match(fs.getName(file), "([^\.]+)")
    local api = require("/NekOS/Api/"..name)
    if type(api) ~= "table" or api["__order__"] == nil then
      _G[name] = api
      return
    end
    apis[name] = api
  end
  for name,api in spairs(apis, function(a,b)
    return a["__order__"] > b["__order__"]
  end) do
    _G[name] = api()
  end
end

function Api:buildCompletions(tree)
  local r = {}
  for i,func in ipairs(tree) do
    local opts = nil
    if type(func) == "table" then func,opts = table.unpack(v) end
    if type(func) == "string" then func = Completions[func] end
    if type(func) ~= "function" then func = nil end
    r[#r+1] = opts and { func, opts } or func
  end
  return Completions.build(table.unpack(r))
end

function Api:__call(order, completion)
  if type(completion) == "table" then
    completion = self:buildCompletions(completion)
  end

  local api = {
    ["__order__"] = order or 0,
    ["__completion__"] = completion
  }

  function api:__call()
    self:constructor()
    return self
  end

  function api:constructor() end

  function api:call(...)
    local a = {...}
    if a[1] and a[2] and fs.getName(a[1]..".lua") == fs.getName(a[2]) then
      if not self["__completion__"] then return end
      shell.setCompletionFunction(a[2], self["__completion__"])
      return
    end
    for i=1,#a,1 do
      if a[i] == "." then
        a[i] = nil
      end
    end
    self:execute(...)
  end

  return setmetatable(api, api)
end

return setmetatable(Api, Api);
