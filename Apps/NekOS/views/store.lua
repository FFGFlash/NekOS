return function(a, u)
  local View = {
    App = a,
    User = u,
    Connections = {},
    Width = 0,
    Height = 0
  }

  function View:connect(event, callback, this)
    table.insert(self.Connections, self.App:connect(event, callback, this or self))
  end

  function View:destroy()
    for _, conn in ipairs(self.Connections) do
      self.App:disconnect(conn)
    end
  end

  function View:handleMousePressed(b, mx, my)
    if b ~= 1 then return end
    local selection = self.Apps[my - 1]
    if not selection then return end
    self.App:activate("app", selection.path)
  end

  function View:handleResize()
    self.Width, self.Height = term.getSize()
  end

  function View:handleTerminate()
    self.App:activate("menu")
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
        self:refresh()
      elseif key == keys.left then
        self:moveCursor(-1)
      elseif key == keys.right then
        self:moveCursor(1)
      end
    end
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

  function View.checkBB(x1, y1, x2, y2, x, y)
    return x >= x1 and x < x2 and y >= y1 and y < y2
  end

  function View:build()
    self.Apps = {}
    self.Input = { Value = "", Index = 0 }

    self:handleResize()
    self:connect("char", self.handleInput)
    self:connect("paste", self.handleInput)
    self:connect("key", self.handleKeyPressed)
    self:connect("terminate", self.handleTerminate)
    -- self:connect("mouse_scroll", self.handleScroll)
    self:connect("mouse_click", self.handleMousePressed)
    self:connect("term_resize", self.handleResize)

    self:refresh()
  end

  function View:draw()
    term.clear()
    term.setCursorPos(1, 1)

    local cx, cy = term.getCursorPos()
    local tc = term.getTextColor()
    local tb = term.getBackgroundColor()

    if #self.Apps > 0 then
      for i, app in ipairs(self.Apps) do
        term.setCursorPos(cx, cy + i)
        local creator, name = table.unpack(string.split(app.path, "/"))
        term.setBackgroundColor(i % 2 == 1 and system:getColor("nekos.background_color") or system:getColor("nekos.completion_color"))
        term.write(name.." by "..creator)
      end
    else
      local l = "Unable to Find any Apps"
      term.setCursorPos((self.Width - string.len(l)) / 2, self.Height / 2)
      term.write(l)
    end

    term.setCursorPos(cx, cy)
    term.setTextColor(tc)
    term.setBackgroundColor(colors.blue)

    term.clearLine()
    term.write("> ")
    local x, y = term.getCursorPos()
    term.write(self.Input.Value)
    term.setCursorPos(x + self.Input.Index, y)
  end

  function View:refresh()
    local res = request:get("https://cc-nekos.herokuapp.com/api/apps", { query = self.Input.Value })
    if not res then return false, "Failed to Load Applications" end
    self.Apps = json:fromStream(res)
    return true
  end

  return View
end
