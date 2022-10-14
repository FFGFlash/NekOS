local Clear = api(0, {})

function Clear:execute(...)
  os.queueEvent("clear")
  term.clear()
  term.setCursorPos(1,1)
end

function Clear:constructor() end

Clear:call(...)
return Clear
