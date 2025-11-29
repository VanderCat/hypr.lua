local env = {}
setmetatable(env, {
    __index = function(self, index)
        return os.getenv(index);
    end
})

return env