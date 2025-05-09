local stylesheet = require "ammgui.css.stylesheet"
local dom = require "ammgui.dom"
local resize = require "ammgui.dom.resize"
local log = require "ammcore.log"
local class = require "ammcore.class"
local u = require "ammgui.css.units"
local eventManager = require "ammgui._impl.eventManager"
local resolved = require "ammgui._impl.css.resolved"

--- Developer panel.
---
--- !doctype module
--- @class ammgui._impl.devtools
local ns = {}

ns.style = stylesheet.Stylesheet:New()
    :addRule {
        "._amm__devtool",
        width = u.vw(100),
        height = u.vh(100),
    }
    :addRule {
        "._amm__devtool__section",
        flex = { 1, 1, 0 },
        flexDirection = "column",
        minHeight = u.rem(3.8),
    }
    :addRule {
        "._amm__devtool__section._amm__devtool__section-collapsed",
        flex = { 0, 0, 0 },
        flexDirection = "column",
        maxHeight = u.rem(1.9),
        minHeight = u.rem(1.9),
    }
    :addRule {
        "._amm__devtool__section-heading",
        margin = 0,
        padding = { u.rem(0.2), u.rem(0.5) },
        fontSize = u.rem(1.2),
        backgroundColor = "#202020",
        flex = { 0, 0, "auto" },
    }
    :addRule {
        "._amm__devtool__section-heading-flex",
        alignItems = "baseline",
    }
    :addRule {
        "._amm__devtool__section-heading-flex-element",
        flex = { 0, 0, "auto" },
    }
    :addRule {
        "._amm__devtool__section-heading-flex-sizer",
        flex = 1,
    }
    :addRule {
        "._amm__devtool__section-heading-toggle",
        padding = { 0, u.rem(0.5) },
        backgroundColor = "#303030",
        outlineRadius = u.rem(0.4),
        outlineWidth = 1,
        fontSize = u.rem(0.8),
        lineHeight = u.rem(1.2),
    }
    :addRule {
        "._amm__devtool__section-heading-toggle-active",
        backgroundColor = "#0e2a9c",
    }
    :addRule {
        "._amm__devtool__section-content",
        flex = { 1, 1, "auto" },
    }
    :addRule {
        "._amm__devtool__section-content-inner",
        minWidth = "max-content",
    }
    :addRule {
        "._amm__devtool__element",
        fontFamily = "monospace",
    }
    :addRule {
        "._amm__devtool__element-title",
        outlineRadius = u.em(0.3),
        margin = { u.rem(0.2), u.rem(0.5) },
        padding = { 0, u.rem(0.5) },
        textWrapMode = "nowrap",
    }
    :addRule {
        "._amm__devtool__element-title:hover",
        backgroundColor = "#303030",
    }
    :addRule {
        "._amm__devtool__element-title__selected._amm__devtool__element-title",
        backgroundColor = "#0e2a9c",
    }
    :addRule {
        "._amm__devtool__element-title__selected._amm__devtool__element-title:hover",
        backgroundColor = "#1435ba",
    }
    :addRule {
        "._amm__devtool__element-title__pre-selected",
        backgroundColor = "#303030",
    }
    :addRule {
        "._amm__devtool__element-tag",
        "._amm__devtool__element-param",
        "._amm__devtool__element-pseudoclasses",
        color = "#617ce6",
    }
    :addRule {
        "._amm__devtool__element-inline-content",
        margin = { u.rem(0.2), u.rem(0.5) },
        padding = { 0, u.rem(0.5) },
        width = "min-content",
        minWidth = u.percent(100),
    }
    :addRule {
        "._amm__devtool__layout-heading",
        marginTop = u.rem(0.4),
        marginBottom = 0,
        padding = { u.rem(0.2), u.rem(0.5) },
        fontSize = u.rem(1),
        backgroundColor = "#202020",
    }
    :addRule {
        "._amm__devtool__layout-section",
        fontFamily = "monospace",
        padding = { 0, u.rem(0.5) },
    }
    :addRule {
        "._amm__devtool__layout-no-elements",
        padding = { 0, u.rem(0.5) },
    }
    :addRule {
        "._amm__devtool__layout-rule-start",
        "._amm__devtool__layout-rule-end",
        "._amm__devtool__layout-selector-unused",
        color = "#737272",
    }
    :addRule {
        "._amm__devtool__layout-selector-theme",
        "._amm__devtool__layout-source",
        color = "#737272",
        fontSize = u.rem(0.7),
    }
    :addRule {
        "._amm__devtool__layout-selector-hipri",
        color = "#e66161",
        fontSize = u.rem(0.7),
    }
    :addRule {
        "._amm__devtool__layout-rule",
        paddingLeft = u.rem(0.5),
    }
    :addRule {
        "._amm__devtool__layout-property-name",
        color = "#617ce6",
    }
    :addRule {
        "._amm__devtool__layout-property-unused",
        color = "#737272",
    }
    :addRule {
        "._amm__devtool__layout-diagram",
        margin = "auto",
        width = u.percent(100),
        height = u.px(220),
    }

