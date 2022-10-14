local Clear = clear

return function(...)
  os.queueEvent("clear", ...)
  Clear()
end
