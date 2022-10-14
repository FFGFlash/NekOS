function term.getWidth()
  return { term.getSize() }[1]
end

function term.getHeight()
  return { term.getSize() }[2]
end

function term.getCursorX()
  return { term.getCursorPos() }[1]
end

function term.getCursorY()
  return { term.getCursorPos() }[2]
end

function term.writeCentered(t, w, h)
  local x, y, W, H = term.getCursorPos(), term.getSize()
  w, h = w or W, h or H
  term.setCursorPos((x - 1) + (w - string.len(t)) / 2, (y - 1) + h / 2)
  term.write(t)
end

function term.writeNewline(t, r)
  local x,y = term.getCursorPos()
  term.write(t)
  term.setCursorPos(r and 1 or x,y + 1)
end

function term.table(t, w, s)
  local x, y, W = term.getCursorPos(), term.getWidth()
  w, s = w or W, s or 0
  local R, C = #t, 0
  for r = 1, R, 1 do C = math.max(C, #t[r]) end
  local cw, ch = w / C, 1 + s
  for r = 1, R, 1 do
    local Y = y + (r - 1) * ch
    for c = 1, C, 1 do
      term.setCursorPos(x + (c - 1) * cw, Y)
      if r == 1 then term.writeCentered(t[r][c], cw, 1)
      else term.write(t[r][c])
      end
    end
  end
  return cw, ch
end

return term
