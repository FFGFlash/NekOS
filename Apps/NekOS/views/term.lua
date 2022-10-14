return function(a)
  local View = {
    App = a,
    Connections = {},
    History = {}
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
    self:handleResize()
    self.Completion = { List = {}, Index = 1 }
    self.Line = math.max(0, #self.History - self.Height + 1)
    self.Input = { Value = "", Index = 0, Line = (#self.History + 1) - self.Line, Visible = true }

    term.setCursorBlink(true)
    term.setTextColor(system:getColor("nekos.text_color"))
    term.setBackgroundColor(system:getColor("nekos.background_color"))
    term.setCursorPos(1, 1)
    term.clear()

    self:connect("char", self.handleInput)
    self:connect("paste", self.handleInput)
    self:connect("key", self.handleKeyPressed)
    self:connect("terminate", self.handleTerminate)
    self:connect("mouse_scroll", self.handleScroll)
    self:connect("print", self.handlePrint)
    self:connect("clear", self.handleClear)
    self:connect("term_resize", self.handleResize)
  end

  function View:draw()
    local c = self:getCompletion()

    term.clear()
    term.setCursorPos(1, 1)
    for i = 1, self.Height, 1 do
      local j = self.Line + i
      if j <= #self.History then
        term.setCursorPos(1, i)
        term.write(self.History[j])
      end
    end

    term.setCursorBlink(self.Input.Visible)
    if self.Input.Visible then
      term.setCursorPos(1, self.Input.Line)
      term.clearLine()
      term.write("> ")

      local x,y = term.getCursorPos()
      term.write(self.Input.Value)
      term.setTextColor(system:getColor("nekos.completion_color"))
      if c then term.write(c) end
      term.setCursorPos(x + self.Input.Index, y)
    end
  end

  function View:handleResize()
    self.Width, self.Height = term.getSize()
  end

  function View:handleClear()
    self.History = {}
    self:resetScroll()
  end

  function View:handlePrint(text)
    table.insert(self.History, text)
    self:resetScroll()
  end

  function View:handleScroll(direction, x, y)
    self.Line = math.max(self.Line + direction, 0)
    self:updateInputLine()
  end

  function View:resetScroll()
    self.Line = math.max(0, #self.History - self.Height + 1)
    self:updateInputLine()
  end

  function View:updateInputLine()
    self.Input.Line = (#self.History + 1) - self.Line
    self.Input.Visible = self.Input.Line > 0 and self.Input.Line <= self.Height
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
    self:resetScroll()
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
    self:resetScroll()
    self.Completion = { List = {}, Index = 1 }
    self.Input.Index = 0
    if self.Line + 1 > self.Height then self:handleScroll(1) end
    self:draw()
    term.setCursorBlink(false)
    shell.run(self.Input.Value)
    self.Input.Value = ""
    term.setCursorBlink(true)
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
    self:resetScroll()
  end

  function View:fetchShellCompletions()
    if not system:get("shell.autocomplete") then return false, "Autocompletions disabled" end
    self.Completion.List = shell.complete(self.Input.Value)
    self.Completion.Index = 1
    return true
  end

  return View
end
