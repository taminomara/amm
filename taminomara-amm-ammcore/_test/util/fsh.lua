local test = require "ammtest"
local fsh = require "ammcore.fsh"

local suite = test.safeSuite()

suite:caseParams(
    "parent",
    {
        test.param("", ""),
        test.param("foo", ""),
        test.param("foo/bar", "foo"),
        test.param("foo/bar/", "foo"),
        test.param("foo/bar/./", "foo"),
        test.param("foo/bar/baz", "foo/bar"),
        test.param("/", "/"),
        test.param("/foo", "/"),
        test.param("/foo/bar", "/foo"),
        test.param("/foo/bar/", "/foo"),
        test.param("/foo/bar/./", "/foo"),
        test.param("/foo/bar/baz", "/foo/bar"),
        test.param("./", ""),
        test.param("./foo", ""),
        test.param("./foo/bar", "foo"),
        test.param("./foo/bar/", "foo"),
        test.param("./foo/bar/./", "foo"),
        test.param("./foo/bar/baz", "foo/bar"),
    },
    function(path, parent)
        test.assertEq(fsh.parent(path), parent)
    end
)
