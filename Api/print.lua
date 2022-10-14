local Print = print

return function(...)
  os.queueEvent("print", ...)
  return Print(...)
end
