local Hypr = require "hypr"
local i = require "inspect"

local instance = Hypr:connect()

--print(i(instance:monitors()))

--instance:close()

--instance:on("*", print)

instance:on("closewindow", function(address)
    instance:notify(6, 4000, "rgb(255,0,255)", "Window("..address..") closed")
end)

while true do instance:poll() end