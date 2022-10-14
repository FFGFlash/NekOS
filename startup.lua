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

local p = peripheral.find("modem")
local v = os.getComputerID()
if not p or not p.isWireless() then
  local e = "Please attach a wireless modem."
  term.setCursorPos(math.floor((w - string.len(e)) / 2), math.floor(h / 2 + 2))
  term.clearLine()
  term.write(e)
  sleep(3)
  os.shutdown()
end
if not p.isOpen(v) then p.open(v) end
if not p.isOpen(65535) then p.open(65535) end

sleep(1)

if system:get("nekos.auto_update") then
  local s,e = true, "Updating..."
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

local user = system:getUser()
app:run("NekOS", user)
