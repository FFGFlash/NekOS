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

  end

  function View:handleResize()
    self.Width, self.Height = term.getSize()
  end

  function View:handleTerminate()
    self.App:activate("menu")
  end

  function View.checkBB(x1, y1, x2, y2, x, y)
    return x >= x1 and x < x2 and y >= y1 and y < y2
  end

  function View:build()
    self:handleResize()
    self:connect("mouse_click", self.handleMousePressed)
    self:connect("term_resize", self.handleResize)
    self:connect("terminate", self.handleTerminate)
  end

  function View:draw()
    term.clear()
    term.setCursorPos(1, 1)

    local cx, cy = term.getCursorPos()
    local tc = term.getTextColor()
    local tb = term.getBackgroundColor()

    -- TODO: Render Store Apps
    local l = "Comming Soon"
    term.setCursorPos(self.Width - string.len(l) / 2, self.Height / 2)
    term.write(l)

    term.setCursorPos(cx, cy)
    term.setTextColor(tc)
    term.setBackgroundColor(tb)
  end

  return View
end
