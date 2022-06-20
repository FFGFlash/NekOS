return function(app)
  local View = {
    App = app,
    Connections = {}
  }

  function View:connect(event, callback, this)
    table.insert(self.Connections, self.App:connect(event, callback, this or self))
  end

  function View:destroy()
    for _, conn in ipairs(self.Connections) do
      self.App:disconnect(conn)
    end
    term.setCursorBlink(false)
  end

  function View:build()
    self.Completion = { List = {}, Index = 1 }
    self.Input = { Value = "", Index = 0, Line = 1 }

    term.setCursorBlink(true)
    term.setTextColor(system:getColor("nekos.text_color"))
    term.setBackgroundColor(system:getColor("nekos.background_color"))
    term.setCursorPos(1, 1)
    term.clear()

    self:connect("char", self.handleInput)
    self:connect("paste", self.handleInput)
    self:connect("key", self.handleKeyPressed)
    self:connect("terminate", self.handleTerminate)
  end

  function View:draw()
    local c = self:getCompletion()

    term.setCursorPos(1, self.Input.Line)
    term.clearLine()
    term.write("> ")

    local x,_ = term.getCursorPos()
    term.write(self.Input.Value)
    term.setTextColor(system:getColor("nekos.completion_color"))
    if c then term.write(c) end
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
      elseif key == keys.up then
        self:changeCompletion(1)
      elseif key == keys.down then
        self:changeCompletion(-1)
      elseif key == keys.tab then
        self:handleInput(self:getCompletion())
      end
    end
  end

  function View:handleTerminate()
    self.App:activate("menu")
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
    if system:get("shell.autocomplete") then
      self:fetchShellCompletions()
    else
      self.Completion = { List = {}, Index = 1 }
    end
  end

  function View:processInput()
    self.Completion = { List = {}, Index = 1 }
    self.Input.Index = 0
    local w, h = term.getSize()
    if self.Input.Line + 1 > h then self:scroll(1) end
    self:draw()
    term.setCursorBlink(false)
    term.setCursorPos(1, self.Input.Line + 1)
    shell.run(self.Input.Value)
    self.Input.Value = ""
    _, self.Input.Line = term.getCursorPos()
    term.setCursorBlind(true)
  end

  function View:getCompletion()
    return self.Completion.List and self.Completion.List[self.Completion.Index] or nil
  end

  function View:changeCompletion(c)
    if not self.Completion.List then return end
    local max = #self.Completion.List
    self.Completion.Index = self.Completion.Index + c
    if self.Completion.Index <= 0 then
      self.Completion.Index = max
    elseif self.Completion.Index > max then
      self.Completion.Index = 1
    end
  end

  function View:scroll(c)
    term.scroll(c)
    self.Input.Line = self.Input.Line - c
  end

  function View:fetchShellCompletions()
    if not system:get("shell.autocomplete") then return false, "Autocompletions disabled" end
    self.Completion.List = shell.complete(self.Input.Value)
    self.Completion.Index = 1
    return true
  end

  return View
end
