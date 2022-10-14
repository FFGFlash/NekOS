function string.startsWith(s, d)
  return string.sub(s, 1, string.len(d)) == d
end

function string.endsWith(s, d)
  return string.sub(s, -string.len(d)) == d
end

function string.split(s, d)
  d = d or ":"
  local a = {}
  s:gsub(string.format("([^%s]+)", d), function(c) a[#a + 1] = c end)
  return a
end

function string.remove(s, i)
  return string.sub(s, 1, i - 1)..string.sub(s, i + 1, -1)
end

function string.insert(s, i, c)
  return string.sub(s, 1, i)..c..string.sub(s, i + 1, -1)
end

return string
