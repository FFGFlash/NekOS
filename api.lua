_G.Completions = require("cc.completion")

function Completions.api(text, space)
  return Completions.choice(text, table.keys(api.List), space)
end

function table.combine(t, o)
  for i,v in ipairs(o) do table.insert(t, v) end
  return t
end

local Api = { List = {} }
Api.__index = Api

function Api:load()
  local apis = {}
  for i,file in ipairs(fs.list("/Api/")) do
    local name = string.match(fs.getName(file), "([^\.]+)")
    local api = require("/Api/"..name)
    if type(api) ~= "table" or api["__order__"] == nil then
      _G[name] = api
    else
      apis[name] = api
    end
  end
  for name,api in spairs(apis, function(a,b)
    return a["__order__"] < b["__order__"]
  end) do
    _G[name] = api()
    self.List[name] = _G[name]
  end
  system:addPath("/Api", 2)
end

function Api:buildCompletions(tree)
  local function constructUsage(tree)
    local function simplifier(a)
      local res = {}
      for i,c in ipairs(a) do
        if c.type == "choice" then
          for k,v in pairs(c.options) do
            local b = simplifier(v)
            table.insert(b, 1, k)
            table.insert(res, b);
          end
        else
          table.insert(res, c.required and "<"..c.name..">" or "["..c.name.."]")
        end
      end
      return res
    end

    local function parser(a)
      local res,str,pre = {},true,""
      if type(a) == "table" then
        for i,v in ipairs(a) do
          if type(v) ~= "string" then
            str = false
            local b = parser(v)
            for j,w in ipairs(b) do
              table.insert(res, pre..w)
            end
          else
            pre = pre..v.." "
          end
        end
        if str then table.insert(res, table.concat(a, " ")) end
      elseif type(a) == "string" then
        table.insert(res, a)
      end
      return res
    end

    local res = simplifier(tree)
    local usages = {}

    for i,v in ipairs(res) do
      table.combine(usages, parser(v))
    end

    return usages
  end

  local function helper(shell, index, current, args)
    local function find(tree, offset)
      offset = offset or 0
      if not tree then return {} end
      for i,v in ipairs(tree) do
        if offset + i == index then
          return v
        elseif v.type == "choice" then
          offset = offset + i
          return find(v.options[args[offset + 1]], offset)
        end
      end
      return {}
    end

    local cur = find(tree)
    if not cur.type or not Completions[cur.type] then return {} end
    local a = {current, cur.space or false}
    if cur.options then table.insert(a, 2, table.keys(cur.options)) end
    return Completions[cur.type](table.unpack(a))
  end

  return helper, constructUsage(tree)
end

function Api:__call(order, completion)
  local usage = nil

  if type(completion) == "table" then
    completion,usage = self:buildCompletions(completion)
  end

  local api = {
    ["__order__"] = order or 0,
    ["__completion__"] = completion,
    ["__usage__"] = usage,
    ["__name__"] = ""
  }

  function api:__call(...)
    return self:constructor(...) or self
  end

  function api:printUsage()
    if not self["__usage__"] then return end
    print(self["__name__"])
    for i,usage in ipairs(self["__usage__"]) do
      print(self["__name__"].." "..usage)
    end
  end

  function api:constructor() end

  function api:call(...)
    local argv = {...}
    if argv[1] and argv[2] and fs.getName(argv[1]..".lua") == fs.getName(argv[2]) then
      self["__name__"] = string.match(fs.getName(argv[2]), "([^\.]+)")
      if not self["__completion__"] then return end
      shell.setCompletionFunction(argv[2], self["__completion__"])
      return
    end
    local args = { ["_"] = {} }
    for i=1,#argv,1 do
      local arg = argv[i]
      if arg == "." then arg = nil end
      if string.startsWith(arg, "--") then
        local nxt = argv[i + 1]
        if nxt and not string.startsWith(nxt, "--") then
          if nxt == "." then nxt = nil end
          args[arg] = nxt
          i = i + 1
        else
          args[arg] = true
        end
      else
        table.insert(args["_"], arg)
      end
    end
    local name = shell.getRunningProgram()
    if args["--focus"] then
      local id = multishell.getCurrent()
      multishell.setFocus(id)
      name = multishell.getTitle(id)
    end
    name = string.match(fs.getName(name), "([^\.]+)")
    self.execute(_G[name], args, table.unpack(args["_"]))
  end

  return setmetatable(api, api)
end

return setmetatable(Api, Api);
