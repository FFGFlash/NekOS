function shell.complete(text)
  local arr = string.split(text, " ")
  if string.endsWith(text, " ") then table.insert(arr, "") end
  local index = #arr - 1
  if index == 0 then return shell.completeProgram(text)
  elseif index < 0 then return {} end
  local path = shell.resolveProgram(arr[1])
  local info = shell.getCompletionInfo()
  local func = (info[path] or info["/"..path]).fnComplete
  return func(shell, index, table.remove(arr, index + 1), arr)
end

return shell
