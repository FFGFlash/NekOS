local Request = api(0, {{
  type = "choice",
  options = {
    post = {
      { name = "url" }
    },
    get = {
      { name = "url" }
    }
  }
}})

function Request:execute(args, action, ...)
  local s, e = false, "Invalid Action"
  if action == "post" then
    s, e = self:post(...)
    if s then print(s) end
  elseif action == "get" then
    s, e = self:get(...)
    if s then print(s) end
  end
  if not s then
    print(e)
    self:printUsage()
  end
end

function Request:constructor() end

function Request.encode(...)
  local retVal = {}
  for _,str in ipairs({...}) do
    table.insert(retVal, textutils.urlEncode(str))
  end
  return table.unpack(retVal)
end

function Request:parseParams(params)
  local retVal = {}
  for key, value in pairs(params) do
    table.insert(retVal, key.."="..self.encode(tostring(value)))
  end
  return table.concat(retVal, "&")
end

function Request:post(url, body, headers)
  headers = table.merge({ ["Content-Type"] = "application/json" }, headers)
  body = json:stringify(body or {})
  return http.post(url, body, headers)
end

function Request:get(url, params, headers)
  params = self:parseParams(params or {})
  return http.get(url.."?"..params, headers)
end

Request:call(...)
return Request
