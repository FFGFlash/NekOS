local loader = {}

local SYSTEM_CALLBACKS = {
  main = true
}

function loader.loadModule(path, env)
  if not fs.exists(path) then
    return nil, nil, "file not found: " .. path
  end

  local h = fs.open(path, "r")
  if not h then return nil, nil, "cannot open: " .. path end
  local code = h.readAll(); h.close()

  local fn, compileErr = load(code, "@" .. path, "bt", env)
  if not fn then
    return nil, nil, "compile error in " .. path .. ": " .. compileErr
  end

  local ok, result = pcall(fn)
  if not ok then
    return nil, nil, "runtime error in " .. path .. ": " .. tostring(result)
  end

  local publicAPI = type(result) == "table" and result or {}

  local callbacks = {}
  for cbName in pairs(SYSTEM_CALLBACKS) do
    local cb = rawget(env, cbName)
    if type(cb) == "function" then
      callbacks[cbName] = cb
    end
  end

  for cbName in pairs(SYSTEM_CALLBACKS) do
    publicAPI[cbName] = nil
  end

  return publicAPI, callbacks
end

loader.SAFE_GLOBALS = {
  -- type system
  type = type,
  tostring = tostring,
  tonumber = tonumber,
  select = select,
  unpack = table.unpack or unpack,
  rawget = rawget,
  rawset = rawset,
  rawequal = rawequal,
  rawlen = rawlen,
  next = next,
  pairs = pairs,
  ipairs = ipairs,
  pcall = pcall,
  xpcall = xpcall,
  error = error,
  assert = assert,
  setmetatable = setmetatable,
  getmetatable = getmetatable,
  -- standard libs
  math = math,
  string = string,
  table = table,
  bit = bit,
  bit32 = bit32,
  utf8 = utf8,
  textutils = textutils,
  keys = keys,
  colors = colors,
  colours = colours,
}

return loader
