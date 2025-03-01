local fin          = require "ammcore.util.fin"
local debugHelpers = require "ammcore.util.debugHelpers"
local bootloader   = require "ammcore.bootloader"
local provider     = require "ammcore.pkg.providers.local"

--- AMM test library.
local test         = {}

local fileRe       = debugHelpers.getFile():match("^.-/taminomara%-amm%-ammtest/")
if fileRe then
    fileRe = fileRe:gsub("[^%w]", "%%%1") .. "[^:]*"
else
    fileRe = "[-]"
end

--- Pretty print implementation.
---
--- @see test.pprint
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
        for k, v in ipairs(x) do
            i = i + 1
            if not long and i > 5 then
                break
            end

            res = string.format("%s%s%s", res, sep, _pprintImpl(v, long, depth))
            sep = ","
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

            if type(k) == "string" and string.match(k, "^[_%a][_%w]*$") then
                res = string.format("%s%s%s=%s", res, sep, k, _pprintImpl(v, long, depth))
            else
                res = string.format("%s%s[%s]=%s", res, sep, _pprintImpl(k, long, depth), _pprintImpl(v, long, depth))
            end
            sep = ","

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
--- @param x any
--- @param long boolean
--- @return string
function test.pprint(x, long)
    return _pprintImpl(x, long, 0)
end

--- Pretty print function arguments.
---
--- @param params any[]
--- @param long boolean
--- @return string
function test.pprintVa(params, long)
    if #params == 0 then
        return "nil"
    elseif #params == 1 then
        return test.pprint(params[1], long)
    else
        local res = ""
        for i, param in ipairs(params) do
            res = string.format("%s\n  %s: %s", res, i, test.pprint(param, long))
        end
        return res
    end
end

local _TsMeta = { __tostring = test.pprintVa }
local function Ts(...)
    return setmetatable({ ... }, _TsMeta)
end

