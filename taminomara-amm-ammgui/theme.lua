local class = require "ammcore.class"

--- Theme and CSS-like style classes.
---
--- !doctype module
--- @class ammgui.theme
local ns = {}

---
---
--- @class ammgui.theme.properties: ammcore.class.Base
ns.properties = class.create("properties")

ns.properties.width = nil
ns.properties.minWidth = nil
ns.properties.maxWidth = nil

ns.properties.height = nil
ns.properties.minHeight = nil
ns.properties.maxHeight = nil

ns.properties.fontSize = nil
ns.properties.fontFamily = nil

ns.properties.color = nil

ns.properties.backgroundColor = nil

ns.properties.paddingTop = nil
ns.properties.paddingLeft = nil
ns.properties.paddingRight = nil
ns.properties.paddingBottom = nil

ns.properties.borderWidthTop = nil
ns.properties.borderWidthLeft = nil
ns.properties.borderWidthRight = nil
ns.properties.borderWidthBottom = nil
ns.properties.borderColorTop = nil
ns.properties.borderColorLeft = nil
ns.properties.borderColorRight = nil
ns.properties.borderColorBottom = nil

ns.properties.flexDirection = nil
ns.properties.flexGrow = nil
ns.properties.flexShrink = nil
ns.properties.flexBasis = nil
ns.properties.flexWrap = nil

ns.properties.alignContent = nil
ns.properties.alignItems = nil
ns.properties.alignSelf = nil

ns.properties.justifyContent = nil
ns.properties.justifyItems = nil
ns.properties.justifySelf = nil

ns.properties.gapColumn = nil
ns.properties.gapRow = nil

ns.properties.overflowX = nil
ns.properties.overflowY = nil

ns.properties.textAlign = nil
ns.properties.textWrap = nil

ns.properties.whitespace = nil

return ns
