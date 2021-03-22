#!/usr/bin/env lua

local socket = require("socket")
local json = require("luci.jsonc")
local udp = assert(socket.udp())

for k,v in ipairs(arg) do -- copied from prometheus-node-exporter
  if (v == "-b") or (v == "--bind") then
    bind = arg[k+1]
  end
  if (v == "-p") or (v == "--port") then
    port = arg[k+1]
  end
  if (v == "-c") or (v == "--connect") then
    connect = arg[k+1]
  end
  if (v == "-s") or (v == "--secret") then
    secret = arg[k+1]
  end
  if (v == "--prefix") then
    prefix = arg[k+1]
  end
  if (v == "--path") then
    path = arg[k+1]
  end
end

local jsondata = luci.jsonc.stringify({ secret=secret, prefix=prefix, path=path })

udp:settimeout(0)
udp:setsockname(bind, port)
udp:sendto(jsondata, connect, port)
