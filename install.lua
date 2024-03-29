if http then
  local function download(user, repo, dpath, rpath, branch, extract)
    if repo == nil or user == nil then return false,"User and Repo required" end
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

    return true
  end

  local res,err = download("FFGFlash", "NekOS", "/", nil, nil, true)
  if not res then return print(err) end
  os.reboot()
else
  print("You need to enable the HTTP API!")
end
