local test = require "ammtest"
local pickle = require "amm.lib.pickle"

local suite = test.suite("pickle")

suite:caseParams(
    "pickle",
    {
        test.param(nil, [[nil]]),
        test.param(0, [[0]]),
        test.param("foo", [["foo"]]),
        test.param("foo\tbar\n\nbaz", "\"foo\\9bar\\\n\\\nbaz\""),
        test.param({}, [[{}]]),
        test.param({ 1, 2, 3 }, [[{[1]=1,[2]=2,[3]=3,}]]),
        test.param({ 1, k = "v" }, [[{[1]=1,["k"]="v",}]]),
        test.param({ [10] = "meep" }, [[{[10]="meep",}]]),
        test.param(structs.Color{ r=1, g=0.5, b=0 }, [[{__amm_s="Color",v={["r"]=0x1p+0,["g"]=0x1p-1,["b"]=0x0p+0,["a"]=0x0p+0,}}]]),
        --- @diagnostic disable-next-line: undefined-global
        test.param(findItem("Wire"), [[{__amm_i="Desc_Wire_C"}]])
    },
    function(value, expected)
        local pickled = pickle.pickle(value)
        test.assertEq(pickled, expected)
        local unpickled = pickle.unpickle(pickled)
        test.assertDeepEq(unpickled, value)
    end
)

suite:caseParams(
    "unsupported",
    {
        test.param(function() end),
    },
    function(value)
        test.assertError(pickle.pickle, {value}, "not supported")
    end
)
