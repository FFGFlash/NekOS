local App = app()

function App:constructor(user)
  self:disconnectAll("terminate")
  self.Views = { List = {}, Active = nil }
  for _, view in ipairs(self:list("views")) do
    local name = string.match(fs.getName(view), "([^\.]+)")
    self.Views.List[name] = self:require("views/"..name)(self, user)
  end
  self:activate(not user.Username and "setup" or "login")
end

function App:activate(name)
  term.setTextColor(system:getColor("nekos.text_color"))
  term.setBackgroundColor(system:getColor("nekos.background_color"))

  if self.Views.Active then
    self.Views.Active:destroy()
  end

  if self.Views.List[name] then
    self.Views.Active = self.Views.List[name]
    self.Views.Active:build()
  end
end

function App:draw()
  if not self.Views.Active then
    return
  end

  self.Views.Active:draw()

  term.setTextColor(system:getColor("nekos.text_color"))
  term.setBackgroundColor(system:getColor("nekos.background_color"))
end

return App
