local t = native.term

local M = {}

function M.write(text) t.write(tostring(text)) end

function M.clear() t.clear() end

function M.clearLine() t.clearLine() end

function M.scroll(n) t.scroll(n) end

function M.setCursorPos(x, y) t.setCursorPos(x, y) end

function M.getCursorPos() return t.getCursorPos() end

function M.getSize() return t.getSize() end

function M.setCursorBlink(b) t.setCursorBlink(b) end

function M.getCursorBlink() return t.getCursorBlink() end

function M.isColor() return t.isColor() end

function M.setTextColor(c) t.setTextColor(c) end

function M.setBackgroundColor(c) t.setBackgroundColor(c) end

function M.getTextColor() return t.getTextColor() end

function M.getBackgroundColor() return t.getBackgroundColor() end

function M.blit(text, fg, bg) t.blit(text, fg, bg) end

function M.setPaletteColor(c, r, g, b) t.setPaletteColor(c, r, g, b) end

function M.getPaletteColor(c) return t.getPaletteColor(c) end

function M.print(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  local _, cy = t.getCursorPos()
  t.write(table.concat(parts, "\t"))
  t.setCursorPos(1, cy + 1)
end

function M.printColor(color, ...)
  local prev = t.getTextColor()
  t.setTextColor(color)
  M.print(...)
  t.setTextColor(prev)
end

return M
