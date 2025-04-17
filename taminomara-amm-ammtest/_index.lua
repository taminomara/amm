local defer = require "ammcore.defer"
local bootloader = require "ammcore.bootloader"
local provider = require "ammcore.pkg.providers.local"
local class = require "ammcore.class"

--- AMM test library.
---
--- !doctype module
--- @class ammtest
local ns = {}

local fileRe = bootloader.getFile():match("^.-/taminomara%-amm%-ammtest/")
if fileRe then
    fileRe = fileRe:gsub("[^%w]", "%%%1") .. "[^:]*"
else
    fileRe = "[-]"
end

--- Pretty print implementation.
---
--- @param x any
--- @param long boolean
--- @param depth integer
--- @return string
local function _pprintImpl(x, long, depth)
    long = long or false
    depth = (depth or 0) + 1
    if not long and depth > 3 then
        return "..."
    end
    if type(x) == "table" then
        if (getmetatable(x) or {}).__tostring then
            return tostring(x)
        end

        local res = "{"
        local sep = ""
        local i = 0
        local seenKeys = {}

        -- Print array keys.
        for k, v in ipairs(x) do
            i = i + 1
            if not long and i > 5 then
                break
            end

            res = string.format("%s%s%s", res, sep, _pprintImpl(v, long, depth))
            sep = long and ", " or ","
            seenKeys[k] = true
        end

        -- Print identifier keys.
        local stringKeys = {}
        for k in pairs(x) do
            if type(k) == "string" and string.match(k, "^[_%a][_%w]*$") then
                table.insert(stringKeys, k)
            end
        end
        table.sort(stringKeys)
        for _, k in ipairs(stringKeys) do
            i = i + 1
            if not long and i > 5 then
                break
            end

            res = string.format("%s%s%s=%s", res, sep, k, _pprintImpl(x[k], long, depth))
            sep = long and ", " or ","
            seenKeys[k] = true
        end

        for k, v in pairs(x) do
            if seenKeys[k] then
                goto continue
            end
            i = i + 1
            if not long and i > 5 then
                break
            end

            res = string.format("%s%s[%s]=%s", res, sep, _pprintImpl(k, long, depth), _pprintImpl(v, long, depth))
            sep = long and ", " or ","

            ::continue::
        end
        if not long and i > 5 then
            res = res .. sep .. "..."
        end
        return res .. "}"
    end

    if type(x) == "string" then
        x = string.format("%q", x):gsub("\\\n", "\\n"):gsub("\\9", "\\t"):gsub("\\009", "\\t")
    else
        x = tostring(x)
    end

    if long then
        return x
    else
        return x:len() > 33 and (x:sub(1, 15) .. "..." .. x:sub(x:len() - 14)) or x
    end
end

--- Pretty print a table/variable.
---
--- @param x any value to be pretty printed.
--- @param long boolean whether to shorten the value or not.
--- @return string
function ns.pprint(x, long)
    return _pprintImpl(x, long, 0)
end

--- Pretty print function arguments.
---
--- @param params any[] array of function arguments.
--- @param long boolean whether to shorten the value or not.
--- @return string
function ns.pprintVa(params, long)
    if #params == 0 then
        return "nil"
    elseif #params == 1 then
        return ns.pprint(params[1], long)
    else
        local res = ""
        for i, param in ipairs(params) do
            res = string.format("%s\n  %s: %s", res, i, ns.pprint(param, long))
        end
        return res
    end
end

local _TsMeta = { __tostring = ns.pprintVa }
local function Ts(...)
    return setmetatable({ ... }, _TsMeta)
end

local _AssertErrorMeta = { __tostring = function(self) return "AssertError: " .. tostring(self.msg) end }
local function AssertError(msg, vars, fmt, ...)
    return setmetatable({ msg = msg, vars = vars, fmt = fmt, args = { ... }, loc = bootloader.getLoc(4) },
        _AssertErrorMeta)
end

local _FailMeta = { __tostring = function(self) return "Fail: " .. tostring(self.msg) end }
local function Fail(msg)
    return setmetatable({ msg = msg }, _FailMeta)
end

local _SkipMeta = { __tostring = function(self) return "Skip: " .. tostring(self.msg) end }
local function Skip(msg)
    return setmetatable({ msg = msg }, _SkipMeta)
