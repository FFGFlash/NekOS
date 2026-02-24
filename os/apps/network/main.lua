local http = native.http

local M = {}

function M.get(url, headers)
  local r = http.get(url, headers)
  if not r then return { ok = false, body = nil, code = 0, headers = {} } end
  local result = {
    ok      = true,
    code    = r.getResponseCode(),
    body    = r.readAll(),
    headers = r.getResponseHeaders(),
  }
  r.close()
  return result
end

function M.post(url, body, headers)
  local r = http.post(url, body, headers)
  if not r then return { ok = false, body = nil, code = 0 } end
  local result = {
    ok   = true,
    code = r.getResponseCode(),
    body = r.readAll(),
  }
  r.close()
  return result
end

function M.checkURL(url)
  return http.checkURL(url)
end

return M
