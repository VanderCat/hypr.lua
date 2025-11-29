local DEBUG = false

local socket = require "posix.sys.socket"
local unistd = require "posix.unistd"
local env = require "env"

local function _debugPrint(...)
end
if DEBUG then
    _debugPrint = function(...)
        local dbg = debug.getinfo(2, "l");
        print("[hypr.lua] line "..dbg.currentline..": "..table.concat({...}, " "))
    end
end
local hypr = {}
local path = env.XDG_RUNTIME_DIR.."/hypr/"..env.HYPRLAND_INSTANCE_SIGNATURE.."/"
function hypr:connect()
    _debugPrint("connecting")
    local fd2 = assert(socket.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0))
    _debugPrint("created fd2")
    assert(socket.connect(fd2, {family=socket.AF_UNIX, path = path..".socket2.sock"}))
    _debugPrint("fd2 connected")
    return setmetatable({
        _socket2 = fd2,
        _funclist = {}
    }, self)
end

function hypr:__index(index) 
    if not hypr[index] then
        return function(self1, ...)
            return hypr.ctl(self1, index, ...)
        end
    end
    return hypr[index]
end

function hypr:on(name, func)
    _debugPrint("added event "..name)
    local fl = self._funclist;
    fl[name] = fl[name] or {}
    local index = #fl[name]+1
    fl[name][index] = func;
    return index
end

function hypr:remove(name, index)
    _debugPrint("removed event "..name)
    local fl = self._funclist
    if not fl[name] then return end
    error("not implemented")
end

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function parseEventLine(str)
    _debugPrint("parsing "..str)
    local t1 = split(str, ">>")
    local name = t1[1]
    local args = split(t1[2], ",")
    return {name=name, args=args}
end

--TODO: poll more
function hypr:poll(maxbytes)
    _debugPrint("polling")
    maxbytes = maxbytes or 1024
    self._buffer = self._buffer or ""
    local result = assert(socket.recv(self._socket2, maxbytes));
    local events = {}
    _debugPrint("parsing events")
    for index, value in ipairs(split(result, "\n")) do
        events[index] = parseEventLine(value)
    end
    local list1 = self._funclist["*"] or {}
    for _, event in pairs(events) do
        local list = self._funclist[event.name] or {}
        for i, func in ipairs(list) do
            _debugPrint("executing event handler #"..i)
            func(table.unpack(event.args))
        end
        for i, func in ipairs(list1) do
            _debugPrint("executing global event handler #"..i)
            func(event.name, table.unpack(event.args))
        end
    end
end

function hypr:close()
    _debugPrint("shutting down...")
    unistd.close(self._socket2)
    _debugPrint("closed socket2")
    self._funclist = {}
    self._socket2 = nil
    self._socket = nil
end

local json = require "json"

function hypr:ctl(name, ...)
    self:_setupsock1()
    local cmd = "j/"..name
    for _, value in ipairs({...}) do
        cmd = cmd.." "..tostring(value).."\n"
    end
    _debugPrint("sending command "..cmd)
    assert(socket.send(self._socket, cmd))
    _debugPrint("awaiting response...")
    local result = assert(socket.recv(self._socket, 8192))
    self:_endsock1();
    if result == "ok" then
        _debugPrint("returned ok")
        return nil
    end
    if result == "unknown request" then
        error(result)
    end
    _debugPrint("returned"..result..", decoding")
    return json.decode(result)
end

function hypr:_setupsock1()
    local fd = assert(socket.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0))
    _debugPrint("created fd")
    assert(socket.connect(fd, {family=socket.AF_UNIX, path = path..".socket.sock"}))
    _debugPrint("fd connected")
    self._socket  = fd
end

function hypr:_endsock1()
    unistd.close(self._socket)
    _debugPrint("closed socket")
end

return hypr