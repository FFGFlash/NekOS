function main()
  display.clear()
  display.setCursorPos(1, 1)

  local W, H = display.getSize()
  local VIEW_H = H - 1

  local lines = {}
  local scroll = 0
  local curLine = ""
  local curFg = colors.white

  local history = {}

  local function maxScroll()
    return math.max(0, #lines - VIEW_H)
  end

  local function flushLine()
    local text = curLine
    curLine = ""
    if text == "" then
      lines[#lines + 1] = { text = "", fg = curFg }
      return
    end
    while #text > 0 do
      lines[#lines + 1] = { text = text:sub(1, W), fg = curFg }
      text = text:sub(W + 1)
    end
  end

  local function redraw(inputStr)
    inputStr = inputStr or ""

    local total = #lines
    local bottom = total - scroll
    local top = bottom - VIEW_H + 1

    display.setCursorBlink(false)

    for row = 1, VIEW_H do
      local idx = top + row - 1
      display.setCursorPos(1, row)
      display.clearLine()
      if idx >= 1 and idx <= total then
        local entry = lines[idx]
        display.setTextColor(entry.fg)
        display.write(entry.text)
      end
    end

    display.setCursorPos(1, H)
    display.clearLine()

    local indicatorWidth = 0
    if scroll > 0 then
      local indicator = " ↑" .. scroll
      indicatorWidth = #indicator
      display.setCursorPos(W - indicatorWidth + 1, H)
      display.setTextColor(colors.gray)
      display.write(indicator)
    end

    display.setCursorPos(1, H)
    display.setTextColor(colors.lime)
    display.write("NekOS> ")

    local maxInput = W - 6 - indicatorWidth
    local displayInput = inputStr
    if #displayInput > maxInput then
      displayInput = displayInput:sub(-maxInput)
    end
    display.setTextColor(colors.white)
    display.write(displayInput)

    display.setCursorPos(7 + #displayInput, H)
    display.setCursorBlink(true)
    display.setTextColor(colors.white)
  end

  local function cls()
    display.clear(); display.setCursorPos(1, 1)
  end

  local function color(c) curFg = c end
  local function reset() curFg = colors.white end

  local function write(text, fg)
    if fg then curFg = fg end
    curLine = curLine .. tostring(text)
  end

  local function println(text, fg)
    if fg then curFg = fg end
    local str = tostring(text or "")
    local first = true
    for segment in (str .. "\n"):gmatch("([^\n]*)\n") do
      if not first then flushLine() end
      first = false
      curLine = curLine .. segment
    end
    flushLine()
    if scroll == 0 then redraw() end
  end

  local function scrollUp(n)
    scroll = math.min(maxScroll(), scroll + (n or 1))
    redraw()
  end

  local function scrollDown(n)
    scroll = math.max(0, scroll - (n or 1))
    redraw()
  end

  local function scrollToBottom()
    scroll = 0
    redraw()
  end

  local function cls()
    lines = {}
    scroll = 0
    curLine = ""
    curFg = colors.white
    display.clear()
    redraw()
  end

  local function readLine()
    local line = ""
    local histIdx = 0
    local saved = ""
    local done = false

    scroll = 0
    redraw(line)

    local function onChar(ch)
      line = line .. ch
      redraw(line)
    end

    local function onKey(key)
      if key == keys.enter then
        done = true
      elseif key == keys.backspace then
        if #line > 0 then
          line = line:sub(1, -2)
          redraw(line)
        end
      elseif key == keys.up then
        if histIdx < #history then
          if histIdx == 0 then saved = line end
          histIdx = histIdx + 1
          line = history[histIdx]
          redraw(line)
        end
      elseif key == keys.down then
        if histIdx > 0 then
          histIdx = histIdx - 1
          line = histIdx == 0 and saved or history[histIdx]
          redraw(line)
        end
      elseif key == keys.pageUp then
        scrollUp(VIEW_H)
        redraw(line)
      elseif key == keys.pageDown then
        scrollDown(VIEW_H)
        redraw(line)
      elseif key == keys.home then
        scrollToBottom()
        redraw(line)
      end
    end

    local function onMouseScroll(_, _, dir)
      if dir == -1 then
        scrollUp(3)
      else
        scrollDown(3)
      end
      redraw(line)
    end

    event.subscribe("char", onChar)
    event.subscribe("key", onKey)
    event.subscribe("mouse_scroll", onMouseScroll)

    while not done do
      __kernel.yield(nil)
    end

    event.unsubscribe("char", onChar)
    event.unsubscribe("key", onKey)
    event.unsubscribe("mouse_scroll", onMouseScroll)

    local trimmed = line:match("^%s*(.-)%s*$")

    if #trimmed > 0 then
      table.insert(history, 1, trimmed)
      if #history > 200 then history[201] = nil end

      curFg   = colors.lime
      curLine = "ccOS> "
      curFg   = colors.white
      curLine = curLine .. trimmed
      flushLine()
    end

    scroll = 0
    return trimmed
  end

  local cmds = {}

  cmds.help = function(_)
    color(colors.yellow); println("Commands:"); reset()
    local list = {
      "install <user/repo> [tag]    install from GitHub",
      "install <user/repo@tag>      install specific version",
      "remove  <user/repo> [ver]    uninstall (all versions if ver omitted)",
      "update  <user/repo> [tag]    update to latest or specific tag",
      "list                          list all installed packages",
      "info    <user/repo> [ver]    show package details",
      "launch  <user/repo> [ver]    launch app",
      "checkup <user/repo>          check for newer release",
      "ps                            list running processes",
      "kill    <pid>                 terminate a process",
      "ls      [path]                list files in your data dir",
      "cat     <path>                read a file from your data dir",
      "clear                         clear screen",
    }
    for _, l in ipairs(list) do println("  " .. l) end
  end

  cmds.install = function(a)
    -- Support both "install user/repo@tag" and "install user/repo tag"
    local spec = a[1]
    if not spec then
      println("usage: install <user/repo> [tag]"); return
    end
    local repo, tag = spec:match("^(.-)@(.+)$")
    if not repo then
      repo = spec; tag = a[2]
    end
    println("Installing " .. repo .. (tag and ("@" .. tag) or " (latest)") .. " …")
    local ok, err = pkgman.install(repo, tag)
    if ok then
      color(colors.lime); println("Done."); reset()
    else
      color(colors.red); println("Error: " .. tostring(err)); reset()
    end
  end

  cmds.remove = function(a)
    if not a[1] then
      println("usage: remove <n> [version]"); return
    end
    local ok, err = pkgman.remove(a[1], a[2])
    if ok then println("Removed.") else println("Error: " .. tostring(err)) end
  end

  cmds.update = function(a)
    if not a[1] then
      println("usage: update <n> [tag]"); return
    end
    println("Updating " .. a[1] .. " …")
    local ok, err = pkgman.update(a[1], a[2])
    if ok then
      color(colors.lime); println("Updated."); reset()
    else
      color(colors.red); println("Error: " .. tostring(err)); reset()
    end
  end

  cmds.list = function(_)
    local apps = pkgman.list()
    if #apps == 0 then
      println("Nothing installed."); return
    end
    color(colors.yellow)
    println(string.format("%-16s %-10s %-5s %s", "NAME", "VERSION", "NATV", "REPO"))
    println(string.rep("-", 58))
    reset()
    for _, a in ipairs(apps) do
      if a.hasNative then color(colors.orange) end
      println(string.format("%-16s %-10s %-5s %s",
        a.name or a.repo, a.version, a.hasNative and "[!]" or "", a.repo))
      if a.hasNative then reset() end
    end
    color(colors.gray); println("[!] = requests native (full CC access)"); reset()
  end

  cmds.info = function(a)
    if not a[1] then
      println("usage: info <user/repo> [ver]"); return
    end
    local repo = a[1]
    local info = pkgman.info(repo, a[2])
    if not info then
      println(repo .. " not installed"); return
    end
    local function showEntry(ver, e)
      color(colors.yellow); println("  " .. repo .. "@" .. ver); reset()
      println("    name:  " .. (e.name or repo))
      println("    entry: " .. (e.entrypoint or "main.lua"))
      println("    caps:  " .. table.concat(e.capabilities or {}, ", "))
      if e.minOSVersion then println("    minOS: " .. e.minOSVersion) end
      if e.hasNative then
        color(colors.orange); println("    [native access]"); reset()
      end
    end
    -- Single version entry has a `name` string field; a versions table has version-string keys
    if type(info.name) == "string" then
      showEntry(a[2] or "?", info)
    else
      for ver, entry in pairs(info) do showEntry(ver, entry) end
    end
  end

  cmds.launch = function(a)
    if not a[1] then
      println("usage: launch <n> [ver] [args…]"); return
    end
    local name = a[1]; local ver = a[2]
    local args = {}
    for i = 3, #a do args[#args + 1] = a[i] end
    local ok, r = pkgman.launch(name, ver, #args > 0 and args or nil)
    if ok then
      color(colors.lime); println("PID " .. tostring(r)); reset()
    else
      color(colors.red); println("Error: " .. tostring(r)); reset()
    end
  end

  cmds.checkup = function(a)
    if not a[1] then
      println("usage: checkup <n>"); return
    end
    local tag, err = pkgman.checkUpdate(a[1])
    if err then
      println("Error: " .. err)
    elseif tag then
      color(colors.yellow)
      println("Update available: " .. a[1] .. "@" .. tag)
      println("  run: update " .. a[1])
      reset()
    else
      println("Up to date.")
    end
  end

  cmds.ps = function(_)
    local procs = process.list()
    table.sort(procs, function(a, b) return a.pid < b.pid end)
    color(colors.yellow)
    println(string.format("%-4s  %-16s %s", "PID", "NAME", "VER"))
    println(string.rep("-", 35))
    reset()
    for _, p in ipairs(procs) do
      println(string.format("%-4s  %-16s %s", p.pid, p.name, p.version or ""))
    end
  end

  cmds.kill = function(a)
    local pid = tonumber(a[1])
    if not pid then
      println("usage: kill <pid>"); return
    end
    process.kill(pid); println("Killed " .. pid)
  end

  cmds.ls = function(a)
    local path = a[1] or ""
    local list, err = fs.list(path)
    if not list then
      println("Error: " .. tostring(err)); return
    end
    for _, name in ipairs(list) do
      local full = path == "" and name or (path .. "/" .. name)
      local isdir = fs.isDir(full)
      if isdir then color(colors.cyan) end
      display.write(name .. (isdir and "/" or "") .. "  ")
      if isdir then reset() end
    end
    local _, cy = display.getCursorPos()
    display.setCursorPos(1, cy + 1)
  end

  cmds.cat = function(a)
    if not a[1] then
      println("usage: cat <path>"); return
    end
    local data, err = fs.read(a[1])
    if not data then
      println("Error: " .. tostring(err)); return
    end
    println(data)
  end

  cmds.clear = cls

  cls()
  color(colors.yellow)
  println("╔══════════════════════════════╗")
  println("║  NekOS v1.0  microkernel OS  ║")
  println("╚══════════════════════════════╝")
  color(colors.gray)
  println("Capabilities are apps. Type 'help'.")
  println("")
  reset()

  while true do
    local line = readLine()
    if #line == 0 then goto continue end

    local parts = {}
    for p in line:gmatch("%S+") do parts[#parts + 1] = p end
    local cmd = table.remove(parts, 1)

    if cmds[cmd] then
      local ok, err = pcall(cmds[cmd], parts)
      if not ok then
        color(colors.red); println("Error: " .. tostring(err)); reset()
      end
    else
      local targetRepo = nil
      if cmd:find("/") then
        if pkgman.info(cmd) then targetRepo = cmd end
      else
        for _, entry in ipairs(pkgman.list()) do
          if entry.name == cmd then
            targetRepo = entry.repo; break
          end
        end
      end

      if targetRepo then
        cmd.launch({ targetRepo, table.unpack(parts) })
      else
        color(colors.red)
        println("Unknown: " .. cmd .. " (try 'help' or 'list')")
        reset()
      end
    end

    ::continue::
  end
end

local M = {}

function M.version()
  return "NekOS shell 1.0"
end

return M