--- @class ammgui._impl.devtools.Element
--- @field id ammgui._impl.id.EventListenerId
--- @field name string?
--- @field inlineContent string?
--- @field classes string[]
--- @field pseudoclasses string[]
--- @field css ammgui._impl.css.resolved.Resolved
--- @field children ammgui._impl.devtools.Element[]
--- @field baseLayout ammgui._impl.layout.blockBase.BaseLayout?
--- @field usedLayout ammgui._impl.layout.blockBase.UsedLayout?

--- @param root ammgui._impl.devtools.Element
local function _annotations(root)
    local sep = (root.name and root.name:len() > 0) and " " or ""
    local list = dom.list({})
    if #root.classes > 0 then
        table.insert(list, sep)
        sep = " "
        table.insert(list, dom.span {
            class = "_amm__devtool__element-param", "class=\"",
        })
        table.insert(list, dom.span {
            class = "_amm__devtool__element-classes",
            table.concat(root.classes, " "),
        })
        table.insert(list, dom.span {
            class = "_amm__devtool__element-param", "\"",
        })
    end
    if #root.pseudoclasses > 0 then
        table.insert(list, sep)
        sep = " "
        table.insert(list, dom.span {
            class = "_amm__devtool__element-pseudoclasses",
            table.concat(root.pseudoclasses, " "),
        })
    end
    return list
end

--- @param params ammgui._impl.devtools._ElementParams
--- @return ammgui.dom.AnyNode
local function elementData(params)
    if params.root.name then
        return dom.list {
            dom.span { class = "_amm__devtool__element-tag", "<" },
            dom.span { class = "_amm__devtool__element-name", params.root.name },
            _annotations(params.root),
            dom.span { class = "_amm__devtool__element-tag", ">" },
        }
    else
        return log.pprint(params.root.inlineContent, true)
    end
end

--- @class ammgui._impl.devtools._ElementParams
--- @field root ammgui._impl.devtools.Element
--- @field depth integer
--- @field expandedIds table<ammgui._impl.id.EventListenerId, true>
--- @field tempExpandedIds table<ammgui._impl.id.EventListenerId, true>
--- @field selectedId ammgui._impl.id.EventListenerId?
--- @field preSelectedId ammgui._impl.id.EventListenerId?
--- @field setSelectedId fun(id: ammgui._impl.id.EventListenerId?)
--- @field setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)
--- @field setExpandedId fun(id: ammgui._impl.id.EventListenerId, e: boolean)

