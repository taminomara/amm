local class = require "ammcore.class"
local log = require "ammcore.log"
local array = require "ammcore._util.array"

--- GUI component.
---
--- !doctype module
--- @class ammgui.component
local ns = {}

local logger = log.Logger:New()

--- Base for all GUI components.
---
--- @class ammgui.component.Component: ammcore.class.Base
ns.Component = class.create("Component")

--- @generic T: ammgui.component.Component
--- @param self T
--- @return T
function ns.Component:New(key)
    self = class.Base.New(self)

    --- Key for synchronizing arrays of nodes.
    ---
    --- @package
    --- @type integer | string | nil
    self.key = key

    --- Indicates that this component's state has changed,
    --- and its needs a layout recalculation.
    ---
    --- New components are always created as `dirty`.
    ---
    --- @package
    --- @type boolean
    self.dirty = true

    --- Extrinsic width of the component.
    ---
    --- @type nil | "px" | "%" | "min-content" | "max-content" | "fix-content"
    self.width = nil

    --- Numeric value for cases when `width` is ``px`` or ``%``.
    ---
    --- @type number?
    self.widthValue = nil

    --- Extrinsic height of the component.
    ---
    --- @type nil | "px" | "%"
    self.height = nil

    --- Numeric value for cases when `height` is ``px`` or ``%``.
    ---
    --- @type number?
    self.heightValue = nil

    return self
end

--- Called when component is initialized.
---
--- !doc abstract
--- @param data ammgui.component.Node user-provided component data.
function ns.Component:onMount(data)
    error("not implemented")
end

--- Called when component is updated.
---
--- If new data causes changes in layout, `onUpdate` handler should set `dirty`
--- to `true` to make sure that its layout is properly recalculated.
---
--- !doc abstract
--- @param data ammgui.component.Node user-provided component data.
function ns.Component:onUpdate(data)
    error("not implemented")
end

--- Called to estimate component's intrinsic dimensions.
---
--- This function is called when container needs to estimate component's dimensions
--- in order to pack all of its contents.
---
--- It should return dimensioins calculated for two cases:
---
--- - ``max-content``: maximum width that the content can take, i.e. width
---   of the container if nothing wraps;
--- - ``min-content``: minimum width that the content can take, i.e. width
---   of the container if every wrapping opportunity is taken.
---
--- !doc abstract
--- @param gpu FINComputerGPU
--- @return number widthMinContent minimal width this component can take.
--- @return number heightMinContent height this component will take when its width is minimal.
--- @return number widthMaxContent maximal width this component can take.
--- @return number heightMaxContent height this component will take when its width is maximal.
function ns.Component:calculateIntrinsicLayout(gpu)
    error("not implemented")
end

--- Called to finalize component's layout.
---
--- !doc abstract
--- @param gpu FINComputerGPU
--- @param width number width available to the container.
--- @param height number height available to the container.
--- @return number width width this component will actually take. If this number exceeds available width, the containing component will overflow.
--- @return number height height this component will actually take. If this number exceeds available height, the containing component will overflow.
function ns.Component:calculateLayout(gpu, width, height)
    error("not implemented")
end

--- Called to draw the component on screen.
---
--- Width and height are guaranteed to be same as were used with
--- the latest `calculateLayout` call.
---
--- !doc abstract
--- @param gpu FINComputerGPU
--- @param width number width available to the container.
--- @param height number height available to the container.
function ns.Component:draw(gpu, width, height)
    error("not implemented")
end

--- Sync one DOM node with its component.
---
--- @param component ammgui.component.Component? component that was
--- @param node ammgui.component.Node
--- @return ammgui.component.Component component
function ns.Component.syncOne(component, node)
    if component and node._component == component.__class then
        component:onUpdate(node)
    else
        component = node._component:New(node._key)
        component:onMount(node)
    end
    return component
end

--- Sync array of DOM nodes with their components.
---
--- This function mutates array of nodes in-place.
---
--- @param components ammgui.component.Component[]
--- @param nodes ammgui.component.Node | ammgui.component.Node[]
--- @return ammgui.component.Component[] components
--- @return boolean dirty
function ns.Component.syncAll(components, nodes)
    local dirty = false

    if nodes._isNode then
        -- This is a single node.
        nodes = { nodes }
    end

    local componentByKey = {}
    for i, component in ipairs(components) do
        local key = component.key or i
        if componentByKey[key] then
            logger:warning(
                "multiple components with the same key %q: %s, %s",
                key, componentByKey[key], component
            )
        else
            componentByKey[key] = component
        end
    end
    for i, node in ipairs(nodes) do
        local key = node._key or i
        ---@diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
        nodes[i] = ns.Component.syncOne(componentByKey[key], node)
        dirty = dirty or nodes[i].dirty
        componentByKey[key] = nil
    end

    return nodes, dirty
end

--- Base for DOM nodes.
---
--- @class ammgui.component.Node
--- @field package _isNode true
--- @field package _component ammgui.component.Component Component class asscociated with this node.
--- @field package _key integer | string | nil Key for synchronizing arrays of nodes.
--- @field package [string] any State for component.
--- @field package [integer] ammgui.component.Node Child elements.


--- A base class for containers that have multiple children.
---
--- @class ammgui.component.Container: ammgui.component.Component
ns.Container = class.create("Container")

function ns.Container:onMount(data)
    --- Child components.
    ---
    --- @private
    --- @type ammgui.component.Component[]
    self.children = {}

    self:onUpdate(data)
end

function ns.Container:onUpdate(data)
    self.children, self.dirty = self.syncAll(self.children, data)
end

return ns
