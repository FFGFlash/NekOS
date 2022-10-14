local Help = api(0, {
  { type = "api", name = "program" }
})

function Help:execute(program, ...)
  if not program then
    print("Welcome to NekOS")
    for name,program in pairs(api.List) do
      program:printUsage()
    end
  else
    program = api.List[program]
    if not program then
      print("Unknown Program")
      self:execute()
    else
      program:printUsage()
    end
  end
end

function Help:constructor() end

Help:call(...)
return Help
