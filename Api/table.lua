function table.combine(t, o)
  for i,v in ipairs(o) do table.insert(t, v) end
  return t
end

function table.merge(t, o)
  for k,v in pairs(o) do t[k] = v end
  return t
end

function table.set(t)
  local s = {}
  for i,v in ipairs(t) do
    s[v] = s[v] or {}
    s[v][#s[v] + 1] = i
  end
  return s
end

function table.find(t, v)
  local s = table.set(t)
  return s[v] and s[v][1] or nil
end

function table.keys(t)
  local r = {}
  for k,_ in pairs(t) do r[#r + 1] = k end
  return r
end

function table.values(t)
  local r = {}
  for _,v in pairs(t) do r[#r + 1] = v end
  return r
end

function table.filter(t, f)
  local r = {}
  for k,v in pairs(t) do r[k] = f(v,k,t) and v or nil end
  return r
end

function table.isArray(t)
  local m = 0
  for k,v in pairs(t) do
    if type(k) ~= "number" then return false end
    m = math.max(m, k)
  end
  return m == #t
end

return table
