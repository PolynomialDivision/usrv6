#!/usr/bin/env lua

--[[
    Lua UDP Server
    Requirements:
        - luasocket
]]--

local socket = require("socket")
local udp = assert(socket.udp())
local json = require("luci.jsonc")
local ubus = require("ubus")
local u = ubus.connect()
local data

for k,v in ipairs(arg) do -- copied from prometheus-node-exporter
  if (v == "-p") or (v == "--port") then
    port = arg[k+1]
  end
  if (v == "-b") or (v == "--bind") then
    bind = arg[k+1]
  end
end

udp:settimeout(1)
assert(udp:setsockname(bind,port))

while true do
  data = udp:receive()
  if data then
    local jsonparsed = json.parse(data)
    local patharray = {}
    for p in string.gmatch(jsonparsed.path, "[^,]+") do table.insert(patharray, p) end
    local prefixes = u:call("usrv6s", "install", { secret = jsonparsed.secret, prefix=jsonparsed.prefix, path=patharray })
  end
end