local _AssertErrorMeta = { __tostring = function(self) return "AssertError: " .. tostring(self.msg) end }
local function AssertError(msg, vars, fmt, ...)
    return setmetatable({ msg = msg, vars = vars, fmt = fmt, args = { ... }, loc = debugHelpers.getLoc(4) },
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
function test.assertTrue(g, msg)
    check(
        g, msg, {},
        "Expected true, got %s", Ts(g))
end

--- Assert that the given value is false.
---
--- @param g any
--- @param msg string?
function test.assertFalse(g, msg)
    check(
        not g, msg, {},
        "Expected false, got %s", Ts(g))
end

--- Assert that two arrays contain the same number of elements.
---
--- @param g any[]
--- @param e integer
--- @param msg string?
function test.assertLen(g, e, msg)
    check(
        #g == e, msg, { g = { g }, e = { e } },
        "Expected length %s, got %s", Ts(#g), Ts(e))
end

--- Assert that two arrays contain different number of elements.
---
--- @param g any[]
--- @param e integer
--- @param msg string?
function test.assertNotLen(g, e, msg)
    check(
        #g ~= e, msg, { g = { g }, e = { e } },
        "Expected length %s, got %s", Ts(#g), Ts(e))
end

--- Assert that the given string matches a pattern.
---
--- @param g string
--- @param pat string
--- @param msg string?
function test.assertMatch(g, pat, msg)
    check(
        string.match(g, pat), msg, { g = { g } },
        "Expected string to match %q", pat)
end

--- Assert that the given string does not match a pattern.
---
--- @param g string
--- @param pat string
--- @param msg string?
function test.assertNotMatch(g, pat, msg)
    check(
        not string.match(g, pat), msg, { g = { g } },
        "Expected string not to match %q", pat)
end

--- Assert that the given function throws an error when called,
--- and that the error message matches the given pattern.
---
--- If the given function doesn't throw an error, and returns a value instead,
--- the value will be displayed in a test failure message.
---
--- @param fn fun(...): ...
--- @param args any[]
--- @param pat string
--- @param msg string?
function test.assertError(fn, args, pat, msg)
    local ret
    local ok, err = fin.xpcall(function() ret = { fn(table.unpack(args or {})) } end)
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
function test.assertLt(g, e, msg)
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
function test.assertLte(g, e, msg)
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
function test.assertGt(g, e, msg)
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
function test.assertGte(g, e, msg)
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
function test.assertEq(g, e, msg)
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
function test.assertNotEq(g, e, msg)
    check(
        g ~= e, msg, { g = { g }, e = { e } },
        "Expected %s ~= %s", Ts(g), Ts(e))
end

local function deepEq(a, b)
    if type(a) == "table" and type(b) == "table" then
        for k, v in pairs(a) do
            if not deepEq(v, b[k]) then return false end
        end
        for k, v in pairs(b) do
            if not a[k] then return false end
        end
        return true
    else
        return a == b
    end
end

--- Assert that two values are deep-equal.
---
--- That is, if two values are tables, they should contain the same set of keys,
--- and their values should themselves be deep-equal; if two values are not tables,
--- they should be equal when compared by the `==` operator.
---
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function test.assertDeepEq(g, e, msg)
    check(
        deepEq(g, e), msg, { g = { g }, e = { e } },
        "Expected deep equality", Ts(g), Ts(e))
end

--- Assert that two values are not deep-equal.
---
--- @see test.assertDeepEq
--- @generic T
--- @param g T
--- @param e T
--- @param msg string?
function test.assertNotDeepEq(g, e, msg)
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
function test.assertClose(g, e, tol, msg)
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
function test.assertNotClose(g, e, tol, msg)
    tol = tol or 1e-9
    check(
        math.abs(g - e) > tol, msg, { g = { g }, e = { e } },
        "Expected not close numbers")
end

--- Assert that the geven value is a boolean.
---
--- @param g any
--- @param msg string?
function test.assertBoolean(g, msg)
    check(
        type(g) == "boolean", msg, { g = { g } },
        "Expected boolean, got %s", type(g))
end

--- Assert that the geven value is not a boolean.
---
--- @param g any
--- @param msg string?
function test.assertNotBoolean(g, msg)
    check(
        type(g) ~= "boolean", msg, { g = { g } },
        "Expected not boolean, got %s", type(g))
end

--- Assert that the geven value is a nil.
---
--- @param g any
--- @param msg string?
function test.assertNil(g, msg)
    check(
        type(g) == "nil", msg, { g = { g } },
        "Expected nil, got %s", type(g))
end

--- Assert that the geven value is not a nil.
---
--- @param g any
--- @param msg string?
function test.assertNotNil(g, msg)
    check(
        type(g) ~= "nil", msg, { g = { g } },
        "Expected not nil, got %s", type(g))
end

--- Assert that the geven value is a string.
---
--- @param g any
--- @param msg string?
function test.assertString(g, msg)
    check(
        type(g) == "string", msg, { g = { g } },
        "Expected string, got %s", type(g))
end

--- Assert that the geven value is not a string.
---
--- @param g any
--- @param msg string?
function test.assertNotString(g, msg)
    check(
        type(g) ~= "string", msg, { g = { g } },
        "Expected not string, got %s", type(g))
end

--- Assert that the geven value is a table.
---
--- @param g any
--- @param msg string?
function test.assertTable(g, msg)
    check(
        type(g) == "table", msg, { g = { g } },
        "Expected table, got %s", type(g))
end

--- Assert that the geven value is not a table.
---
--- @param g any
--- @param msg string?
function test.assertNotTable(g, msg)
    check(
        type(g) ~= "table", msg, { g = { g } },
        "Expected not table, got %s", type(g))
end

--- Assert that the geven value is a number.
---
--- @param g any
--- @param msg string?
function test.assertNumber(g, msg)
    check(
        type(g) == "number", msg, { g = { g } },
        "Expected number, got %s", type(g))
end

--- Assert that the geven value is not a number.
---
--- @param g any
--- @param msg string?
function test.assertNotNumber(g, msg)
    check(
        type(g) ~= "number", msg, { g = { g } },
        "Expected not number, got %s", type(g))
end

--- Mark test as failed and immediately stop it.
---
--- @param msg string?
function test.fail(msg)
    error(Fail(msg), 2)
end

--- Mark test as skipped and immediately stop it.
---
--- @param msg string?
function test.skip(msg)
    error(Skip(msg), 2)
end

--- @see test.param
--- @class test.Param-Cls
--- @field package loc string
--- @field package values any[]
local Param = {}

Param.__index = Param

--- Test parameter, used with `test.Suite:caseParams`.
---
--- @see test.Suite-Cls.caseParams
--- @param ... any
--- @return test.Param-Cls
function test.param(...)
    return setmetatable({ values = { ... }, loc = debugHelpers.getLoc(2) }, Param)
end

--- @see test.suite
--- @class test.Suite-Cls
--- @field name string
--- @field package _cases { name: string, loc: string, fn: fun(...), param: test.Param-Cls? }[]
local Suite = {}

Suite.__index = Suite

--- Runs before every test.
function Suite:setupTest() end

--- Runs after every test.
function Suite:teardownTest() end

--- Runs before every suite.
function Suite:setupSuite() end

--- Runs after every suite.
function Suite:teardownSuite() end

--- Add a test to the suite.
---
--- @param name string
--- @param fn fun()
function Suite:case(name, fn)
    table.insert(self._cases, { name = name, loc = debugHelpers.getLoc(2), fn = fn })
end

--- Add a parametrized test to the suite.
---
--- # Example
---
--- ```
--- local suite = test.suite("math")
--- suite:caseParams(
---     "multiply",
---     {
---         test.param(2, 2, 4),
---         test.param(3, 3, 9),
---     },
---     function(a, b, c)
---         test.assertEq(a * b, c)
---     end
--- )
--- ```
---
--- @param name string
--- @param params test.Param-Cls[]
--- @param fn fun(...)
function Suite:caseParams(name, params, fn)
    if #params == 0 then
        self:case(name, function() test.skip("Parameter list is empty.") end)
        return
    end
    for i, param in ipairs(params) do
        table.insert(self._cases, { name = string.format("%s[%s]", name, i), loc = param.loc, fn = fn, param = param })
    end
end

--- @type test.Suite-Cls[]
local suites = {}

--- Create a new test suite.
---
--- @param name string?
--- @return test.Suite-Cls
function test.suite(name)
    name = name or debugHelpers.getMod(2)
    local suite = setmetatable({ name = name, _cases = {} }, Suite)
    table.insert(suites, suite)
    return suite
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
function test.isInTest()
    return testData.isInTest
end

--- Get log lines that were printed during the test.
---
--- @return { level: integer, msg: string}[]
function test.getLog()
    if not testData.output then
        error("`test.getLog` can't be called outside of test case")
    end
    return testData.output
end

--- Get log lines that were printed during the test, concatenated into a single string.
---
--- @return string
function test.getLogStr()
    if not testData.output then
        error("`test.getLog` can't be called outside of test case")
    end
    local log = ""
    for _, line in ipairs(testData.output) do
        log = log .. line.msg .. "\n"
    end
    return log
end

--- Info about patches applied via `test.patch`.
---
--- Patches are undone in layers: one layer for patches done in suite setup,
--- one for patches in test setup, and one for patches in a test itself.
---
--- @type { env: table<string, any>, name: string, value: any }[][]
local patchStack = {}

--- Temporarily replace value of a variable.
---
--- Calling `test.patch(a.b, "c", x)` is equivalent to executing `a.b.c = x`, and then
--- restoring the old value. To replace global variable, set `env` to `nil`.
---
--- Depending on where this function was called from, the effects are testored
--- after test case, test teardown, or suite teardown.
---
--- @param env table<string, any>?
--- @param name string
--- @param value any
function test.patch(env, name, value)
    if #patchStack == 0 then
        error("`test.patch` can't be called outside of test suite")
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
        end
    })
end

--- Result of a test run.
---
--- @enum test.Status
test.Status = {
    OK = "OK",
    SKIP = "SKIP",
    FAIL = "FAIL",
}

--- Log a string using an appropriate level for the given status.
---
--- @param status test.Status
--- @param msg string
local function logWithStatus(status, msg)
    local level = { [test.Status.OK] = 1, [test.Status.SKIP] = 2, [test.Status.FAIL] = 3 }
    computer.log(level[status], msg)
end

--- Results of a single test suite.
---
--- @class test.Result-Cls
--- @field name string
--- @field status test.Status
--- @field msg string?
--- @field loc string?
--- @field cases test.CaseResult-Cls[]
local Result = {}

Result.__index = Result

--- Create a new test suite results container.
---
--- @param name string
--- @return test.Result-Cls
function test.result(name)
    return setmetatable({ name = name, status = test.Status.FAIL, cases = {} }, Result)
end

--- Results of a single test case.
---
--- @class test.CaseResult-Cls
--- @field name string
--- @field status test.Status
--- @field testLoc string
--- @field loc string?
--- @field msg string?
local CaseResult = {}

CaseResult.__index = CaseResult

--- Create a new test case results container.
---
--- @param name string
--- @param testLoc string
--- @return test.CaseResult-Cls
function test.caseResult(name, testLoc)
    return setmetatable({ name = name, testLoc = testLoc, status = test.Status.FAIL }, CaseResult)
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
--- @return test.Status, string?, string?
local function run(what, fn, ...)
    local ok, err = fin.xpcall(fn, ...)
    if ok then
        return test.Status.OK, nil, nil
    elseif type(err.message) == "table" and getmetatable(err.message) == _FailMeta then
        return test.Status.FAIL, err.message.msg, nil
    elseif type(err.message) == "table" and getmetatable(err.message) == _SkipMeta then
        return test.Status.SKIP, err.message.msg, nil
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
                { "e",   "Exp" },
                { "g",   "Got" },
                { "tb",  "Original trace", true }
            }
            for _, var in ipairs(vars) do
                local k, name, isTb = table.unpack(var)
                if err.message.vars[k] then
                    local v
                    if isTb then
                        v = "\n" .. indent(cleanTraceback(tostring(err.message.vars[k])))
                    else
                        v = " " .. test.pprintVa(err.message.vars[k], true)
                    end
                    msg = msg .. string.format("%s:%s", name, v) .. "\n"
                end
            end
        end
        if testData.output then
            local log = test.getLogStr()
            if log:len() > 0 then msg = msg .. "Test log:\n" .. indent(log) .. "\n" end
        end

        return test.Status.FAIL, msg, err.message.loc
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
            local log = test.getLogStr()
            if log:len() > 0 then msg = msg .. "Test log:\n" .. indent(log) .. "\n" end
        end

        return test.Status.FAIL, msg, nil
    end
end

local function loadTests(root, devRoot)
    if not filesystem.exists(root) then
        return
    end
    for _, filename in ipairs(filesystem.children(root)) do
        local path = filesystem.path(root, filename)
        local devPath = filesystem.path(devRoot, filename)
        local modpath = filesystem.path(devRoot, filename):match("^(.*)%.lua$")
        if modpath then
            require(modpath:gsub("/", "."))
        elseif filesystem.isDir(path) then
            loadTests(path, devPath)
        end
    end
end

--- Search and load all tests in all dev packages.
---
--- @param name string?
function test.loadTests(name)
    if bootloader.getLoaderKind() ~= "drive" then
        error("test library only works with drive loader")
    end

    local loader = provider.LocalProvider:Dev()

    for pkgName, _ in pairs(loader:getRootRequirements()) do
        if not name or pkgName == name then
            loadTests(
                filesystem.path(assert(bootloader.getDevRoot()), pkgName, "_test"),
                filesystem.path(pkgName, "_test")
            )
        end
    end
end

--- Run all collected tests and return a result.
---
--- @return test.Result-Cls[]
function test.run()
    local results = {}
    for _, suite in ipairs(suites) do
        local _ <close> = pushPatchContext()

        local suiteResult = test.result(suite.name)
        table.insert(results, suiteResult)

        do
            local status, msg, loc = run("suite setup", suite.setupSuite, suite)
            if status ~= test.Status.OK then
                suiteResult.status = status
                suiteResult.loc = loc
                suiteResult.msg = msg
                goto continue
            end
        end

        for _, case in pairs(suite._cases) do
            local _ <close> = pushPatchContext()

            local testResult = test.caseResult(case.name, case.loc)
            table.insert(suiteResult.cases, testResult)

            do
                local status, msg, loc = run("test setup", suite.setupTest, suite)
                if status ~= test.Status.OK then
                    testResult.status = status
                    testResult.loc = loc
                    testResult.msg = msg
                    goto continue
                end
            end

            do
                local _ <close> = pushPatchContext()

                test.patch(testData, "isInTest", true)
                test.patch(testData, "output", {})
                test.patch(_ENV, "print", printToOutput)
                test.patch(computer, "log", logToOutput)

                local values = (case.param and case.param.values) or {}
                local status, msg, loc = run(nil, case.fn, table.unpack(values))
                testResult.status = status
                testResult.loc = loc
                testResult.msg = msg
            end

            do
                local status, msg, loc = run("test teardown", suite.teardownTest, suite)
                if status == test.Status.FAIL then
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
            if status ~= test.Status.OK then
                suiteResult.status = status
                suiteResult.loc = loc
                suiteResult.msg = "Suite teardown " .. status
                if msg then suiteResult.msg = suiteResult.msg .. ": " .. msg end
                goto continue
            end
        end

        suiteResult.status = test.Status.OK

        ::continue::
    end

    return results
end

--- Main function that will collect and run all the tests.
---
--- @param name string?
function test.main(name)
    test.loadTests(name)
    local results = test.run()

    local nTests = {
        [test.Status.OK] = 0,
        [test.Status.SKIP] = 0,
        [test.Status.FAIL] = 0,
    }

    for _, suite in ipairs(results) do
        if suite.status ~= test.Status.OK then
            local suiteDesc = string.format("%s: %s", suite.name, suite.status)
            if suite.loc then suiteDesc = suiteDesc .. "\n" .. string.format("  At %s", suite.loc) end
            if suite.msg then suiteDesc = suiteDesc .. "\n" .. indent(suite.msg) end
            logWithStatus(suite.status, suiteDesc)
        end

        for _, case in ipairs(suite.cases) do
            nTests[case.status] = nTests[case.status] + 1
            if case.status ~= test.Status.OK then
                local caseDesc = string.format("%s/%s: %s", suite.name, case.name, case.status)
                if case.testLoc then caseDesc = caseDesc .. "\n" .. string.format("  At %s", case.testLoc) end
                if case.loc then caseDesc = caseDesc .. "\n" .. string.format("  At %s", case.loc) end
                if case.msg then caseDesc = caseDesc .. "\n" .. indent(case.msg) end
                logWithStatus(case.status, caseDesc)
            end
        end
    end

    local logLevel, msg, beepA, beepB
    if nTests[test.Status.FAIL] > 0 then
        logLevel = 3
        msg = "Failed"
        beepA, beepB = 1, 0.7
    elseif nTests[test.Status.SKIP] > 0 or nTests[test.Status.OK] > 0 then
        logLevel = 1
        msg = "Passed"
        beepA, beepB = 0.7, 1
    else
        logLevel = 2
        msg = "No tests found"
        beepA, beepB = 0.7, 0.7
    end

    computer.log(
        logLevel,
        string.format(
            "========================================\n%s OK, %s SKIP, %s FAIL\n%s",
            nTests[test.Status.OK],
            nTests[test.Status.SKIP],
            nTests[test.Status.FAIL],
            msg
        )
    )

    computer.beep(beepA)
    sleep(0.1)
    computer.beep(beepB)
end

return test
