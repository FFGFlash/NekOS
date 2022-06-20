return function()
  local handler = { Events = {} }
  handler.__index = handler

  function handler:__call()
    local args = { os.pullEvent() }
    local event = table.remove(args, 1)
    if not self.Events[event] then return end
    for i, callback in ipairs(self.Events[event]) do
      callback(table.unpack(args))
    end
  end

  function handler:emit(event, ...)
    os.queueEvent(event, ...)
  end

  function handler:disconnect(eventCallback)
    table.remove(self.Events[eventCallback.Event], eventCallback.Id)
  end

  function handler:connect(event, callback)
    self.Events[event] = self.Events[event] or {}
    table.insert(self.Events[event], callback)
    return { Event = event, Id = #self.Events[event] }
  end

  function handler:disconnectAll(event)
    if event then
      self.Events[event] = nil
    else
      self.Events = {}
    end
  end

  return setmetatable(handler, handler)
end
