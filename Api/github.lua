local Github = api(2, {
  {
    type = "choice",
    options = {
      download = {}
    }
  }
})

function Github:execute(args, action, ...)
  local res,err = false,"Usage: github download <user> <repo> [download path] [remote path] [branch]"
  if action == "download" then
    res,err = self.download(...)
  end
  if not res then self:printUsage() end
end

function Github:constructor() end

function Github:getRepo(user, repo)
  if repo == nil or user == nil then return false,"User and Repo required" end
  local res = http.get("https://cc-nekos.herokuapp.com/api/github/"..user.."/"..repo)
  if not res then return false,"Can't Resolve Manifest URL" end
  local data = json:fromStream(res)
  return data
end

function Github:download(user, repo, dpath, rpath, branch, extract)
  if repo == nil or user == nil then return false,"User and Repo Required" end
  if rpath == nil then rpath = "" end
  if dpath == nil then dpath = "/Downloads/" end
  if branch == nil then branch = "main" end
  if extract == nil then extract = false end

  local function downloadManager(path, files, dirs)
    if not files then files = {} end
    if not dirs then dirs = {} end
    local fType,fPath,fName,cPath = {},{},{},{}
    local res = http.get("https://cc-nekos.herokuapp.com/api/github/"..user.."/"..repo.."/content?branch="..branch.."&path="..path)
    if not res then return false,"Can't Resolve Download URL" end
    res = res.readAll()
    if res ~= nil then
      for str in res:gmatch('"type":"(%w+)"') do table.insert(fType, str) end
      for str in res:gmatch('"path":"([^\"]+)"') do table.insert(fPath, str) end
      for str in res:gmatch('"name":"([^\"]+)"') do table.insert(fName, str) end
    end
    for i,data in pairs(fType) do
      local path = dpath.."/"
      if not extract then
        path = path..repo.."/"
      end
      if data == "file" then
        cPath = http.get("https://cc-nekos.herokuapp.com/api/github/"..user.."/"..repo.."/"..branch.."?path="..fPath[i])
        if cPath == nil then fPath[i] = fPath[i].."/"..fName[i] end
        path = path..fPath[i]
        if not files[path] then
          files[path] = { "https://cc-nekos.herokuapp.com/api/github/"..user.."/"..repo.."/"..branch.."?path="..fPath[i], fName[i] }
        end
      elseif data == "dir" then
        path = path..fPath[i]
        if not dirs[path] then
          dirs[path] = { "https://cc-nekos.herokuapp.com/api/github/"..user.."/"..repo.."/"..branch.."?path="..fPath[i], fName[i] }
          downloadManager(fPath[i], files, dirs)
        end
      end
    end
    return {files=files, dirs=dirs}
  end

  local function downloadFile(path, url, name)
    local dirPath = path:gmatch('([%w%_%.% %-%+%,%;%:%*%#%=%/]+)/'..name..'$')()
    if dirPath ~= nil and not fs.isDir(dirPath) then fs.makeDir(dirPath) end
    local content = http.get(url)
    local file = fs.open(path,"w")
    file.write(content.readAll())
    file.close()
  end

  local res,err = downloadManager(rpath)
  if not res then return res,err end
  for i,data in pairs(res.files) do downloadFile(i, table.unpack(data)) end

  local meta = self:getRepo(user, repo)
  local metaPath = dpath.."/"
  if not extract then
    metaPath = metaPath..repo.."/"
  end
  local metaFile = fs.open(metaPath..".manifest", "w")
  metaFile.write(json:stringify(meta, true))
  metaFile.close()

  return true
end

Github:call(...)
return Github
