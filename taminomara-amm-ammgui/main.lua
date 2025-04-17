local log = require "ammcore.log"
local gui = require "ammgui"
local dom = require "ammgui.dom"
local stylesheet = require "ammgui.css.stylesheet"

event.ignoreAll()
event.clear()

log.Logger:New("ammgui"):setLevel(0)

local gpu = assert(computer.getPCIDevices(classes.FINComputerGPUT2)[1]) --[[ @as FINComputerGPUT2 ]]
-- local screen = assert(component.proxy("B600CC964F94C5F1FB63C3A7F1BEF281")) --[[ @as FINComputerScreen ]]
local screen = assert(computer.getPCIDevices(classes.Build_ScreenDriver_C)[1]) --[[ @as Build_ScreenDriver_C ]]
local _ = gpu:bindScreen(screen)

computer.promote()

local counter = dom.functional(function(ctx, params)
    local x, setX = ctx:useState(params.initial or 1)

    local flex = dom.flex { class = "drag-area" }
    for i = 1, 15 do
        local div = dom.flex { class = { "drag-target" }, dom.p { tostring(i) } }
        if i == x then
            table.insert(div.class --[[ @as string[] ]], "drag-target-active")
            div.isDraggable = true
            div.onDrag = function (pos, origin, modifiers, target)
                if target == 1 then
                    return "err"
                elseif target == 2 then
                    return "warn"
                elseif target then
                    return "ok"
                end
            end
            div.onDragEnd = function (pos, origin, modifiers, target)
                if target then
                    setX(target)
                end
            end
        else
            div.dragTarget = i
        end
        table.insert(flex, div)
    end

    return dom.flex { style = { justifyContent = "center", alignItems = "center", width = "100vw", height = "100vh", backgroundColor = "#224", padding = 10, }, flex }
end)

local app = gui.App:New(gpu, counter, {})

app:addStyle(
    stylesheet.Stylesheet:New()
    :addRule {
        ".drag-area",
        gap = 10,
        flexWrap = "wrap",
        backgroundColor = "#228",
    }
    :addRule {
        ".drag-target",
        width = 100,
        height = 100,
        outlineWidth = 1,
        backgroundColor = "#303030",
        justifyContent = "center",
        alignItems = "center",
    }
    :addRule {
        ".drag-target:hover",
        backgroundColor = "#404040",
    }
    :addRule {
        ".drag-target.drag-target-active",
        backgroundColor = "#309930"
    }
    -- :addRule {
    --     "h1",
    --     fontSize = "32pt",
    -- }
    -- :addRule {
    --     "button",
    --     width = 100,
    --     padding = 10,
    --     backgroundColor = "#303030",
    --     outlineWidth = 1,
    --     outlineRadius = "0.4em",
    -- }
    -- :addRule {
    --     "button:hover",
    --     backgroundColor = "#505050",
    -- }
    :addRule {
        ":drop:drop",
        backgroundColor = "#505050",
    }
    :addRule {
        ":drop:drop-ok",
        backgroundColor = "#506550",
    }
    :addRule {
        ":drop:drop-warn",
        backgroundColor = "#656550",
    }
    :addRule {
        ":drop:drop-err",
        backgroundColor = "#655050",
    })

-- app.stressMode = true

local defer = require "ammcore.defer"
local ok, err = defer.xpcall(function ()
app:start()
future.loop()
end)

if not ok then
    print(err.message, err.trace)
end
