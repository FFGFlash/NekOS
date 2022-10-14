local Print = api(0, {
  { name = "...text" }
})

function Print:execute(...)
  local args = { ... }
  self(table.concat(args, " "))
end

function Print:constructor()
  self.p = print
  function self:constructor(...)
    self.p(...)
    os.queueEvent("print", ...)
  end
end

return Print
