function fs.dirs(root)
  local dirs = {}
  for _, file in ipairs(fs.list(path)) do
    local path = root.."/"..file
    if fs.isDir(path) then
      table.insert(dirs, file)
    end
  end
  return dirs
end

function fs.files(root)
  local files = {}
  for _, file in ipairs(fs.list(path)) do
    local path = root.."/"..file
    if not fs.isDir(path) then
      table.insert(files, file)
    end
  end
  return files
end

return fs
