local test = require "ammtest"
local str = require "ammgui.string"

local suite = test.suite()

--- @param s string
--- @return number
local function width(s)
    return s:len()
end

--- @param s string
--- @return ammgui.string.String s
local function nobr(s)
    return str.String:New(s, nil, nil, true)
end

suite:caseParams(
    "calculateTextWidth",
    {
        test.param(
            { "foo" },
            {
                { string = "foo", width = 3 },
            }
        ),
        test.param(
            { "foo", "bar" },
            {
                { string = "foo", width = 3 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { "foo bar" },
            {
                { string = "foo", width = 3 },
                { string = " ", width = 1 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { "foo   bar" },
            {
                { string = "foo", width = 3 },
                { string = " ", width = 1 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { "  foo" },
            {
                { string = "foo", width = 3 },
            }
        ),
        test.param(
            { "foo  " },
            {
                { string = "foo", width = 3 },
            }
        ),
        test.param(
            { "  foo  " },
            {
                { string = "foo", width = 3 },
            }
        ),
        test.param(
            { "foo-bar" },
            {
                { string = "foo-", width = 4 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { "foo--bar" },
            {
                { string = "foo--", width = 5 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { "foo", " bar" },
            {
                { string = "foo", width = 3 },
                { string = " ", width = 1 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { "foo ", "bar" },
            {
                { string = "foo", width = 3 },
                { string = " ", width = 1 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { "foo ", " bar" },
            {
                { string = "foo", width = 3 },
                { string = " ", width = 1 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { " foo ", " bar " },
            {
                { string = "foo", width = 3 },
                { string = " ", width = 1 },
                { string = "bar", width = 3 },
            }
        ),
        test.param(
            { nobr("foo") },
            {
                { string = "foo", width = 3 },
            }
        ),
        test.param(
            { nobr("foo  ") },
            {
                { string = "foo", width = 3 },
            }
        ),
        test.param(
            { nobr("  foo") },
            {
                { string = "foo", width = 3 },
            }
        ),
        test.param(
            { nobr("  foo  ") },
            {
                { string = "foo", width = 3 },
            }
        ),
        test.param(
            { nobr("foo bar-baz") },
            {
                { string = "foo bar-baz", width = 11 },
            }
        ),
    },
    function(s, expected)
        test.assertDeepEq(str.calculateTextWidth(s, width, 0), expected)
    end
)


--- @param strings ammgui.string.StringW[]
--- @param indices [integer, integer][]
--- @return string[]
local function mergeLines(strings, indices)
    local result = {}
    for _, index in ipairs(indices) do
        local line = ""
        for i = index[1], index[2] do
            line = line .. strings[i].string
        end
        table.insert(result, line)
    end
    return result
end

suite:caseParams(
    "splitLines",
    {
        test.param(
            { "foo bar baz" }, 15,
            { "foo bar baz" }, 11
        ),
        test.param(
            { "foo bar baz" }, 7,
            { "foo bar", "baz" }, 7
        ),
        test.param(
            { "foo bar baz" }, 10,
            { "foo bar", "baz" }, 7
        ),
        -- N.B.: ö is two symbols,
        -- and we don't have a unicode database at hand to check that.
        test.param(
            { "Eyjafjallajökull" }, 10,
            { "Eyjafjallajökull" }, 17
        ),
        test.param(
            { "foo bar baz" }, 0,
            { "foo", "bar", "baz" }, 3
        )
    },
    function(s, w, expected, expectedMaxLineWidth)
        local strings = str.calculateTextWidth(s, width, 0)
        local indices, maxLineWidth = str.splitLines(strings, w)
        test.assertDeepEq(mergeLines(strings, indices), expected)
        test.assertEq(maxLineWidth, expectedMaxLineWidth)
    end
)