local element
--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._ElementParams
--- @return ammgui.dom.AnyNode
local function _element(ctx, params)
    local lastClickTime = ctx:useRef(0)

    if not params.root then
        return dom.list {}
    end

    local selected = params.root.id == params.selectedId
    local preSelected = params.root.id == params.preSelectedId
    local expanded = params.expandedIds[params.root.id] or params.tempExpandedIds[params.root.id] or false

    local div = dom.div {
        class = "_amm__devtool__element",
        dom.div {
            class = {
                "_amm__devtool__element-title",
                expanded and "_amm__devtool__element-title__expanded",
                selected and "_amm__devtool__element-title__selected",
                preSelected and "_amm__devtool__element-title__pre-selected",
            },
            dom.div {
                style = { paddingLeft = u.rem(params.depth * 0.5) },
                dom.span {
                    class = "_amm__devtool__element-arrow",
                    #params.root.children > 0 and
                    (expanded and "▼" or "▶")
                    or "-",
                },
                " ",
                elementData(params),
            },
            onMouseEnter = function()
                params.setHighlightedId(params.root.id, true, true, true, true)
            end,
            onMouseExit = function()
                params.setHighlightedId(nil)
            end,
            onClick = function()
                params.setSelectedId(params.root.id)

                local now = computer.millis()
                if now - lastClickTime.current < 300 then
                    params.setExpandedId(params.root.id, not expanded)
                end

                lastClickTime.current = now
            end,
        },
    }

    if expanded then
        for _, child in ipairs(params.root.children) do
            table.insert(
                div,
                element(
                    {
                        key = child.id,
                        root = child,
                        selectedId = params.selectedId,
                        preSelectedId = params.preSelectedId,
                        expandedIds = params.expandedIds,
                        tempExpandedIds = params.tempExpandedIds,
                        setSelectedId = params.setSelectedId,
                        setExpandedId = params.setExpandedId,
                        setHighlightedId = params.setHighlightedId,
                        depth = params.depth + 1,
                    }
                )
            )
        end
    end

    return div
end
element = dom.Functional(_element)

-- --- @class ammgui._impl.devtools.LayoutCanvasEventListener: ammgui._impl.eventListener.EventListener
-- ns.LayoutCanvasEventListener = class.create("LayoutCanvasEventListener", eventManager.EventListener)

-- --- @param setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)?
-- --- @param id ammgui._impl.id.EventListenerId?
-- --- @param kind "content"|"padding"|"outline"|"margin"
-- --- @param prevKind "content"|"padding"|"outline"|"margin"?
-- --- @param canvas ammgui._impl.devtools.LayoutCanvas
-- ---
-- --- !doctype classmethod
-- --- @generic T: ammgui._impl.devtools.LayoutCanvasEventListener
-- --- @param self T
-- --- @return T
-- function ns.LayoutCanvasEventListener:New(setHighlightedId, id, kind, prevKind, canvas)
--     self = eventManager.EventListener.New(self)

--     --- @type ammgui._impl.id.EventListenerId?
--     self.id = id

--     --- @type "content"|"padding"|"outline"|"margin"
--     self.kind = kind

--     --- @type "content"|"padding"|"outline"|"margin"?
--     self.prevKind = prevKind

--     --- @type fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)?
--     self.setHighlightedId = setHighlightedId

--     --- @type ammgui._impl.devtools.LayoutCanvas
--     self.canvas = canvas

--     return self
-- end

-- function ns.LayoutCanvasEventListener:onMouseEnter(pos, modifiers)
--     if self.id and self.setHighlightedId then
--         self.setHighlightedId(
--             self.id,
--             self.kind == "content",
--             self.kind == "padding",
--             self.kind == "outline",
--             self.kind == "margin"
--         )
--         self.canvas.hoverKind = self.kind
--     end
-- end

-- function ns.LayoutCanvasEventListener:onMouseExit(pos, modifiers)
--     if self.id and self.setHighlightedId then
--         if self.prevKind ~= nil then
--             self.setHighlightedId(
--                 self.id,
--                 self.prevKind == "content",
--                 self.prevKind == "padding",
--                 self.prevKind == "outline",
--                 self.prevKind == "margin"
--             )
--         else
--             self.setHighlightedId(nil)
--         end
--         self.canvas.hoverKind = self.prevKind
--     end
-- end

-- --- @class ammgui._impl.devtools.LayoutCanvas: ammgui.component.block.canvas.CanvasBase
-- LayoutCanvas = class.create("LayoutCanvas", dom.CanvasBase)

-- function LayoutCanvas:New()
--     self = dom.CanvasBase.New(self)

