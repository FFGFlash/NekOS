local scomp = require("cc.shell.completion")

local Api = {}
Api.__index = Api

function Api:__call(order, completion)
  if type(completion) == "table" then
    completion = scomp.build(completion)
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
