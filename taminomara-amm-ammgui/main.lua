local gui = require "ammgui"
local dom = require "ammgui.dom"
local stylesheet = require "ammgui.css.stylesheet"
local vec = require "ammgui._impl.vec"
local tabs = require "ammgui.dom.tabs"

Vec2 = vec.Vec2

event.ignoreAll()
event.clear()

-- log.Logger:New("ammgui"):setLevel(0)

local gpu = assert(computer.getPCIDevices(classes.FINComputerGPUT2)[1]) --[[ @as FINComputerGPUT2 ]]
local screen = assert(computer.getPCIDevices(classes.Build_ScreenDriver_C)[1]) --[[ @as Build_ScreenDriver_C ]]
-- local screen = assert(component.proxy("C81DA9E4492C2B7BB08C89BD7D585B4D")) --[[ @as FINComputerScreen ]]
local _ = gpu:bindScreen(screen)

computer.promote()

local text = dom.Functional(function(ctx, params)
    local x, setX = ctx:useState(0)
    print("Text refresh", params.text, x)
    return dom.p {
        style = { backgroundColor = "#202020" },
        onClick = function()
            setX(x + 1); return false
        end,
        params.text, " ", tostring(x),
    }
end)

local container = dom.Functional(function(ctx, params)
    local x, setX = ctx:useState(0)
    print("Container refresh", x)
    return dom.article {
        onClick = function()
            setX(x + 1); return false
        end,
        dom.h1 { "Hello! ", tostring(x) },
        dom.list(params),
        text { text = "C" },
    }
end)

local tab = dom.Functional(function(ctx, params)
    print("Root refresh")
    return container {
        text { text = "A" },
        text { text = "B" },
        dom.p { params.content },
    }
end)

local root = dom.Functional(function(ctx, params)
    local currentTab, setCurrentTab = ctx:useState(2)
    return tabs.TabsManual {
        small = true,
        additionalTabs = dom.button {
            onClick = function() setCurrentTab(1) end,
            "Go to 1"
        },
        currentTab = currentTab,
        setCurrentTab = setCurrentTab,
        {
            title = "Tab 1",
            key = 1,
            tab { content = "Tab 1" },
        },
        {
            title = "Tab 2",
            key = 2,
            tab { content = "Tab 2" },
        },
        {
            title = "Tab 3",
            key = 3,
            tab { content = "Tab 3" },
        }
    }
end)

local app = gui.App:New(gpu, root, { max = 10 })

app:addStyle(stylesheet.Stylesheet:New():addRule {
    ".X",
    width = 100,
    height = 100,
    backgroundColor = "#202020",
    outlineWidth = 1,
}:addRule {
    ".X:hover",
    backgroundColor = "#404040",
    -- width = 200,
})

local defer = require "ammcore.defer"
local ok, err = defer.xpcall(function()
    app:start()

    -- future.addTask(async(function()
    --     while true do
    --         app:setData { max = computer.millis() / 1000 }
    --         sleep(1)
    --     end
    -- end))

    future.loop()
end)

if not ok then
    print(err.message, err.trace)
end
