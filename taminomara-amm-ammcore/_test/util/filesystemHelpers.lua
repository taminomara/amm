local test = require "ammtest"
local filesystemHelpers = require "ammcore.util.filesystemHelpers"

local suite = test.suite()

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
        test.assertEq(filesystemHelpers.parent(path), parent)
    end
)
