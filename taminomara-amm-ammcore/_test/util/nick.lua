local test = require "ammtest.index"
local nick = require "ammcore.util.nick"

local suite = test.suite("nick")

suite:caseParams(
    "basic",
    {
        test.param("meep=moop foo=bar foo=baz", { meep = { "moop" }, foo = { "bar", "baz" } }),
        test.param("before=hash # after=hash", { after = { "hash" } }),
        test.param("spaces = not allowed", {}),
        test.param("spaces=break values", { spaces = { "break" } }),
        test.param("a=b # key=value#with#hash", { key = { "value#with#hash" } }),
    },
    function(input, expected)
        test.assertDeepEq(nick.parse(input), expected)
    end
)

suite:caseParams(
    "getOne",
    {
        test.param("foo=10 bar=baz foo=qux foo=3", "foo", tonumber, 10),
        test.param("foo=10 bar=baz foo=qux foo=3", "bar", tonumber, nil, "invalid value for bar: \"baz\""),
        test.param("foo=10 bar=baz foo=qux foo=3", "bar", tostring, "baz"),
    },
    function(input, name, ty, expected, expectedError)
        test.assertEq(nick.parse(input):getOne(name, ty), expected)
        if expectedError then
            test.assertMatch(test.getLogStr(), expectedError)
        end
    end
)

suite:caseParams(
    "getAll",
    {
        test.param("foo=10 bar=baz foo=qux foo=3", "foo", tonumber, { 10, 3 }, "invalid value for foo: \"qux\""),
        test.param("foo=10 bar=baz foo=qux foo=3", "bar", tonumber, {}, "invalid value for bar: \"baz\""),
        test.param("foo=10 bar=baz foo=qux foo=3", "foo", tostring, { "10", "qux", "3" }),
        test.param("foo=10 bar=baz foo=qux foo=3", "bar", tostring, { "baz" }),
    },
    function(input, name, ty, expected, expectedError)
        test.assertDeepEq(nick.parse(input):getAll(name, ty), expected)
        if expectedError then
            test.assertMatch(test.getLogStr(), expectedError)
        end
    end
)
