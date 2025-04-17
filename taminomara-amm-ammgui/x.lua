local function closingCoro(id, shouldFail)
    local _ <close> = setmetatable({}, {
        __close = function(self, err)
            print(string.format("Closing coroutine %s, err=%s", id, err))
        end,
    })

    sleep(1)

    if shouldFail then
        error("error")
    end
end

local function manuallyClosingCoro(...)
    local args = { ... }
    local co = coroutine.create(closingCoro)
    while coroutine.status(co) ~= "dead" do
        local res = { coroutine.resume(co, table.unpack(args)) }
        if res[1] then
            args = { coroutine.yield(table.unpack(res, 2, #res)) }
        end
    end
    coroutine.close(co)
end

-- future.addTask(async(closingCoro, "success", false))
-- future.addTask(async(closingCoro, "error", true))
future.addTask(async(manuallyClosingCoro, "success+wrapped", false))
-- future.addTask(async(manuallyClosingCoro, "error+wrapped", true))
future.loop()
