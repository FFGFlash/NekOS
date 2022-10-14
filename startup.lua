os.pullEvent = os.pullEventRaw

term.clear()
term.setCursorPos(1, 1)

_G.api = require("/api")
api:load()

local c, t, w, h = 0, 0, term.getSize()
local l = "///NekOS///"

term.setTextColor(system:getColor("nekos.text_color"))
term.setBackgroundColor(system:getColor("nekos.background_color"))
term.clear()

term.setCursorPos(math.floor((w - string.len(l)) / 2), math.floor(h / 2))
for i = 1, string.len(l) do
  term.blit(string.sub(l, i, i), string.sub(string.gsub("edb00000bde", "0", system:getColorBlit("nekos.text_color")), i, i), system:getColorBlit("nekos.background_color"))
  sleep(1 / 5)
end

sleep(1)

if system:get("nekos.auto_update") then
  local s,e = true, "Checking for Updates"
  term.setCursorPos(math.floor((w - string.len(e)) / 2), math.floor(h / 2 + 2))
  term.clearLine()
  term.write(e)

  s, e = system:update()

  term.setCursorPos(math.floor((w - string.len(e)) / 2), math.floor(h / 2 + 2))
  term.clearLine()
  term.write(e)

  sleep(3)

  if s then
    os.reboot()
  end
end

term.clear()
term.setCursorPos(1, 1)

system:startup()

local user = system:getUser()
app:run("NekOS", user)