--     self._marginListener = ns.LayoutCanvasEventListener:New(nil, nil, "margin", nil, self)
--     self._marginListener.parent = self
--     self._outlineListener = ns.LayoutCanvasEventListener:New(nil, nil, "outline", "margin", self)
--     self._outlineListener.parent = self._marginListener
--     self._paddingListener = ns.LayoutCanvasEventListener:New(nil, nil, "padding", "outline", self)
--     self._paddingListener.parent = self._outlineListener
--     self._contentListener = ns.LayoutCanvasEventListener:New(nil, nil, "content", "padding", self)
--     self._contentListener.parent = self._paddingListener

--     self.hoverKind = nil

--     return self
-- end

-- function LayoutCanvas:prepareLayout(params, textMeasure)
--     local makeText = function(size)
--         if -1e-5 < size and size < 1e-5 then
--             return ""
--         else
--             return string.format("%0.2f", size)
--         end
--     end

--     self._contentListener.id = params.highlightedId
--     self._contentListener.setHighlightedId = params.setHighlightedId
--     self._paddingListener.id = params.highlightedId
--     self._paddingListener.setHighlightedId = params.setHighlightedId
--     self._outlineListener.id = params.highlightedId
--     self._outlineListener.setHighlightedId = params.setHighlightedId
--     self._marginListener.id = params.highlightedId
--     self._marginListener.setHighlightedId = params.setHighlightedId

--     self._outline = makeText(params.outline)

--     self._paddingTop = makeText(params.paddingTop)
--     self._paddingBottom = makeText(params.paddingBottom)
--     self._paddingLeft = makeText(params.paddingLeft)
--     self._paddingRight = makeText(params.paddingRight)

--     self._marginTop = makeText(params.marginTop)
--     self._marginBottom = makeText(params.marginBottom)
--     self._marginLeft = makeText(params.marginLeft)
--     self._marginRight = makeText(params.marginRight)

--     self._contentSize = string.format("%0.2f×%0.2f", params.contentSize.x, params.contentSize.y)

--     local setSize = function(name) return function(s) self[name] = s end end

