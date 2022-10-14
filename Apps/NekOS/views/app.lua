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
    self.App:activate("store")
  end

  function View.checkBB(x1, y1, x2, y2, x, y)
    return x >= x1 and x < x2 and y >= y1 and y < y2
  end

  function View:build(path)
    self.Info = nil
    self.Path = path

    self:handleResize()
    self:connect("mouse_click", self.handleMousePressed)
    self:connect("term_resize", self.handleResize)
    self:connect("terminate", self.handleTerminate)

    self:refresh()
  end

  function View:draw()
    term.clear()
    term.setCursorPos(1, 1)

    local cx, cy = term.getCursorPos()
    local tc = term.getTextColor()
    local tb = term.getBackgroundColor()

    -- TODO: Render App
    local l = "Comming Soon"
    term.setCursorPos((self.Width - string.len(l)) / 2, self.Height / 2)
    term.write(l)

    term.setCursorPos(cx, cy)
    term.setTextColor(tc)
    term.setBackgroundColor(tb)
  end

  function View:refresh()
    local res = request:get("https://cc-nekos.herokuapp.com/api/apps", { path = self.Path })
    if not res then return false, "Unable to Get App Info" end
    self.Info = json:fromStream(res)
    return true
  end

  return View
end
