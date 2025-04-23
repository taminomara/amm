local log = require "ammcore.log"
local gui = require "ammgui"
local dom = require "ammgui.dom"
local stylesheet = require "ammgui.css.stylesheet"

event.ignoreAll()
event.clear()

-- log.Logger:New("ammgui"):setLevel(0)

local gpu = assert(computer.getPCIDevices(classes.FINComputerGPUT2)[1]) --[[ @as FINComputerGPUT2 ]]
-- local screen = assert(computer.getPCIDevices(classes.Build_ScreenDriver_C)[1]) --[[ @as Build_ScreenDriver_C ]]
local screen = assert(component.proxy("B600CC964F94C5F1FB63C3A7F1BEF281")) --[[ @as FINComputerScreen ]]
local _ = gpu:bindScreen(screen)

computer.promote()

local text = dom.functional(function (ctx, params)
    local x, setX = ctx:useState(0)
    print("Text refresh", params.text, x)
    return dom.p {
        onClick = function () setX(x + 1); return false end,
        params.text, " ", tostring(x)
    }
end)

local container = dom.functional(function (ctx, params)
    local x, setX = ctx:useState(0)
    print("Container refresh", x)
    return dom.div {
        onClick = function () setX(x + 1); return false end,
        dom.h1 { "Hello! ", tostring(x) },
        dom.list(params),
        text { text = "C", },
    }
end)

local root = dom.functional(function(ctx, params)
    print("Root refresh")
    return container {
        text { text = "A", },
        text { text = "B", },
    }
end)

local app = gui.App:New(gpu, root, {})

local defer = require "ammcore.defer"
local ok, err = defer.xpcall(function()
    app:start()
    future.loop()
end)

if not ok then
    print(err.message, err.trace)
end
