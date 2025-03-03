local test = require "ammtest"

local asserts = test.suite("test.asserts")

asserts:case("assertError throws matches", function()
    test.assertError(function() error("!!!") end, {}, "!!!")
end)

asserts:case("assertError params", function()
    local got
    test.assertError(function(...)
        got = { ... }; error("!!!")
    end, { "foo", "bar" }, "!!!")
    test.assertDeepEq(got, { "foo", "bar" })
end)

asserts:case("assertError not throws", function()
    local ok, err = pcall(test.assertError, function() end, {}, "")
    print(ok, err)
    if ok then
        error("test.assertError didn't catch an error")
    end
end)

asserts:case("assertError not matches", function()
    local ok, err = pcall(test.assertError, function() error("???") end, {}, "!!!")
    print(ok, err)
    if ok then
        error("test.assertError didn't catch an error")
    end
end)

asserts:caseParams(
    "success",
    {
        test.param(test.assertTrue, true),
        test.param(test.assertTrue, 1),
        test.param(test.assertTrue, {}),
        test.param(test.assertFalse, nil),
        test.param(test.assertFalse, false),
        test.param(test.assertLen, {}, 0),
        test.param(test.assertLen, { 1 }, 1),
        test.param(test.assertLen, { 1, 2, 3 }, 3),
        test.param(test.assertNotLen, { 1 }, 0),
        test.param(test.assertMatch, "foo bar baz", "b.r"),
        test.param(test.assertNotMatch, "foo bar baz", "b.t"),
        test.param(test.assertLt, 1, 2),
        test.param(test.assertLte, 1, 2),
        test.param(test.assertLte, 1, 1),
        test.param(test.assertGt, 2, 1),
        test.param(test.assertGte, 2, 1),
        test.param(test.assertGte, 2, 2),
        test.param(test.assertEq, 1, 1),
        test.param(test.assertEq, "foo", "foo"),
        test.param(test.assertNotEq, 1, 2),
        test.param(test.assertNotEq, "foo", "bar"),
        test.param(test.assertDeepEq, 1, 1),
        test.param(test.assertDeepEq, "foo", "foo"),
        test.param(test.assertDeepEq, { 1, 2, 3 }, { 1, 2, 3 }),
        test.param(test.assertDeepEq, { [4.5] = 1 }, { [4.5] = 1 }),
        test.param(test.assertDeepEq, { foo = 1, bar = { baz = 2 } }, { foo = 1, bar = { baz = 2 } }),
        test.param(test.assertNotDeepEq, 1, 2),
        test.param(test.assertNotDeepEq, "foo", "bar"),
        test.param(test.assertNotDeepEq, { [{}] = 1 }, { [{}] = 1 }),
        test.param(test.assertNotDeepEq, { foo = 1, bar = { baz = 2 } }, { foo = 1, bar = { baz = 3 } }),
        test.param(test.assertClose, 1 / 3, 1 / 3),
        test.param(test.assertNotClose, 0, 1e-8),
        test.param(test.assertBoolean, true),
        test.param(test.assertNotBoolean, nil),
        test.param(test.assertNil, nil),
        test.param(test.assertNotNil, ""),
        test.param(test.assertString, ""),
        test.param(test.assertNotString, {}),
        test.param(test.assertTable, {}),
        test.param(test.assertNotTable, 10),
        test.param(test.assertNumber, 10),
        test.param(test.assertNotNumber, true),
    },
    function(cmp, ...)
        cmp(...)
    end
)

asserts:caseParams(
    "failure",
    {
        test.param(test.assertTrue, nil),
        test.param(test.assertTrue, false),
        test.param(test.assertFalse, true),
        test.param(test.assertFalse, {}),
        test.param(test.assertLen, {}, 1),
        test.param(test.assertNotLen, { 1 }, 1),
        test.param(test.assertMatch, "foo", "bar"),
        test.param(test.assertNotMatch, "foo", "fooo?"),
        test.param(test.assertLt, 1, 1),
        test.param(test.assertLte, 2, 1),
        test.param(test.assertGt, 1, 1),
        test.param(test.assertGte, 1, 2),
        test.param(test.assertEq, 1, 2),
        test.param(test.assertNotEq, 1, 1),
        test.param(test.assertDeepEq, "foo", "bar"),
        test.param(test.assertDeepEq, { 1 }, { 2 }),
        test.param(test.assertDeepEq, { { 1 } }, { { {} } }),
        test.param(test.assertNotDeepEq, { 1, 2, 3 }, { 1, 2, 3 }),
        test.param(test.assertClose, 1, 2),
        test.param(test.assertNotClose, 0, 0),
        test.param(test.assertBoolean, nil),
        test.param(test.assertNotBoolean, false),
        test.param(test.assertNil, 10),
        test.param(test.assertNotNil, nil),
        test.param(test.assertString, nil),
        test.param(test.assertNotString, ""),
        test.param(test.assertTable, -5),
        test.param(test.assertNotTable, {}),
        test.param(test.assertNumber, "???"),
        test.param(test.assertNotNumber, 15),
    },
    function(cmp, ...)
        test.assertError(cmp, { ... }, "AssertError")
    end
)

