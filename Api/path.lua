local Path = api(0)

function Path:execute(...) end
function Path:constructor() end

function Path.list(root, recursive)
  local function helper(path)
    local retVal = {}
    local files = fs.list(path)
    for _,file in ipairs(files) do
      file = path.."/"..file
      local isDir = fs.isDir(file)
      if isDir and recursive then
        table.combine(retVal, helper(file))
      elseif not isDir then
        file = string.gsub(file, root.."/", "")
        table.insert(retVal, file)
      end
    end
    return retVal
  end
  return helper(root)
end

Path:call(...)
return Path
