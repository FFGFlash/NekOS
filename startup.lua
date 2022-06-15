for i,f in ipairs(fs.list("/NekOS/Api/")) do
  local n = string.match(fs.getName(f), "([^\.]+)")
  _G[n] = require("/NekOS/Api/"..n)
end

print("Hello World!")
