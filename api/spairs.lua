return function(t, o)
  local k, i = table.keys(t), 0
  table.sort(k, not o and nil or function(a, b) return o(t[a], t[b]) end)
  return function()
    i = i + 1
    if k[i] then return k[i],t[k[i]] end
  end
end
