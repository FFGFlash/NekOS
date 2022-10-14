local Help = api(0, {
  { type = "api", name = "api" }
})

function Help:execute(api, ...)
  if not program then
    print("Welcome to NekOS")
    for name,api in pairs(api.List) do
      api:printUsage()
    end
  else
    local api = api.List[api]
    api:printUsage()
  end
end

function Help:constructor() end

Help:call(...)
return Help
