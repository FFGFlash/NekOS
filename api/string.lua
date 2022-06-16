function string.startsWith(s, d)
  return string.sub(s, 1, string.len(d)) == d
end

function string.split(s, d)
  d = d or ":"
  local a = {}
  s:gsub(string.format("([^%s]+)", d), function(c) a[#a + 1] = c end)
  return a
end

return string
