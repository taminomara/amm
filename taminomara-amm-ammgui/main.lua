-- local gpu = computer.getPCIDevices(classes.FINComputerGPUT2)[1] --[[ @as FINComputerGPUT2 ]]
-- local screen = computer.getPCIDevices(classes.FINComputerScreen)[1] --[[ @as FINComputerScreen ]]
-- gpu:bindScreen(screen)

local dom = require "ammgui.dom.block"
local idom = require "ammgui.dom.inline"
local com = require "ammgui.component.block"
local icom = require "ammgui.component.inline"

local component = nil

computer.promote()
print("start")

local start = computer.millis()
local i = 0
while true do
    i = i + 1
    if i > 10000 then
        i = 0
        local now = computer.millis()
        print((now - start) / 10000)
        start = now
    end

    local div = dom.p {
        " is simply dummy text of the printing and typesetting industry. ",
        "Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, ",
        "when an unknown printer took a galley of type and scrambled it to make a type ",
        "specimen book. It has survived not only five centuries, but also the leap into ",
        "electronic typesetting, remaining essentially unchanged. It was popularised ",
        "in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, ",
        "and more recently with desktop publishing software like Aldus PageMaker ",
        "including versions of ",
        " is simply dummy text of the printing and typesetting industry. ",
        "Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, ",
        "when an unknown printer took a galley of type and scrambled it to make a type ",
        "specimen book. It has survived not only five centuries, but also the leap into ",
        "electronic typesetting, remaining essentially unchanged. It was popularised ",
        "in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, ",
        "and more recently with desktop publishing software like Aldus PageMaker ",
        "including versions of ",
        " is simply dummy text of the printing and typesetting industry. ",
        "Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, ",
        "when an unknown printer took a galley of type and scrambled it to make a type ",
        "specimen book. It has survived not only five centuries, but also the leap into ",
        "electronic typesetting, remaining essentially unchanged. It was popularised ",
        "in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, ",
        "and more recently with desktop publishing software like Aldus PageMaker ",
        "including versions of ",
        " is simply dummy text of the printing and typesetting industry. ",
        "Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, ",
        "when an unknown printer took a galley of type and scrambled it to make a type ",
        "specimen book. It has survived not only five centuries, but also the leap into ",
        "electronic typesetting, remaining essentially unchanged. It was popularised ",
        "in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, ",
        "and more recently with desktop publishing software like Aldus PageMaker ",
        "including versions of ",
        " is simply dummy text of the printing and typesetting industry. ",
        "Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, ",
        "when an unknown printer took a galley of type and scrambled it to make a type ",
        "specimen book. It has survived not only five centuries, but also the leap into ",
        "electronic typesetting, remaining essentially unchanged. It was popularised ",
        "in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, ",
        "and more recently with desktop publishing software like Aldus PageMaker ",
        "including versions of ",
    }
    component = com.Component.syncOne(component, div)
    if component.outdated then
        local tms = icom.TextMeasuringService:New()
        component:prepareLayout(gpu, tms)
        tms:run(gpu)
        component:calculateIntrinsicLayout(gpu)
        component:calculateLayout(gpu, { x = 1000, y = 500 })
        -- component.outdated = false
    end
    -- component:draw(gpu)
    -- gpu:flush()
end