-- test.patch

TEST_GLOBAL_VAR = 1
TEST_GLOBAL_NAMESPACE = { x = 2, y = { z = 3 } }

local patch = test.suite("test.patch")

function patch:setupSuite()
    test.assertEq(TEST_GLOBAL_VAR, 1)
    test.assertEq(TEST_GLOBAL_NAMESPACE.x, 2)
    test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, 3)

    test.patch(nil, "TEST_GLOBAL_VAR", 4)
    test.patch(TEST_GLOBAL_NAMESPACE, "x", 5)
    test.patch(TEST_GLOBAL_NAMESPACE.y, "z", 6)

    test.assertEq(TEST_GLOBAL_VAR, 4)
    test.assertEq(TEST_GLOBAL_NAMESPACE.x, 5)
    test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, 6)
end

function patch:setupTest()
    test.assertEq(TEST_GLOBAL_VAR, 4)
    test.assertEq(TEST_GLOBAL_NAMESPACE.x, 5)
    test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, 6)

    test.patch(nil, "TEST_GLOBAL_VAR", 7)
    test.patch(TEST_GLOBAL_NAMESPACE, "x", 8)
    test.patch(TEST_GLOBAL_NAMESPACE.y, "z", 9)

    test.assertEq(TEST_GLOBAL_VAR, 7)
    test.assertEq(TEST_GLOBAL_NAMESPACE.x, 8)
    test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, 9)
end

patch:caseParams(
    "patch",
    {
        test.param(10),
        test.param(20),
    },
    function(b)
        test.assertEq(TEST_GLOBAL_VAR, 7)
        test.assertEq(TEST_GLOBAL_NAMESPACE.x, 8)
        test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, 9)

        test.patch(nil, "TEST_GLOBAL_VAR", b + 10)
        test.patch(TEST_GLOBAL_NAMESPACE, "x", b + 11)
        test.patch(TEST_GLOBAL_NAMESPACE.y, "z", b + 12)

        test.assertEq(TEST_GLOBAL_VAR, b + 10)
        test.assertEq(TEST_GLOBAL_NAMESPACE.x, b + 11)
        test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, b + 12)
    end
)

function patch:teardownTest()
    test.assertEq(TEST_GLOBAL_VAR, 7)
    test.assertEq(TEST_GLOBAL_NAMESPACE.x, 8)
    test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, 9)
end

function patch:teardownSuite()
    test.assertEq(TEST_GLOBAL_VAR, 4)
    test.assertEq(TEST_GLOBAL_NAMESPACE.x, 5)
    test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, 6)
end

local postPatch = test.suite("test.patch")

postPatch:case("cleanup", function()
    test.assertEq(TEST_GLOBAL_VAR, 1)
    test.assertEq(TEST_GLOBAL_NAMESPACE.x, 2)
    test.assertEq(TEST_GLOBAL_NAMESPACE.y.z, 3)
end)

local getLog = test.suite("test.getLog")

getLog:case("getLog", function()
    test.assertDeepEq(test.getLog(), {})
    print("123", 1, 2)
    computer.log(2, "foo\n\nbar!")
    test.assertDeepEq(test.getLog(), { { level = 1, msg = "123\t1\t2" }, { level = 2, msg = "foo\n\nbar!" } })
end)

getLog:case("getLogStr", function()
    test.assertEq(test.getLogStr(), "")
    print("123", 1, 2)
    computer.log(2, "foo\n\nbar!")
    test.assertEq(test.getLogStr(), "123\t1\t2\nfoo\n\nbar!\n")
end)

local helpers = test.suite("test.helpers")

helpers:caseParams(
    "pprint long",
    {
        test.param(10, "10"),
        test.param("foo", "\"foo\""),
        test.param("foo\nbar", "\"foo\\nbar\""),
        test.param({ 1, 2, 3 }, "{1,2,3}"),
        test.param({ foo = "bar" }, "{foo=\"bar\"}"),
        test.param({ "a", "b", foo = "bar" }, "{\"a\",\"b\",foo=\"bar\"}"),
        test.param({ [0.5] = 10 }, "{[0.5]=10}"),
        test.param({ ["100"] = 10 }, "{[\"100\"]=10}"),
    },
    function(value, expected)
        test.assertEq(test.pprint(value, true), expected)
    end
)
