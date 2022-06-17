local Json = api(0)

function Json:execute() end

function Json:constructor()
  self.whites = {["\n"] = true, ["\r"] = true, ["\t"] = true, [" "] = true, [","] = true, [":"] = true}
  self.numChars = {["e"] = true, ["E"] = true, ["+"] = true, ["-"] = true, ["."] = true}
  self.escaped = {["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f", ["\""] = "\\\"", ["\\"] = "\\\\"}
  self.iescaped = {}
  for k,v in pairs(self.escaped) do self.iescaped[v] = k end
end

function Json:parse(str)
  function removeWhite(s)
    while self.whites[s:sub(1,1)] do
      s = s:sub(2)
    end
    return s
  end

  function parseBoolean(s)
    local v = s:sub(1,4) == "true"
    return v, removeWhite(s:sub(v and 5 or 6))
  end

  function parseNull(s)
    return nil, removeWhite(s:sub(5))
  end

  function parseNumber(s)
    local i = 1
    while self.numChars[s:sub(i, i)] or tonumber(s:sub(i, i)) do
      i = i + 1
    end
    local v = tonumber(s:sub(1, i - 1))
    return v, removeWhite(s:sub(i))
  end

  function parseString(s)
    s = s:sub(2)
    local v = ""
    while s:sub(1, 1) ~= "\"" do
      local n = s:sub(1, 1)
      s = s:sub(2)
      assert(n ~= "\n", "Unclosed string")
      if n == "\\" then
        local e = s:sub(1, 1)
        s = s:sub(2)
        n = assert(self.iescaped[n..e], "Invalid escaped character")
      end
      v = v..n
    end
    return v, removeWhite(s:sub(2))
  end

  function parseArray(s)
    s = removeWhite(s:sub(2))
    local a, i = {}, 1
    while s:sub(1, 1) ~= "]" do
      local v = nil
      v, s = parseValue(s)
      a[i] = v
      i = i + 1
      s = removeWhite(s)
    end
    return a, removeWhite(s:sub(2))
  end

  function parseMember(s)
    local k, v = nil, nil
    k, s = parseValue(s)
    v, s = parseValue(s)
    return k, v, s
  end

  function parseObject(s)
    s = removeWhite(s:sub(2))
    local t = {}
    while s:sub(1, 1) ~= "}" do
      local k, v = nil, nil
      k, v, s = parseMember(s)
      t[k] = v
      s = removeWhite(s)
    end
    return t, removeWhite(s:sub(2))
  end

  function parseValue(s)
    local f = s:sub(1, 1)
    if f == "{" then
      return parseObject(s)
    elseif f == "[" then
      return parseArray(s)
    elseif tonumber(f) ~= nil or self.numChars[f] then
      return parseNumber(s)
    elseif s:sub(1, 4) == "true" or s:sub(1, 5) == "false" then
      return parseBoolean(s)
    elseif f == "\"" then
      return parseString(s)
    elseif s:sub(1, 4) == "null" then
      return parseNull(s)
    end
    return nil
  end

  return parseValue(removeWhite(str))
end

function Json:fromStream(stream)
  return self:parse(stream.readAll())
end

function Json:fromFile(file)
  file = fs.open(file, "r")
  local ret = self:fromStream(file)
  file.close()
  return ret
end

function Json:stringify(json, pretty, u, o)
  local str = ""
  pretty, u, o = pretty or false, u or 0, o or {}

  local function tab(i)
    str = str..("\t"):rep(u)..i
  end

  local function encoding(t, b, c, i, l)
    str = str..b

    if pretty then
      str = str.."\n"
      u = u + 1
    end

    for k, v in i(t) do
      tab("")
      l(k, v)
      str = str..","
      if pretty then
        str = str.."\n"
      end
    end

    if pretty then
      u = u - 1
    end

    if str:sub(-2) == ",\n" then
      str = str:sub(1, -3).."\n"
    elseif str:sub(-1) == "," then
      str = str:sub(1, -2)
    end
    tab(c)
  end

  if type(json) == "table" then
    assert(not o[json], "Cannot handle cyclic tables")
    o[json] = true
    if table.isArray(json) then
      encoding(json, "[", "]", ipairs, function(k, v)
        str = str..self:stringify(v, pretty, u, o)
      end)
    else
      encoding(json, "{", "}", pairs, function(k, v)
        assert(type(k) == "string", "JSON Object keys must be strings", 2)
        str = str..self:stringify(k, pretty, u, o)
        str = str..(p and ": " or ":")..self:stringify(v, pretty, u, o)
      end)
    end
  elseif type(json) == "string" then
    str = "\""..json:gsub("[%c\"\\]", self.escaped).."\""
  elseif type(json) == "number" or type(json) == "boolean" then
    str = tostring(json)
  else
    error("JSON only supports arrays, objects, numbers, booleans and strings", 2)
  end
  return str
end

Json:call(...)
return Json
