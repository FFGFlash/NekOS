return function(a, u)
  local View = {
    App = a,
    User = u,
    Connections = {},
    Structure = {
      { Name = "Username", Filter = "[^(%a| )]" },
      { Name = "Password", Replacer = "*", Passthrough = function(s) return md5:hash(s) end }
    }
  }

  function View:connect(event, callback, this)
    table.insert(self.Connections, self.App:connect(event, callback, this or self))
  end

  function View:destroy()
    self.User:save()
    for _, conn in ipairs(self.Connections) do
      self.App:disconnect(conn)
    end
  end

  function View:build()
    self.Struct = { Value = nil, Index = 0 }
    self.Input = { Value = "", Index = 0, Line = 1 }
    self.Timer = os.startTimer(0.25)

    self.User()
    self:connect("char", self.handleInput)
    self:connect("paste", self.handleInput)
    self:connect("key", self.handleKeyPressed)
    self:connect("timer", self.handleTimer)

    self:nextStruct()
  end

  function View:nextStruct()
    self.Struct.Index = self.Struct.Index + 1
    self.Struct.Value = self.Structure[self.Struct.Index]
    return self.Struct
  end

  function View:draw()
    term.setCursorPos(1, self.Input.Line)
    term.clearLine()
    term.write(self.Struct.Value.Name.." > ")
    local x,_ = term.getCursorPos()
    local r = self.Struct.Value.Replacer
    term.write(r and string.gsub(self.Input.Value, ".", r) or self.Input.Value)
    term.setCursorPos(x + self.Input.Index, self.Input.Line)
  end

  function View:moveCursor(c)
    self.Input.Index = self.Input.Index + c
    local l = string.len(self.Input.Value)
    if self.Input.Index < 0 then
      self.Input.Index = 0
    elseif self.Input.Index > l then
      self.Input.Index = l
    end
  end

  function View:handleKeyPressed(key, held)
    if key == keys.backspace then
      self:handleInput(0)
    elseif key == keys.delete then
      self:handleInput(1)
    elseif not held then
      if key == keys.enter then
        self:processInput()
      elseif key == keys.left then
        self:moveCursor(-1)
      elseif key == keys.right then
        self:moveCursor(1)
      end
    end
  end

  function View:handleTimer(c)
    if c ~= self.Timer then return end
    shell.switchTab(1)
    shell.Timer = os.startTimer(0.25)
  end

  function View:handleInput(c)
    if not c then return
    elseif type(c) == "number" then
      local p = self.Input.Index + c
      self.Input.Value = string.sub(self.Input.Value, 1, p - 1)..string.sub(self.Input.Value, p + 1, -1)
      if c <= 0 then
        self:moveCursor(c - 1)
      end
    else
      self.Input.Value = string.sub(self.Input.Value, 1, self.Input.Index)..c..string.sub(self.Input.Value, self.Input.Index + 1, -1)
      self:moveCursor(string.len(c))
    end
  end

  function View:processInput()
    self.Input.Index = 0
    local w, h = term.getSize()
    if self.Input.Line + 1 > h then
      term.scroll(h - self.Input.Line)
      self.Input.Line = self.Input.Line - 1
    end
    self:draw()
    term.setCursorBlink(false)
    term.setCursorPos(1, self.Input.Line + 1)
    term.clearLine()
    local f = self.Struct.Value.Filter
    if f then
      local m = string.match(self.Input.Value, f)
      if m then
        print("Invalid character '"..m.."' found.")
        return
      end
    end
    local p = self.Struct.Value.Passthrough
    self.User[self.Struct.Value.Name] = p and p(self.Input.Value) or self.Input.Value
    self.Input.Value = ""
    _,self.Input.Line = term.getCursorPos()
    if self.Struct.Index >= #self.Structure then
      return self.App:activate("login")
    end
    term.setCursorBlink(true)
    self:nextStruct()
  end

  return View
end
