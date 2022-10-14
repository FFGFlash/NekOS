local Network = api(0, {
  {
    type = "choice",
    options = {
      lookup = {
        { name = "protocol", required = true },
        { name = "hostname" }
      },
      send = {
        { name = "receiver", required = true },
        { name = "event", required = true },
        { name = "...data" }
      },
      broadcast = {
        { name = "event", required = true },
        { name = "...data" }
      },
      request = {
        { name = "receiver", required = true },
        { name = "event", required = true },
        { name = "...data" }
      },
      protocol = {
        { name = "protocol", required = true },
        { type = "choice", options = {
          lookup = {
            { name = "hostname" }
          },
          send = {
            { name = "receiver", required = true },
            { name = "event", required = true },
            { name = "...data" }
          },
          broadcast = {
            { name = "event", required = true },
            { name = "...data" }
          },
          request = {
            { name = "receiver", required = true },
            { name = "event", required = true },
            { name = "...data" }
          }
        } }
      }
    }
  }
})

function Network:execute(action, ...)
  local args = { ... }
  local s, e = false, "Invalid Action"
  if action == "lookup" then
    s, e = self:lookup(table.unpack(args))
  elseif action == "send" then
    local receiver, event = tonumber(table.remove(args, 1)), table.remove(args, 1)
    s, e = self:send(receiver, event, nil, table.unpack(args))
  elseif action == "broadcast" then
    local event = table.remove(args, 1)
    s, e = self:broadcast(event, nil, table.unpack(args))
  elseif action == "request" then
    local receiver, event = table.remove(args, 1), table.remove(args, 1)
    s, e = self:request(receiver, event, nil, table.unpack(args))
  elseif action == "protocol" then
    local protocol, subaction = table.remove(args, 1), table.remove(args, 1)
    if subaction == "lookup" then
      s, e = self:lookup(protocol, table.unpack(args))
    elseif subaction == "send" then
      local receiver, event = tonumber(table.remove(args, 1)), table.remove(args, 1)
      s, e = self:send(receiver, event, protocol, table.unpack(args))
    elseif action == "broadcast" then
      local event = table.remove(args, 1)
      s, e = self:broadcast(event, protocol, table.unpack(args))
    elseif action == "request" then
      local receiver, event = table.remove(args, 1), table.remove(args, 1)
      s, e = self:request(receiver, event, protocol, table.unpack(args))
    end
  end
  print(e)
  if not s then
    self:printUsage()
  end
end

function Network:constructor()
  self:connect()
  self.RequestTimeout = 15

  function self:constructor(protocol, requestTimeout)
    local Network = self
    local network = { Protocol = protocol or "NekOS", RequestTimeout = requestTimeout or self.RequestTimeout, Hostname = nil }
    network.__index = network

    function network:__call(hostname)
      if hostname then
        local id = rednet.lookup(self.Protocol, hostname)
        if id then return false, "Hostname Already in Use" end
        rednet.host(self.Protocol, hostname)
        self.Hostname = hostname
      end
      return true, "Network Created Successfully"
    end

    function network:lookup(hostname)
      return Network:lookup(self.Protocol, hostname)
    end

    function network:broadcast(event, ...)
      return Network:broadcast(event, self.Protocol, ...)
    end

    function network:send(receiver, event, ...)
      return Network:send(receiver, event, self.Protocol, ...)
    end

    function network:request(receiver, event, ...)
      return Network:request(receiver, event, self.Protocol, ...)
    end

    return setmetatable(network, network)
  end

  function self:lookup(protocol, hostname)
    if not self.Connected then return false, "Invalid Network Connection" end
    if not protocol then return false, "Invalid Protocol" end
    return true, { rednet.lookup(protocol, hostname) }
  end

  function self:broadcast(event, protocol, ...)
    if not self.Connected then return false, "Invalid Network Connection" end
    if not event then return false, "Invalid Event" end
    rednet.broadcast({ event, ... }, protocol)
    return true, "Broadcast Sent"
  end

  function self:send(receiver, event, protocol, ...)
    if not self.Connected then return false, "Invalid Network Connection" end
    if not event then return false, "Invalid Event" end
    rednet.send(receiver, { event, ... }, protocol)
    return true, "Message Sent"
  end

  function self:request(receiver, event, protocol, ...)
    if not self.Connected then return false, "Invalid Network Connection" end
    if not event then return false, "Invalid Event" end
    rednet.send(receiver, { event, ... }, protocol)
    local id, res = -1, nil
    repeat id, res = rednet.receive(nil, self.RequestTimeout)
    until id == receiver or id == nil
    return id == receiver, id and res or "Request Timed Out"
  end
end

function Network:connect()
  self.Connected = false
  local ComputerId, Modems = os.getComputerID(), { peripheral.find("modem") }
  for i, modem in ipairs(Modems) do
    if modem.isWireless() then
      if not modem.isOpen(ComputerId) then modem.open(ComputerId) end
      if not modem.isOpen(65535) then modem.open(65535) end
      self.Connected = true
      break
    end
  end
  return self.Connected, self.Connected and "Network Connected" or "Failed to Connect"
end

Network:call(...)
return Network
