return function(app, user)
  local View = {
    App = app,
    User = user,
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

  function View:handleMousePressed(b, mx, my)
    self.Selection = nil
    for name, data in pairs(app.Apps:raw()) do
      if not data[3] then
        local x, y = math.clamp(data[1], 1, self.Width - 2), math.clamp(data[2], 2, self.Height - 2)
        if self.checkBB(x, y, x + 3, y + 3, mx, my) then
          self.Selection = { name, x - mx, y - my }
          break
        end
      end
    end
  end

  function View:handleMouseReleased(b, mx, my)
    if self.Dragging then
      self.Dragging = false
      app.Apps:save()
      return
    end

    for i, btn in ipairs(self.Buttons) do
      if self.checkBB(btn[1], btn[2], btn[1] + btn[3], btn[2] + btn[4], mx, my) then
        btn[5]()
        return
      end
    end

    for name, data in pairs(app.Apps:raw()) do
      if not data[3] then
        local x, y = math.clamp(data[1], 1, self.Width - 2), math.clamp(app[2], 2, self.Height - 2)
        if self.checkBB(x, y, x + 3, y + 3, mx, my) then
          local i = shell.openTab("app execute", name)
          multishell.setFocus(i)
          return
        end
      end
    end
  end

  function View:handleMouseDragged(b, mx, my)
    self.Dragging = true
    if not self.Selection then return end
    local s = app.Apps[self.Selection[1]]
    s[1] = mx + self.Selection[2]
    s[2] = my + self.Selection[3]
  end

  function View:handleResize()
    self.Width, self.Height = term.getSize()
    self.Buttons = {}
    self.TextButtons = {}

    self:addTextButton(self.Width - 1, 1, "> ", function() self.App:activate("term") end, colors.black, colors.white)
  end

  function View:handleTerminate()
    self.App:activate("login")
  end

  function View.checkBB(x1, y1, x2, y2, x, y)
    return x >= x1 and x < x2 and y >= y1 and y < y2
  end

  function View:addButton(x, y, w, h, s, b)
    self.Buttons[#self.Buttons + 1] = {x, y, w, h, s, b}
    return #self.Buttons
  end

  function View:addTextButton(x, y, i, s, b, c)
    local index = self:addButton(x, y, string.len(i), 1, s, b)
    self.TextButtons[index] = {i, c}
    return index
  end

  function View:build()
    self.Dragging = false
    self.Selection = nil
    self.Buttons = {}

    self:connect("mouse_click", self.handleMousePressed)
    self:connect("mouse_up", self.handleMouseReleased)
    self:connect("mouse_drag", self.handleMouseDragged)
    self:connect("term_resize", self.handleResize)
    self:connect("terminate", self.handleTerminate)

    self:handleResize()
  end

  function View:draw()
    term.clear()
    term.setCursorPos(1, 1)

    local cx, cy = term.getCursorPos()
    local tc = term.getTextColor()
    local tb = term.getBackgroundColor()

    for name, data in pairs(app.Apps:raw()) do
      if not data[3] then
        local descriptor = app:getDescriptor(name)
        local icon = "/NekOS/Apps/"..name.."/"..(descriptor.icon or "icon.nfp")
        local image = paintutils.loadImage(fs.exists(icon) and icon or system:get("nekos.missing_icon"))
        local x, y = math.clamp(data[1], 1, self.Width - 2), math.clamp(data[2], 2, self.Height - 2)
        paintutils.drawImage(image, x, y)
      end
    end

    for i, btn in ipairs(self.Buttons) do
      paintutils.drawFilledBox(btn[1], btn[2], btn[1] + btn[3] - 1, btn[2] + btn[4] - 1, btn[6])
      local textBtn = self.TextButtons[i]
      if textBtn then
        term.setCursorPos(btn[1], btn[2])
        term.setTextColor(textBtn[2])
        term.setBackgroundColor(btn[6])
        term.write(textBtn[1])
      end
    end

    term.setCursorPos(cx, cy)
    term.setTextColor(tc)
    term.setBackgroundColor(tb)

    local l = "nekOS///"
    term.blit(l, string.gsub("00000bde", "0", system:getColorBlit("nekos.text_color")), string.gsub(l, ".", system:getColorBlit("nekos.background_color")))
    term.write(" "..self.User.Username)
    term.setCursorPos(1, 2)
  end

  return View
end