end

local function check(pass, msg, vars, fmt, ...)
    if not pass then
        error(AssertError(msg, vars, fmt, ...), 3)
    end
end

--- Assert that the given value is true.
---
--- @param g any
--- @param msg string?
function ns.assertTrue(g, msg)
    check(
        g, msg, {},
        "Expected true, got %s", Ts(g))
end

--- Assert that the given value is false.
---
--- @param g any
--- @param msg string?
function ns.assertFalse(g, msg)
    check(
        not g, msg, {},
        "Expected false, got %s", Ts(g))
end

--- Assert that two arrays contain the same number of elements.
---
--- @param g any[]
--- @param e integer
--- @param msg string?
function ns.assertLen(g, e, msg)
    check(
        #g == e, msg, { g = { g }, e = { e } },
        "Expected length %s, got %s", Ts(#g), Ts(e))
end

--- Assert that two arrays contain different number of elements.
---
--- @param g any[]
--- @param e integer
--- @param msg string?
function ns.assertNotLen(g, e, msg)
    check(
        #g ~= e, msg, { g = { g }, e = { e } },
        "Expected length %s, got %s", Ts(#g), Ts(e))
end

--- Assert that the given string `matches <string.match>` a pattern.
---
--- @param g string
--- @param pat string
--- @param msg string?
function ns.assertMatch(g, pat, msg)
    check(
        string.match(g, pat), msg, { g = { g } },
        "Expected string to match %q", pat)
end

--- Assert that the given string does not `match <string.match>` a pattern.
---
--- @param g string
--- @param pat string
--- @param msg string?
function ns.assertNotMatch(g, pat, msg)
    check(
        not string.match(g, pat), msg, { g = { g } },
        "Expected string not to match %q", pat)
end

--- Assert that the given function throws an error when called,
--- and that the error message `matches <string.match>` the given pattern.
---
--- If the given function doesn't throw an error, and returns a value instead,
--- the value will be displayed in a test failure message.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    test.assertError(
---        function (a, b) return a + b end,
---        { nil, 1 },
---        "attempt to perform arithmetic on a nil value",
---    )
---
--- @param fn fun(...): ...
--- @param args any[]
--- @param pat string
--- @param msg string?
function ns.assertError(fn, args, pat, msg)
    local ret
    local ok, err = defer.xpcall(function() ret = { fn(table.unpack(args or {})) } end)
    check(
        not ok, msg, { ret = ret },
        "Function didn't throw an error")
    check(
        string.match(tostring(err.message), pat), msg, { g = { err.message }, tb = err.trace },
        "Expected error to match %q", pat)
end

--- Assert that `g < e`.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function ns.assertLt(g, e, msg)
    check(
        g < e, msg, { g = { g }, e = { e } },
        "Expected %s < %s", Ts(g), Ts(e))
end

--- Assert that `g <= e`.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function ns.assertLte(g, e, msg)
    check(
        g <= e, msg, { g = { g }, e = { e } },
        "Expected %s <= %s", Ts(g), Ts(e))
end

--- Assert that `g > e`.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function ns.assertGt(g, e, msg)
    check(
        g > e, msg, { g = { g }, e = { e } },
        "Expected %s > %s", Ts(g), Ts(e))
end

--- Assert that `g >= e`.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function ns.assertGte(g, e, msg)
    check(
        g >= e, msg, { g = { g }, e = { e } },
        "Expected %s >= %s", Ts(g), Ts(e))
end

--- Assert that `g == e`.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function ns.assertEq(g, e, msg)
    check(
        g == e, msg, { g = { g }, e = { e } },
        "Expected %s == %s", Ts(g), Ts(e))
end

--- Assert that `g ~= e`.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function ns.assertNotEq(g, e, msg)
    check(
        g ~= e, msg, { g = { g }, e = { e } },
        "Expected %s ~= %s", Ts(g), Ts(e))
end

local function deepEq(a, b)
    local function walk(a, b, fails, ctx)
        if type(a) == "table" and type(b) == "table" then
            for k, v in pairs(a) do
                table.insert(ctx, k)
                walk(v, b[k], fails, ctx)
                table.remove(ctx)
            end
            for k, v in pairs(b) do
                if not a[k] then
                    table.insert(ctx, k)
                    walk(a[k], v, fails, ctx)
                    table.remove(ctx)
                end
            end
        else
            if a ~= b then
                local loc, sep = "", ""
                for _, key in ipairs(ctx) do
                    loc = loc .. sep .. ns.pprint(key, false)
                    sep = "."
                end
                table.insert(fails, loc)
            end
        end
    end

    local fails, ctx = {}, {}
    walk(a, b, fails, ctx)
    table.sort(fails)

    return #fails == 0, fails
end

--- Assert that two values are deep-equal.
---
--- That is, if two values are tables, they should contain the same set of keys,
--- and their values should themselves be deep-equal; if two values are not tables,
--- they should be equal when compared by the ``==`` operator.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function ns.assertDeepEq(g, e, msg)
    local ok, fails = deepEq(g, e)
    local n = string.format("keys differ: %s", table.concat(fails, ", "))
    check(
        ok, msg, { g = { g }, e = { e }, n = n },
        "Expected deep equality", Ts(g), Ts(e))
end

--- Assert that two values are not deep-equal.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function ns.assertNotDeepEq(g, e, msg)
    check(
        not deepEq(g, e), msg, { g = g, e = e },
        "Expected deep inequality", Ts(g), Ts(e))
end

--- Assert that two floats are equal, within the given tolerance.
---
--- @param g number
--- @param e number
--- @param tol number?
--- @param msg string?
function ns.assertClose(g, e, tol, msg)
    tol = tol or 1e-9
    check(
        math.abs(g - e) <= tol, msg, { g = { g }, e = { e } },
        "Expected close numbers")
end

--- Assert that two floats are not equal, within the given tolerance.
---
--- @param g number
--- @param e number
--- @param tol number?
--- @param msg string?
function ns.assertNotClose(g, e, tol, msg)
    tol = tol or 1e-9
    check(
        math.abs(g - e) > tol, msg, { g = { g }, e = { e } },
        "Expected not close numbers")
end

--- Assert that the given value is a boolean.
---
--- @param g any
--- @param msg string?
function ns.assertBoolean(g, msg)
    check(
        type(g) == "boolean", msg, { g = { g } },
        "Expected boolean, got %s", type(g))
end

--- Assert that the given value is not a boolean.
---
--- @param g any
--- @param msg string?
function ns.assertNotBoolean(g, msg)
    check(
        type(g) ~= "boolean", msg, { g = { g } },
        "Expected not boolean, got %s", type(g))
end

--- Assert that the given value is a nil.
---
--- @param g any
--- @param msg string?
function ns.assertNil(g, msg)
    check(
        type(g) == "nil", msg, { g = { g } },
        "Expected nil, got %s", type(g))
end

--- Assert that the given value is not a nil.
---
--- @param g any
--- @param msg string?
function ns.assertNotNil(g, msg)
    check(
        type(g) ~= "nil", msg, { g = { g } },
        "Expected not nil, got %s", type(g))
end

--- Assert that the given value is a string.
---
--- @param g any
--- @param msg string?
function ns.assertString(g, msg)
    check(
        type(g) == "string", msg, { g = { g } },
        "Expected string, got %s", type(g))
end

--- Assert that the given value is not a string.
---
--- @param g any
--- @param msg string?
function ns.assertNotString(g, msg)
    check(
        type(g) ~= "string", msg, { g = { g } },
        "Expected not string, got %s", type(g))
end

--- Assert that the given value is a table.
---
--- @param g any
--- @param msg string?
function ns.assertTable(g, msg)
    check(
        type(g) == "table", msg, { g = { g } },
        "Expected table, got %s", type(g))
end

--- Assert that the given value is not a table.
---
--- @param g any
--- @param msg string?
function ns.assertNotTable(g, msg)
    check(
        type(g) ~= "table", msg, { g = { g } },
        "Expected not table, got %s", type(g))
end

--- Assert that the given value is a number.
---
--- @param g any
--- @param msg string?
function ns.assertNumber(g, msg)
    check(
        type(g) == "number", msg, { g = { g } },
        "Expected number, got %s", type(g))
end

--- Assert that the given value is not a number.
---
--- @param g any
--- @param msg string?
function ns.assertNotNumber(g, msg)
    check(
        type(g) ~= "number", msg, { g = { g } },
        "Expected not number, got %s", type(g))
end

--- Mark test as failed and immediately stop it.
---
--- @param msg string?
function ns.fail(msg)
    error(Fail(msg), 2)
end

--- Mark test as skipped and immediately stop it.
---
--- @param msg string?
function ns.skip(msg)
    error(Skip(msg), 2)
end

--- Container for test parameters and additional debug values.
--- Used with `ammtest.Suite.caseParams`.
---
--- @class ammtest.Param: ammcore.class.Base
ns.Param = class.create("Param")

--- .. note::
---
---    Use `ammtest.param` to properly construct test parameters.
---
--- @param values any[]
--- @param loc string?
---
--- @generic T: ammtest.Param
--- @param self T
--- @return T
function ns.Param:New(values, loc)
    self = class.Base.New(self)

    --- Values that will be passed to the test function.
    ---
    --- !doctype const
    --- @type any[]
    self.values = values

    --- Location where this parameter was created.
    ---
    --- !doctype const
    --- @type string
    self.loc = loc or bootloader.getLoc(2)

    return self
end

--- Test parameter, used with `ammtest.Suite.caseParams`.
---
--- @param ... any
--- @return ammtest.Param
function ns.param(...)
    return ns.Param:New({ ... }, bootloader.getLoc(2))
end

--- @type ammtest.Suite[]
local suites = {}

--- Base class for test suites.
---
--- @class ammtest.Suite: ammcore.class.Base
ns.Suite = class.create("Suite")

--- .. note::
---
---    Use `ammtest.suite` to properly construct test suites.
---
--- @param name string? name of the test suite.
--- @param isSafe boolean
---
--- @generic T: ammtest.Suite
--- @param self T
--- @return T
function ns.Suite:New(name, isSafe)
    self = class.Base.New(self)

    --- Name of the suite, used for error messages.
    ---
    --- !doctype const
    --- @type string
    self.name = name or bootloader.getMod(2)

    --- Indicates that this suite is safe to run in GitHub actions.
    ---
    --- !doctype const
    --- @type boolean
    self.isSafe = isSafe

    --- @package
    --- @type { name: string, loc: string, fn: fun(...), param: ammtest.Param? }[]
    self._cases = {}

    table.insert(suites, self)

    return self
end

--- Runs before every test.
---
--- !doc virtual
function ns.Suite:setupTest() end

--- Runs after every test.
---
--- !doc virtual
function ns.Suite:teardownTest() end

--- Runs before every suite.
---
--- !doc virtual
function ns.Suite:setupSuite() end

--- Runs after every suite.
---
--- !doc virtual
function ns.Suite:teardownSuite() end

--- Add a test to the suite.
---
--- @param name string test name, used for error messages.
--- @param fn fun() test implementation.
function ns.Suite:case(name, fn)
    table.insert(self._cases, { name = name, loc = bootloader.getLoc(2), fn = fn })
end

--- Add a parametrized test to the suite.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    local suite = test.suite("math")
---    suite:caseParams(
---        "multiply",
---        {
---            test.param(2, 2, 4),
---            test.param(3, 3, 9),
---        },
---        function (a, b, c)
---            test.assertEq(a * b, c)
---        end
---    )
---
--- @param name string test name, used for error messages.
--- @param params ammtest.Param[] array of test parameters.
--- @param fn fun(...) test implementation, must accept parameters as its arguments.
function ns.Suite:caseParams(name, params, fn)
    if #params == 0 then
        fn = function() ns.skip("Parameter list is empty.") end
        table.insert(self._cases, { name = name, loc = bootloader.getLoc(2), fn = fn })
        return
    end
    for i, param in ipairs(params) do
        table.insert(self._cases, { name = string.format("%s[%s]", name, i), loc = param.loc, fn = fn, param = param })
    end
end

--- Create a new test suite.
---
--- @param name string?
--- @param isSafe boolean?
--- @return ammtest.Suite
function ns.suite(name, isSafe)
    name = name and (":" .. name) or ""
    return ns.Suite:New(bootloader.getMod(2) .. name, isSafe or false)
end

--- Create a new test suite and mark it as safe to run in GitHub actions.
---
--- @param name string?
--- @return ammtest.Suite
function ns.safeSuite(name)
    name = name and ("." .. name) or ""
    return ns.Suite:New(bootloader.getMod(2) .. name, true)
end

local testData = {
    isInTest = false,
    output = nil,
}

--- This function replaces `computer.log` during test.
local function logToOutput(level, msg)
    table.insert(assert(testData.output), { level = level, msg = tostring(msg) })
end

--- This function replaces `print` during test.
local function printToOutput(...)
    local strings = {}
    for _, x in ipairs({ ... }) do table.insert(strings, tostring(x)) end
    logToOutput(1, table.concat(strings, "\t"))
end

--- Check if we're currently in test mode.
---
--- @return boolean
function ns.isInTest()
    return testData.isInTest
end

--- Get log lines that were printed during the test.
---
--- This function only works in tests, no in setup/teardown functions.
---
--- @return { level: integer, msg: string}[]
function ns.getLog()
    if not testData.output then
        error("`ammtest.getLog` can't be called outside of test case")
    end
    return testData.output
end

--- Get log lines that were printed during the test, concatenated into a single string.
---
--- This function only works in tests, no in setup/teardown functions.
---
--- @return string
function ns.getLogStr()
    if not testData.output then
        error("`ammtest.getLog` can't be called outside of test case")
    end
    local log = ""
    for _, line in ipairs(testData.output) do
        log = log .. line.msg .. "\n"
    end
    return log
end

--- Info about patches applied via `ammtest.patch`.
---
--- Patches are undone in layers: one layer for patches done in suite setup,
--- one for patches in test setup, and one for patches in a test itself.
---
--- @type { env: table<string, any>, name: string, value: any }[][]
local patchStack = {}

--- Temporarily replace value of a variable.
---
--- Calling `ammtest.patch(a.b, "c", x)` is equivalent to executing `a.b.c = x`, and then
--- restoring the old value. To replace global variable, set `env` to `nil`.
---
--- Depending on where this function was called from, the effects are restored
--- after test case, test teardown, or suite teardown.
---
--- @param env table<string, any>? table that contains the replaced value.
--- @param name string name of the replaced value.
--- @param value any new value.
function ns.patch(env, name, value)
    if #patchStack == 0 then
        error("`ammtest.patch` can't be called outside of test suite")
    end

    env = env or _ENV or _G
    table.insert(patchStack[#patchStack], { env = env, name = name, value = env[name] })
    env[name] = value
end

--- Add a patch layer to `patchStack`.
---
--- @nodiscard
local function pushPatchContext()
    table.insert(patchStack, {})
    return setmetatable({}, {
        __close = function(err)
            if #patchStack == 0 then
                computer.panic(string.format(
                    "Error when popping test patch context. Previous error: %s", err
                ))
            end

            local patches = table.remove(patchStack)

            for i = #patches, 1, -1 do
                local patch = patches[i]
                patch.env[patch.name] = patch.value
            end
        end,
    })
end

--- Result of a test run.
---
--- .. data:: OK
---
---    Test finished successfully.
---
--- .. data:: SKIP
---
---    Test was skipped.
---
--- .. data:: FAIL
---
---    Test failed.
---
--- @alias ammtest.Status "OK" | "SKIP" | "FAIL"
ns.Status = {
    OK = "OK",
    SKIP = "SKIP",
    FAIL = "FAIL",
}

--- Log a string using an appropriate level for the given status.
---
--- @param status ammtest.Status
--- @param msg string
local function logWithStatus(status, msg)
    local level = { [ns.Status.OK] = 1, [ns.Status.SKIP] = 2, [ns.Status.FAIL] = 3 }
    computer.log(level[status], msg)
end

--- Results of a single test suite.
---
--- @class ammtest.Result: ammcore.class.Base
ns.Result = class.create("Result")

--- @param name string
--- @param status ammtest.Status?
--- @param msg string?
--- @param loc string?
---
--- @generic T: ammtest.Result
--- @param self T
--- @return T
function ns.Result:New(name, status, msg, loc)
    self = class.Base.New(self)

    --- Name of the test suite.
    ---
    --- !doctype const
    --- @type string
    self.name = name

    --- Status of the test suite.
    ---
    --- !doctype const
    --- @type ammtest.Status
    self.status = status or ns.Status.FAIL

    --- Message with which the test suite failed.
    ---
    --- !doctype const
    --- @type string?
    self.msg = msg

    --- Location of the error that failed the suite.
    --- Only set if the failure occurred during suite setup/teardown.
    ---
    --- !doctype const
    --- @type string?
    self.loc = loc

    --- Array of test cases executed within this suite.
    ---
    --- !doctype const
    --- @type ammtest.CaseResult[]
    self.cases = {}

    return self
end

--- Results of a single test case.
---
--- @class ammtest.CaseResult: ammcore.class.Base
ns.CaseResult = class.create("Result")

--- @param name string
--- @param status ammtest.Status?
--- @param msg string?
--- @param testLoc string?
--- @param loc string?
---
--- @generic T: ammtest.CaseResult
--- @param self T
--- @return T
function ns.CaseResult:New(name, status, msg, testLoc, loc)
    self = class.Base.New(self)

    --- Name of the test case.
    ---
    --- !doctype const
    --- @type string
    self.name = name

    --- Status of the test case.
    ---
    --- !doctype const
    --- @type ammtest.Status
    self.status = status or ns.Status.FAIL

    --- Message with which the test case failed.
    ---
    --- !doctype const
    --- @type string?
    self.msg = msg

    --- Location of the test function.
    ---
    --- !doctype const
    --- @type string?
    self.testLoc = testLoc

    --- Location of the error that failed the test.
    ---
    --- !doctype const
    --- @type string?
    self.loc = loc

    return self
end

--- Add indentation to a string.
---
--- @param s string
--- @return string
local function indent(s)
    if s then
        s = s:gsub("([^\n\r]+)", "  %1")
    end
    return s
end

--- Cleanup traceback for better readability.
---
--- @param tb string
local function cleanTraceback(tb)
    return tb
        -- Remote tabs.
        :gsub("^\t+", "")
        :gsub("\n\t", "\n")
        :gsub("\t", "  ")
        -- Remove header.
        :gsub("^stack traceback:\n", "")
        :gsub("^%[C%]: in %?\n", "")
        :gsub("^%[C%]: in global 'error'\n", "")
        -- Remove xpcall calls from testlib.
        :gsub("%[C%]: in global 'xpcall'\n" .. fileRe .. ":.-\n", "\t")
        -- Remove testlib lines.
        :gsub("" .. fileRe .. ":.-\n", "\t")
        -- Collapse removed lines and insert dots.
        :gsub("\t+", "(...testlib calls...)\n")
end

--- Run a function and report its status and status message.
---
--- @param what string?
--- @param fn fun(...)
--- @param ... any
--- @return ammtest.Status status
--- @return string? msg
--- @return string? loc
local function run(what, fn, ...)
    local ok, err = defer.xpcall(fn, ...)
    if ok then
        return ns.Status.OK, nil, nil
    elseif type(err.message) == "table" and getmetatable(err.message) == _FailMeta then
        return ns.Status.FAIL, err.message.msg, nil
    elseif type(err.message) == "table" and getmetatable(err.message) == _SkipMeta then
        return ns.Status.SKIP, err.message.msg, nil
    elseif type(err.message) == "table" and getmetatable(err.message) == _AssertErrorMeta then
        local msg

        if what then
            msg = string.format("Error in %s: ", what)
        else
            msg = "Error: "
        end
        msg = msg .. string.format(err.message.fmt, table.unpack(err.message.args)) .. "\n"
        if err.message.msg then
            msg = msg .. indent(err.message.msg) .. "\n"
        end
        if err.message.vars then
            local vars = {
                { "ret", "Returned value" },
                { "e", "Exp" },
                { "g", "Got" },
                { "n", "Note", "as-is" },
                { "tb", "Original trace", "tb" },
            }
            for _, var in ipairs(vars) do
                local k, name, mode = table.unpack(var)
                if err.message.vars[k] then
                    local v
                    if mode == "tb" then
                        v = "\n" .. indent(cleanTraceback(tostring(err.message.vars[k])))
                    elseif mode == "as-is" then
                        v = " " .. err.message.vars[k]
                    else
                        v = " " .. ns.pprintVa(err.message.vars[k], true)
                    end
                    msg = msg .. string.format("%s:%s", name, v) .. "\n"
                end
            end
        end
        if testData.output then
            local log = ns.getLogStr()
            if log:len() > 0 then msg = msg .. "Test log:\n" .. indent(log) .. "\n" end
        end

        return ns.Status.FAIL, msg:gsub("%s$", ""), err.message.loc
    else
        local msg

        if what then
            msg = string.format("Error in %s: ", what)
        else
            msg = "Error: "
        end
        msg = msg .. tostring(err.message) .. "\n"
        msg = msg .. "Trace:\n" .. indent(cleanTraceback(err.trace)) .. "\n"
        if testData.output then
            local log = ns.getLogStr()
            if log:len() > 0 then msg = msg .. "Test log:\n" .. indent(log) .. "\n" end
        end

        return ns.Status.FAIL, msg:gsub("%s$", ""), nil
    end
end

local function loadTests(root, devRoot)
    if not filesystem.exists(root) then
        return
    end
    for _, filename in ipairs(filesystem.children(root)) do
        local path = filesystem.path(root, filename)
        local devPath = filesystem.path(devRoot, filename)
        local modpath = devPath:match("^(.*)%.lua$")
        if modpath then
            require(modpath:gsub("/_index%.lua", ""):gsub("/", "."))
        elseif filesystem.isDir(path) then
            loadTests(path, devPath)
        end
    end
end

--- Search and load all tests in all dev packages.
---
--- @param name string?
function ns.loadTests(name)
    if bootloader.getLoaderKind() ~= "drive" then
        computer.panic("Program \".test\" only works with drive loader")
    end

    local devRoot = bootloader.getDevRoot()
    local loader = provider.LocalProvider:New(devRoot, true)

    for _, pkg in ipairs(loader:getLocalPackages()) do
        if not name or pkg.name == name then
            loadTests(
                filesystem.path(pkg.packageRoot, "_test"),
                filesystem.path(pkg.name, "_test")
            )
        end
    end
end

--- Run all collected tests and return a result.
---
--- @return ammtest.Result[]
function ns.run()
    local results = {}
    for _, suite in ipairs(suites) do
        local _ <close> = pushPatchContext()

        local suiteResult = ns.Result:New(suite.name)
        table.insert(results, suiteResult)

        ---@diagnostic disable-next-line: undefined-global
        if __AMM_EXTERNAL_ENV and not suite.isSafe then
            suiteResult.status = "SKIP"
            suiteResult.msg = "Suite can't run in this environment."
            goto continue
        end

        do
            local status, msg, loc = run("suite setup", suite.setupSuite, suite)
            if status ~= ns.Status.OK then
                suiteResult.status = status
                suiteResult.loc = loc
                suiteResult.msg = msg
                goto continue
            end
        end

        for _, case in pairs(suite._cases) do
            local _ <close> = pushPatchContext()

            local testResult = ns.CaseResult:New(case.name)
            testResult.testLoc = case.loc
            table.insert(suiteResult.cases, testResult)

            do
                local status, msg, loc = run("test setup", suite.setupTest, suite)
                if status ~= ns.Status.OK then
                    testResult.status = status
                    testResult.loc = loc
                    testResult.msg = msg
                    goto continue
                end
            end

            do
                local _ <close> = pushPatchContext()

                ns.patch(testData, "isInTest", true)
                ns.patch(testData, "output", {})
                ns.patch(_ENV, "print", printToOutput)
                ns.patch(computer, "log", logToOutput)

                local values = (case.param and case.param.values) or {}
                local status, msg, loc = run(nil, case.fn, table.unpack(values))
                testResult.status = status
                testResult.loc = loc
                testResult.msg = msg
            end

            do
                local status, msg, loc = run("test teardown", suite.teardownTest, suite)
                if status == ns.Status.FAIL then
                    testResult.status = status
                    testResult.loc = loc
                    if testResult.msg and msg then
                        testResult.msg = testResult.msg .. "\n" .. msg
                    elseif msg then
                        testResult.msg = msg
                    end
                    goto continue
                end
            end

            ::continue::
        end

        do
            local status, msg, loc = run("suite teardown", suite.teardownSuite, suite)
            if status ~= ns.Status.OK then
                suiteResult.status = status
                suiteResult.loc = loc
                suiteResult.msg = "Suite teardown " .. status
                if msg then suiteResult.msg = suiteResult.msg .. ": " .. msg end
                goto continue
            end
        end

        suiteResult.status = ns.Status.OK

        ::continue::
    end

    return results
end

--- Main function that will collect and run all the tests.
---
--- @param name string?
function ns.main(name)
    ns.loadTests(name)

    computer.log(
        1,
        string.format(
            "Running tests in %s suite%s...",
            #suites,
            #suites == 1 and "" or "s"
        )
    )

    local results = ns.run()

    if #results > 0 then
        computer.log(1, "========================================")
    end

    local nTests = {
        [ns.Status.OK] = 0,
        [ns.Status.SKIP] = 0,
        [ns.Status.FAIL] = 0,
    }
    local mods = {}
    local nTestsByMod = {}

    for _, suite in ipairs(results) do
        local mod = suite.name:match("^[^.]*")
        if not nTestsByMod[mod] then
            table.insert(mods, mod)
            nTestsByMod[mod] = { [ns.Status.OK] = 0, [ns.Status.SKIP] = 0, [ns.Status.FAIL] = 0 }
        end

        if suite.status ~= ns.Status.OK then
            local suiteDesc = string.format("%s: %s", suite.name, suite.status)
            if suite.loc then suiteDesc = suiteDesc .. "\n" .. string.format("  At %s", suite.loc) end
            if suite.msg then suiteDesc = suiteDesc .. "\n" .. indent(suite.msg) end
            logWithStatus(suite.status, suiteDesc)
        end

        for _, case in ipairs(suite.cases) do
            nTests[case.status] = nTests[case.status] + 1
            nTestsByMod[mod][case.status] = nTestsByMod[mod][case.status] + 1
            if case.status ~= ns.Status.OK then
                local caseDesc = string.format("%s/%s: %s", suite.name, case.name, case.status)
                if case.testLoc then caseDesc = caseDesc .. "\n" .. string.format("  At %s", case.testLoc) end
                if case.loc then caseDesc = caseDesc .. "\n" .. string.format("  At %s", case.loc) end
                if case.msg then caseDesc = caseDesc .. "\n" .. indent(case.msg) end
                logWithStatus(case.status, caseDesc)
            end
        end
    end

    if #mods > 0 then
        table.sort(mods)
        computer.log(1, "========================================")
        for _, mod in ipairs(mods) do
            local nTests = nTestsByMod[mod] or {}
            local logLevel
            if nTests[ns.Status.FAIL] > 0 then
                logLevel = 3
            elseif nTests[ns.Status.SKIP] > 0 or nTests[ns.Status.OK] > 0 then
                logLevel = 1
            else
                logLevel = 2
            end

            computer.log(
                logLevel,
                string.format(
                    "%-14s %s OK, %s SKIP, %s FAIL",
                    mod,
                    nTests[ns.Status.OK],
                    nTests[ns.Status.SKIP],
                    nTests[ns.Status.FAIL]
                )
            )
        end
    end

    local logLevel, msg, beepA, beepB, exitcode
    if nTests[ns.Status.FAIL] > 0 then
        logLevel = 3
        msg = "Failed"
        beepA, beepB = 1, 0.7
        exitcode = 2
    elseif nTests[ns.Status.SKIP] > 0 or nTests[ns.Status.OK] > 0 then
        logLevel = 1
        msg = "Passed"
        beepA, beepB = 0.7, 1
        exitcode = 0
    else
        logLevel = 2
        msg = "No tests found"
        beepA, beepB = 0.7, 0.7
        exitcode = 1
    end

    computer.log(1, "----------------------------------------")
    computer.log(
        logLevel,
        string.format(
            "%-14s %s OK, %s SKIP, %s FAIL",
            "total",
            nTests[ns.Status.OK],
            nTests[ns.Status.SKIP],
            nTests[ns.Status.FAIL]
        )
    )
    computer.log(1, "========================================")
    computer.log(logLevel, msg)

    computer.beep(beepA)
    sleep(0.1)
    computer.beep(beepB)
    if exitcode ~= 0 then
        computer.panic("Test failed")
    end
end

return ns
