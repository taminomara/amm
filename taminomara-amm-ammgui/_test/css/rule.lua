local test = require "ammtest"
local rule = require "ammgui.css.rule"

local suite = test.suite()

suite:caseParams(
    "resolve",
    {
        -- Initial values.
        test.param(
            { {} },
            {
                width = "auto",
                minWidth = "auto",
                maxWidth = "auto",
                height = "auto",
                minHeight = "auto",
                maxHeight = "auto",
                fontSize = { 12, "pt" },
                fontFamily = "normal",
                lineHeight = { 1.2, "" },
                color = structs.Color { r = 1, g = 0.5, b = 0.25, a = 1 },
                backgroundColor = structs.Color { r = 0, g = 0, b = 0, a = 0 },
                paddingTop = { 0, "px" },
                paddingLeft = { 0, "px" },
                paddingRight = { 0, "px" },
                paddingBottom = { 0, "px" },
                borderWidthTop = { 0, "px" },
                borderWidthLeft = { 0, "px" },
                borderWidthRight = { 0, "px" },
                borderWidthBottom = { 0, "px" },
                borderColorTop = structs.Color { r = 1, g = 0.5, b = 0.25, a = 1 },
                borderColorLeft = structs.Color { r = 1, g = 0.5, b = 0.25, a = 1 },
                borderColorRight = structs.Color { r = 1, g = 0.5, b = 0.25, a = 1 },
                borderColorBottom = structs.Color { r = 1, g = 0.5, b = 0.25, a = 1 },
                flexDirection = "row",
                flexGrow = 0,
                flexShrink = 1,
                flexBasis = "auto",
                flexWrap = "nowrap",
                alignContent = "normal",
                alignItems = "normal",
                alignSelf = "auto",
                justifyContent = "normal",
                justifyItems = "normal",
                justifySelf = "auto",
                columnGap = { 0, "px" },
                rowGap = { 0, "px" },
                overflowX = "visible",
                overflowY = "visible",
                textAlign = "left",
                textWrapMode = "wrap",
            }
        ),
        -- Parse.
        test.param(
            { { {
                width = 15,
                minWidth = 16,
                maxWidth = 17,
                height = 18,
                minHeight = 19,
                maxHeight = 20,
                fontSize = 15,
            } } },
            {
                width = { 15, "px" },
                minWidth = { 16, "px" },
                maxWidth = { 17, "px" },
                height = { 18, "px" },
                minHeight = { 19, "px" },
                maxHeight = { 20, "px" },
                fontSize = { 15, "px" },
            }
        ),
        test.param(
            { { {
                width = "15px",
                minWidth = "16px",
                maxWidth = "17px",
                height = "18px",
                minHeight = "19px",
                maxHeight = "20px",
                color = "#f00",
                backgroundColor = "#00ff0000",
                fontSize = "5pt",
            } } },
            {
                width = { 15, "px" },
                minWidth = { 16, "px" },
                maxWidth = { 17, "px" },
                height = { 18, "px" },
                minHeight = { 19, "px" },
                maxHeight = { 20, "px" },
                color = structs.Color { r = 1, g = 0, b = 0, a = 1 },
                backgroundColor = structs.Color { r = 0, g = 1, b = 0, a = 0 },
                fontSize = { 5, "pt" },
            }
        ),
        test.param(
            { { {
                width = "2em",
                minWidth = "2em",
                maxWidth = "2em",
                height = "2em",
                minHeight = "2em",
                maxHeight = "2em",
            } } },
            {
                width = { 24, "pt" },
                minWidth = { 24, "pt" },
                maxWidth = { 24, "pt" },
                height = { 24, "pt" },
                minHeight = { 24, "pt" },
                maxHeight = { 24, "pt" },
            }
        ),
        -- Priority.
        test.param(
            {
                { { width = 10 }, { width = 20, color = "#fcf" } },
            },
            {
                width = { 10, "px" },
                color = structs.Color { r = 1, g = 0.8, b = 1, a = 1 },
            }
        ),
        -- Inherit.
        test.param(
            {
                { { width = 10 }, { color = "#fcf" } },
                {}
            },
            {
                width = "auto",
                color = structs.Color { r = 1, g = 0.8, b = 1, a = 1 },
            }
        ),
        -- Inherit from em.
        test.param(
            {
                { { fontSize = 10, lineHeight = "2em" } },
                {},
                { { fontSize = 15 } },
            },
            {
                lineHeight = { 20, "px" },
            }
        ),
        test.param(
            {
                { { fontSize = 10, lineHeight = 2 } },
                {},
                { { fontSize = 15 } },
            },
            {
                lineHeight = { 2, "" },
            }
        ),
        -- Force-inherit.
        test.param(
            {
                { { width = 10 } },
                {},
                { { width = "inherit" } },
            },
            {
                width = { 10, "px" },
            }
        ),
    },
    function(path, expected)
        local parent = nil
        local theme = { canvastext = structs.Color { r = 1, g = 0.5, b = 0.25, a = 1 } }
        for _, matches in ipairs(path) do
            local processedMatches = {}
            for _, ruleData in ipairs(matches) do
                table.insert(processedMatches, rule.makeRule(ruleData))
            end
            parent = rule.Resolved:New(processedMatches, parent, theme)
        end
        assert(parent)

        local results = {}
        for name, _ in pairs(expected) do
            results[name] = parent[name]
        end
        test.assertDeepEq(results, expected)
    end
)
