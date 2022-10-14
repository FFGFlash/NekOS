local Help = api(0, {
  { type = "api", name = "api" }
})

function Help:execute(program, ...)
  if not program then
    print("Welcome to NekOS")
    for name,program in pairs(api.List) do
      program:printUsage()
    end
  else
    local program = api.List[program]
    program:printUsage()
  end
end

function Help:constructor() end

Help:call(...)
return Help
