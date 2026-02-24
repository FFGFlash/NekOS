local subs = {}

local function addSub(eventName, pid, callback, once)
  subs[eventName] = subs[eventName] or {}
  table.insert(subs[eventName], { pid = pid, cb = callback, once = once })
end

local function removeSub(eventName, pid, callback)
  local list = subs[eventName]
  if not list then return end
  for i = #list, 1, -1 do
    local s = list[i]
    if s.pid == pid and (callback == nil or s.cb == callback) then
      table.remove(list, i)
    end
  end
end

local function dispatch(eventName, args)
  local lists = { subs[eventName], subs["*"] }
  for _, list in ipairs(lists) do
    if list then
      for i = #list, 1, -1 do
        local s = list[i]
        local ok, err = pcall(s.cb, table.unpack(args, 1, args.n or #args))
        if not ok then
          table.remove(list, i)
        end
        if s.once then table.remove(list, i) end
      end
    end
  end
end

function main()
  while true do
    local ev = table.pack(native.coroutine.yield(nil))
    local evName = ev[1]

    if evName and evName ~= "__ipc" then
      local args = {}
      for i = 2, ev.n do args[i - 1] = ev[i] end
      args.n = ev.n - 1
      dispatch(evName, args)
    end
  end
end

local M = {}

function M.subscribe(eventName, callback)
  assert(type(eventName) == "string", "subscribe: eventName must be a string")
  assert(type(callback) == "function", "subscribe: callback must be a function")
  addSub(eventName, __kernel.pid, callback, false)
end

function M.once(eventName, callback)
  assert(type(eventName) == "string", "subscribe: eventName must be a string")
  assert(type(callback) == "function", "subscribe: callback must be a function")
  addSub(eventName, __kernel.pid, callback, true)
end

function M.subscribeAll(callback)
  assert(type(callback) == "function", "subscribe: callback must be a function")
  addSub("*", __kernel.pid, callback, false)
end

function M.unsubscribe(eventName, callback)
  removeSub(eventName, __kernel.pid, callback)
end

return M
