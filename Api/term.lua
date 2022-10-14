function term.getWidth()
  return { term.getSize() }[1]
end

function term.getHeight()
  return { term.getSize() }[2]
end

function term.writeCentered(t, w, h)
  local x, y, W, H = term.getCursorPos(), term.getSize()
  w, h = w or W, h or H
  term.setCursorPos((x - 1) + (w - string.len(t)) / 2, (y - 1) + h / 2)
  term.write(t)
end

return term