--     --- @type ammgui._impl.vec.Vec2
--     self._outlineSize = nil
--     textMeasure:addRequest(self._outline, 10, false, setSize("_outlineSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._paddingTopSize = nil
--     textMeasure:addRequest(self._paddingTop, 10, false, setSize("_paddingTopSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._paddingBottomSize = nil
--     textMeasure:addRequest(self._paddingBottom, 10, false, setSize("_paddingBottomSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._paddingLeftSize = nil
--     textMeasure:addRequest(self._paddingLeft, 10, false, setSize("_paddingLeftSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._paddingRightSize = nil
--     textMeasure:addRequest(self._paddingRight, 10, false, setSize("_paddingRightSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._marginTopSize = nil
--     textMeasure:addRequest(self._marginTop, 10, false, setSize("_marginTopSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._marginBottomSize = nil
--     textMeasure:addRequest(self._marginBottom, 10, false, setSize("_marginBottomSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._marginLeftSize = nil
--     textMeasure:addRequest(self._marginLeft, 10, false, setSize("_marginLeftSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._marginRightSize = nil
--     textMeasure:addRequest(self._marginRight, 10, false, setSize("_marginRightSize"))
--     --- @type ammgui._impl.vec.Vec2
--     self._contentSizeSize = nil
--     textMeasure:addRequest(self._contentSize, 10, false, setSize("_contentSizeSize"))
-- end

-- function LayoutCanvas:draw(params, ctx, size)
--     local contentSize = Vec2:New(
--         math.max(100, self._contentSizeSize.x + 10),
--         self._contentSizeSize.y + 8,
--     )
--     local paddingSize = Vec2:New(
--         contentSize.x + 2 * math.max(self._paddingLeftSize.x, self._paddingRightSize.x, 25) + 20,
--         contentSize.y * 3,
--     )
--     local outlineSize = Vec2:New(
--         paddingSize.x + 2 * math.max(self._outlineSize.x, 25) + 20,
--         contentSize.y * 5,
--     )
--     local marginSize = Vec2:New(
--         outlineSize.x + 2 * math.max(self._marginLeftSize.x, self._marginRightSize.x, 25) + 20,
--         contentSize.y * 7,
--     )

--     local marginColor =
--         (not self.hoverKind or self.hoverKind == "margin")
--         and structs.Color { 0x44 / 0xff, 0x27 / 0xff, 0x24 / 0xff, 1 }
--         or structs.Color { 0x10 / 0xff, 0x10 / 0xff, 0x10 / 0xff, 1 }
--     local marginOutlineColor = structs.Color { 0xEC / 0xff, 0x8F / 0xff, 0x82 / 0xff, 1 }
--     self:_drawBox(ctx, marginSize, marginColor, marginOutlineColor, size)
--     ctx:pushEventListener((size - marginSize) * 0.5, marginSize, self._marginListener)

--     local outlineColor =
--         (not self.hoverKind or self.hoverKind == "outline")
--         and structs.Color { 0x4B / 0xff, 0x2D / 0xff, 0x08 / 0xff, 1 }
--         or structs.Color { 0x10 / 0xff, 0x10 / 0xff, 0x10 / 0xff, 1 }
--     local outlineOutlineColor = structs.Color { 0xC9 / 0xff, 0x85 / 0xff, 0x31 / 0xff, 1 }
--     self:_drawBox(ctx, outlineSize, outlineColor, outlineOutlineColor, size)
--     ctx:pushEventListener((size - outlineSize) * 0.5, outlineSize, self._outlineListener)

--     local paddingColor =
--         (not self.hoverKind or self.hoverKind == "padding")
--         and structs.Color { 0x3B / 0xff, 0x39 / 0xff, 0x4A / 0xff, 1 }
--         or structs.Color { 0x10 / 0xff, 0x10 / 0xff, 0x10 / 0xff, 1 }
--     local paddingOutlineColor = structs.Color { 0xA4 / 0xff, 0xA0 / 0xff, 0xC6 / 0xff, 1 }
--     self:_drawBox(ctx, paddingSize, paddingColor, paddingOutlineColor, size)
--     ctx:pushEventListener((size - paddingSize) * 0.5, paddingSize, self._paddingListener)

--     local contentColor =
--         (not self.hoverKind or self.hoverKind == "content")
--         and structs.Color { 0x17 / 0xff, 0x3D / 0xff, 0x4D / 0xff, 1 }
--         or structs.Color { 0x10 / 0xff, 0x10 / 0xff, 0x10 / 0xff, 1 }
--     local contentOutlineColor = structs.Color { 0x54 / 0xff, 0xA9 / 0xff, 0xCE / 0xff, 1 }
--     self:_drawBox(ctx, contentSize, contentColor, contentOutlineColor, size)
--     ctx:pushEventListener((size - contentSize) * 0.5, contentSize, self._contentListener)

--     ctx.gpu:drawText(
--         (size - marginSize) * 0.5 + Vec2:New( 5, 4 ), "Margin", 10, marginOutlineColor, false
--     )
--     ctx.gpu:drawText(
--         (size - outlineSize) * 0.5 + Vec2:New( 5, 4 ), "Outline", 10, outlineOutlineColor, false
--     )
--     ctx.gpu:drawText(
--         (size - paddingSize) * 0.5 + Vec2:New( 5, 4 ), "Padding", 10, paddingOutlineColor, false
--     )

--     ctx.gpu:drawText(
--         (size - self._contentSizeSize) * 0.5, self._contentSize, 10, contentOutlineColor, false
--     )

--     self:_drawText(ctx, paddingSize, Vec2:New( 0, -1 ), self._paddingTop, self._paddingTopSize,
--         paddingOutlineColor, size)
--     self:_drawText(ctx, paddingSize, Vec2:New( 0, 1 ), self._paddingBottom, self._paddingBottomSize,
--         paddingOutlineColor, size)
--     self:_drawText(ctx, paddingSize, Vec2:New( -1, 0 ), self._paddingLeft, self._paddingLeftSize,
--         paddingOutlineColor, size)
--     self:_drawText(ctx, paddingSize, Vec2:New( 1, 0 ), self._paddingRight, self._paddingRightSize,
--         paddingOutlineColor, size)

--     self:_drawText(ctx, outlineSize, Vec2:New( 0, -1 ), self._outline, self._outlineSize, outlineOutlineColor,
--         size)
--     self:_drawText(ctx, outlineSize, Vec2:New( 0, 1 ), self._outline, self._outlineSize, outlineOutlineColor,
--         size)
--     self:_drawText(ctx, outlineSize, Vec2:New( -1, 0 ), self._outline, self._outlineSize, outlineOutlineColor,
--         size)
--     self:_drawText(ctx, outlineSize, Vec2:New( 1, 0 ), self._outline, self._outlineSize, outlineOutlineColor,
--         size)

--     self:_drawText(ctx, marginSize, Vec2:New( 0, -1 ), self._marginTop, self._marginTopSize, marginOutlineColor,
--         size)
--     self:_drawText(ctx, marginSize, Vec2:New( 0, 1 ), self._marginBottom, self._marginBottomSize,
--         marginOutlineColor, size)
--     self:_drawText(ctx, marginSize, Vec2:New( -1, 0 ), self._marginLeft, self._marginLeftSize,
--         marginOutlineColor, size)
--     self:_drawText(ctx, marginSize, Vec2:New( 1, 0 ), self._marginRight, self._marginRightSize,
--         marginOutlineColor, size)
-- end

-- function LayoutCanvas:_drawBox(ctx, size, color, outlineColor, canvasSize)
--     ctx.gpu:drawBox {
--         position = canvasSize * 0.5,
--         size = size,
--         rotation = 0,
--         color = color,
--         image = "",
--         imageSize = Vec2:New( x = 0, y = 0 ),
--         hasCenteredOrigin = true,
--         horizontalTiling = false,
--         verticalTiling = false,
--         isBorder = false,
--         margin = { top = 0, right = 0, bottom = 0, left = 0 },
--         isRounded = true,
--         radii = structs.Vector4 { 0, 0, 0, 0 },
--         hasOutline = true,
--         outlineThickness = 1,
--         outlineColor = outlineColor - structs.Color { 0, 0, 0, 0.9 },
--     }
-- end

-- function LayoutCanvas:_drawText(ctx, size, direction, text, textSize, color, canvasSize)
--     local pos = 0.5 * (canvasSize + Vec2:New(
--         (size.x - 10) * direction.x - textSize.x * (direction.x + 1),
--         (size.y - 8) * direction.y - textSize.y * (direction.y + 1),
--     ))

--     ctx.gpu:drawText(pos, text, 10, color, false)
-- end

-- local layoutCanvas = dom.canvas(LayoutCanvas.New, LayoutCanvas)

local function selectors(cssRule, usedSelector)
    local result = dom.list {}

    if cssRule.compiledSelectors and #cssRule.compiledSelectors > 0 then
        for _, selector in ipairs(cssRule.compiledSelectors) do
            local repr = dom.list { dom.span { selector:repr() } }
            if selector.layer < 0 then
                table.insert(repr, dom.span {
                    class = "_amm__devtool__layout-selector-theme",
                    " theme",
                })
            elseif selector.layer > 0 then
                table.insert(repr, dom.span {
                    class = "_amm__devtool__layout-selector-hipri",
                    " layer ", tostring(selector.layer),
                })
            end
            if cssRule.loc then
                table.insert(repr, dom.span {
                    class = "_amm__devtool__layout-source",
                    " @ ", cssRule.loc,
                })
            end
            table.insert(result, dom.div {
                class = {
                    "_amm__devtool__layout-selector",
                    (usedSelector and selector ~= usedSelector) and "_amm__devtool__layout-selector-unused",
                },
                repr,
            })
        end
    else
        local repr = dom.list { dom.span { "<inline>" } }
        if cssRule.loc then
            table.insert(repr, dom.span {
                class = "_amm__devtool__layout-source",
                " @ ", cssRule.loc,
            })
        end
        table.insert(result, dom.div {
            class = "_amm__devtool__layout-selector",
            repr,
        })
    end

    return result
end

--- @param cssRule ammgui._impl.css.resolved.CompiledRule
--- @param keys string[]
--- @param seenProperties table<string, true>
--- @return ammgui.dom.ListNode
local function ruleData(cssRule, keys, seenProperties)
    local result = dom.list {}

    for _, k in ipairs(keys) do
        local seenClass = seenProperties[k] and "_amm__devtool__layout-property-unused" or false
        table.insert(result, dom.div {
            key = k,
            dom.span {
                class = { "_amm__devtool__layout-property-name", seenClass },
                k, " = ",
            },
            dom.span {
                class = { "_amm__devtool__layout-property-value", seenClass },
                log.pprint(cssRule[k], true),
            },
        })
        seenProperties[k] = true
    end

    return result
end

--- @param res ammgui._impl.css.resolved.Resolved
--- @return ammgui.dom.ListNode
local function rules(res)
    local result = dom.list {}

    if not res then
        return result
    end

    local context = res.context
    local contextSelectors = res.contextSelectors
    local seenProperties = {}
    for i = #context, 1, -1 do
        local cssRule = context[i]
        local keys = resolved.getRuleKeys(cssRule)
        if #keys > 0 then
            table.insert(result, dom.section {
                key = cssRule,
                dom.div { class = "_amm__devtool__layout-selectors", selectors(cssRule, contextSelectors[i]) },
                dom.div { class = "_amm__devtool__layout-rule-start", "{" },
                dom.div { class = "_amm__devtool__layout-rule", ruleData(cssRule, keys, seenProperties) },
                dom.div { class = "_amm__devtool__layout-rule-end", "}" },
            })
        end
    end

    return result
end

--- @class ammgui._impl.devtools._ElementDataParams
--- @field root ammgui._impl.devtools.Element?
--- @field setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)

--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._ElementDataParams
--- @return ammgui.dom.AnyNode
local function _elementData(ctx, params)
    if not params.root then
        return dom.article {
            key = "layout",
            class = "_amm__devtool__layout-no-elements",
            dom.p { "Select an element above" },
        }
    end

    local body = dom.article {}

    local baseLayout = params.root.baseLayout
    local usedLayout = params.root.usedLayout
    if baseLayout and usedLayout then
        local outline = baseLayout.outlineWidth

        local paddingTop = baseLayout.paddingTop
        local paddingBottom = baseLayout.paddingBottom
        local paddingLeft = baseLayout.paddingLeft
        local paddingRight = baseLayout.paddingRight

        local marginTop = baseLayout.marginTop or usedLayout.effectiveVerticalMargin.x
        local marginBottom = baseLayout.marginBottom or usedLayout.effectiveVerticalMargin.y
        local marginLeft = baseLayout.marginLeft or usedLayout.effectiveHorizontalMargin.x
        local marginRight = baseLayout.marginRight or usedLayout.effectiveHorizontalMargin.y

        local contentSize = usedLayout.resolvedContentSize

        table.insert(body, dom.h2 {
            key = "layout-heading",
            class = "_amm__devtool__layout-heading",
            "Layout",
        })
        table.insert(body, dom.article {
            key = "layout",
            class = "_amm__devtool__layout-section",
            -- layoutCanvas {
            --     class = "_amm__devtool__layout-diagram",
            --     highlightedId = params.root.id,
            --     setHighlightedId = params.setHighlightedId,
            --     outline = outline,
            --     paddingTop = paddingTop,
            --     paddingBottom = paddingBottom,
            --     paddingLeft = paddingLeft,
            --     paddingRight = paddingRight,
            --     marginTop = marginTop,
            --     marginBottom = marginBottom,
            --     marginLeft = marginLeft,
            --     marginRight = marginRight,
            --     contentSize = contentSize,
            -- },
        })
    end

    table.insert(body, dom.h2 {
        key = "css-heading",
        class = "_amm__devtool__layout-heading",
        "CSS Rules",
    })
    table.insert(body, dom.article {
        key = "css",
        class = "_amm__devtool__layout-section",
        rules(params.root.css),
    })

    return body
end
local elementData = dom.Functional(_elementData)

--- @class ammgui._impl.devtools._SectionParams: ammgui.dom.FunctionalParamsWithChildren

--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._SectionParams
--- @return ammgui.dom.AnyNode
local function _section(ctx, params)
    local collapsed, setCollapsed = ctx:useState(false)
    local lastClickTime = ctx:useRef(0)

    local body = dom.flex {
        class = {
            "_amm__devtool__section",
            collapsed and "_amm__devtool__section-collapsed",
        },
        dom.div {
            class = "_amm__devtool__section-heading",
            params[1],
            onClick = function()
                local now = computer.millis()
                if now - lastClickTime.current < 300 then
                    setCollapsed(not collapsed)
                end
                lastClickTime.current = now
            end,
        },
    }

    if not collapsed then
        table.insert(body, dom.scroll {
            class = "_amm__devtool__section-content",
            dom.div {
                class = "_amm__devtool__section-content-inner",
                params[2],
            },
        })
    end

    return body
end
local section = dom.Functional(_section)

--- @param root ammgui._impl.devtools.Element
--- @param id ammgui._impl.id.EventListenerId?
--- @param tempExpandedIds table<ammgui._impl.id.EventListenerId, true>
--- @return ammgui._impl.devtools.Element?
local function findSelected(root, id, tempExpandedIds)
    if not id then
        return nil
    end
    if root.id == id then
        return root
    else
        for _, child in ipairs(root.children) do
            local selected = findSelected(child, id, tempExpandedIds)
            if selected then
                tempExpandedIds[root.id] = true
                return selected
            end
        end
    end
    return nil
end

--- @class ammgui._impl.devtools._PanelParams
--- @field root ammgui._impl.devtools.Element
--- @field selectedId ammgui._impl.id.EventListenerId?
--- @field preSelectedId ammgui._impl.id.EventListenerId?
--- @field selectionEnabled boolean
--- @field setSelectionEnabled fun(enabled: boolean)
--- @field setSelectedId fun(id: ammgui._impl.id.EventListenerId?)
--- @field setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)

--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._PanelParams
--- @return ammgui.dom.AnyNode
local function panel(ctx, params)
    local expandedIds, setExpanded = ctx:useReducer(
        setmetatable({}, { __mode = "kv" }),
        function(t, id, set)
            t[id] = set or nil
            return t
        end
    )

    local selectedRoot = findSelected(params.root, params.selectedId, expandedIds)
    local tempExpandedIds = {}
    findSelected(params.root, params.preSelectedId, tempExpandedIds)

    return resize.Split {
        class = "_amm__devtool",
        direction = "column",
        section {
            dom.flex {
                class = "_amm__devtool__section-heading-flex",
                dom.span {
                    class = "_amm__devtool__section-heading-flex-element",
                    "Elements",
                },
                dom.div {
                    class = "_amm__devtool__section-heading-flex-sizer",
                },
                dom.span {
                    class = {
                        "_amm__devtool__section-heading-flex-element",
                        "_amm__devtool__section-heading-toggle",
                        params.selectionEnabled and "_amm__devtool__section-heading-toggle-active",
                    },
                    "Pick",
                    onClick = function()
                        params.setSelectionEnabled(not params.selectionEnabled)
                        return false
                    end,
                },
            },
            element {
                root = params.root,
                selectedId = params.selectedId,
                preSelectedId = params.preSelectedId,
                expandedIds = expandedIds,
                tempExpandedIds = tempExpandedIds,
                setSelectedId = params.setSelectedId,
                setExpandedId = setExpanded,
                setHighlightedId = params.setHighlightedId,
                depth = 0,
            },
        },
        section {
            "Style",
            elementData {
                root = selectedRoot,
                setHighlightedId = params.setHighlightedId,
            },
        },
    }
end
ns.panel = dom.Functional(panel)

return ns
