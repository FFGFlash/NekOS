return function(a, u)
  local View = {
    App = a,
    User = u,
    Connections = {}
  }

  function View:connect(event, callback, this)
    table.insert(self.Connections, self.App:connect(event, callback, this or self))
  end

  function View:destroy()
    for _, conn in ipairs(self.Connections) do
      self.App:disconnect(conn)
    end
  end

  function View:build()
    self.Input = { Value = "", Index = 0, Line = 1 }
    self.Timer = os.startTimer(0.25)

    if md5:hash("") == self.User.Password then
      return self.App:activate("menu")
    end

    term.setCursorBlink(true)
    term.setCursorPos(1, 1)
    term.clear()
    term.write("Username > ")
    term.write(self.User.Username)

    self.User()
    self:connect("char", self.handleInput)
    self:connect("paste", self.handleInput)
    self:connect("key", self.handleKeyPressed)
    self:connect("timer", self.handleTimer)
  end

  function View:draw()
    term.setCursorPos(1, self.Input.Line)
    term.clearLine()
    term.write("Password > ")
    local x,_ = term.getCursorPos()
    term.write(string.gsub(self.Input.Value, ".", "*"))
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
    self:draw()
    term.setCursorBlink(false)
    term.setCursorPos(1, self.Input.Line + 1)
    if md5:hash(self.Input.Value) == self.User.Password then
      self.App:activate("menu")
      return
    end
    term.write("Incorrect Password.")
    self.Input.Value = ""
    term.setCursorBlink(true)
  end

  return View
end
