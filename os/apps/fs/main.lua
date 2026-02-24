local fs = native.fs

local DATA_DIR = "/data"

local function resolveJail()
  local name    = __kernel.name
  local version = "unknown"

  if name:sub(1, 1) == "_" then return "/" end

  return DATA_DIR .. "/" .. name .. "/" .. version
end

local function jail(path)
  local root = resolveJail()
  if root == "/" then return path end

  if not fs.exists(root) then fs.makeDir(root) end

  if path:sub(1, 1) ~= "/" then
    path = root .. "/" .. path
  end

  local parts = {}
  for seg in path:gmatch("[^/]+") do
    if seg == ".." then
      table.remove(parts)
    elseif seg ~= "." then
      parts[#parts + 1] = seg
    end
  end
  local resolved = "/" .. table.concat(parts, "/")

  if resolved ~= root and resolved:sub(1, #root + 1) ~= root .. "/" then
    error("fs: path outside data directory: " .. path, 3)
  end
  return resolved
end

local M = {}

function M.read(path)
  local p = jail(path)
  if not fs.exists(p) then return nil, "not found: " .. path end
  local h = fs.open(p, "r")
  if not h then return nil, "cannot open: " .. path end
  local data = h.readAll(); h.close()
  return data
end

function M.write(path, data)
  local p = jail(path)
  local dir = fs.getDir(p)
  if not fs.exists(dir) then fs.makeDir(dir) end
  local h = fs.open(p, "w")
  if not h then return false, "cannot open for write: " .. path end
  h.write(data or ""); h.close()
  return true
end

function M.append(path, data)
  local p = jail(path)
  local h = fs.open(p, "a")
  if not h then return false, "cannot open for append: " .. path end
  h.write(data or ""); h.close()
  return true
end

function M.delete(path)
  fs.delete(jail(path))
  return true
end

function M.exists(path)
  return fs.exists(jail(path))
end

function M.list(path)
  local p = jail(path)
  if not fs.exists(p) then return nil, "not found: " .. path end
  return fs.list(p)
end

function M.isDir(path)
  return fs.isDir(jail(path))
end

function M.makeDir(path)
  fs.makeDir(jail(path))
  return true
end

function M.move(from, to)
  fs.move(jail(from), jail(to))
  return true
end

function M.copy(from, to)
  fs.copy(jail(from), jail(to))
  return true
end

function M.getSize(path)
  return fs.getSize(jail(path))
end

function M.getName(path) return fs.getName(path) end

function M.getDir(path) return fs.getDir(path) end

function M.combine(a, b) return fs.combine(a, b) end

return M
