local class = require "ammcore.class"

--- A service for batch-measuring sizes or rendered strings.
---
--- !doctype module
--- @class ammgui._impl.context.textMeasure
local ns = {}

--- Text measuring service.
---
--- Allows measuring dimensions of rendered strings in batch.
---
--- @class ammgui._impl.context.textMeasure.TextMeasure: ammcore.class.Base
ns.TextMeasure = class.create("TextMeasure")

--- !doctype classmethod
--- @generic T: ammgui._impl.context.textMeasure.TextMeasure
--- @param self T
--- @return T
function ns.TextMeasure:New()
    self = class.Base.New(self)

    --- @private
    --- @type { text: string, size: integer, monospace: boolean, cb: fun(size: ammgui.Vec2, baseline: number) }[]
    self._requests = {}

    return self
end

--- Request measure for a word.
---
--- @param text string
--- @param size integer
--- @param monospace boolean
--- @param cb fun(size: ammgui.Vec2, baseline: number)
function ns.TextMeasure:addRequest(text, size, monospace, cb)
    table.insert(self._requests, { text = text, size = size, monospace = monospace, cb = cb })
end

--- Measure all words and save results.
---
--- @param gpu FINComputerGPUT2
function ns.TextMeasure:run(gpu)
    if #self._requests == 0 then
        return
    end

    local text = {}
    local size = {}
    local monospace = {}

    for _, word in ipairs(self._requests) do
        table.insert(text, word.text)
        table.insert(size, word.size)
        table.insert(monospace, word.monospace)
    end

    local measured = gpu:measureTextBatch(text, size, monospace)
    local baselines = gpu:getFontBaselineBatch(size, monospace)

    for i = 1, #self._requests do
        self._requests[i].cb(measured[i], baselines[i])
    end

    self._requests = {}
end

return ns
