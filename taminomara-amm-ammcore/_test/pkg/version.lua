local version = require "ammcore/pkg/version"
local test = require "ammtest/index"

local suite = test.suite()

suite:caseParams("parse", {}, function()
end)

suite:caseParams("parse with star", {}, function()
end)

suite:caseParams("parse spec", {}, function()
end)

suite:caseParams(
    "compare",
    {
        test.param("1.0.0", "==", "1.0.0", true),
        test.param("1.0.0", "==", "1", true),
        test.param("1.0.0", "==", "1.0", true),
        test.param("1.0.0", "==", "1.0.0.0", true),
        test.param("1", "==", "1.0.0", true),
        test.param("0", "==", "0", true),
        test.param("0.0", "==", "0.0", true),
        test.param("1.0.0", "==", "1.0.1", false),
        test.param("1.0.1", "==", "1.0.0", false),
        test.param("1.0.1", "==", "1", false),
        test.param("1", "==", "1.0.1", false),
        test.param("1", "==", "1.0.0.1", false),
        test.param("2", "==", "1", false),
        test.param("2", "==", "2.0.0.1", false),

        test.param("1.0.0", "!=", "1.0.0", false),
        test.param("1.0.0", "!=", "1", false),
        test.param("1.0.0", "!=", "1.0", false),
        test.param("1.0.0", "!=", "1.0.0.0", false),
        test.param("1", "!=", "1.0.0", false),
        test.param("0", "!=", "0", false),
        test.param("0.0", "!=", "0.0", false),
        test.param("1.0.0", "!=", "1.0.1", true),
        test.param("1.0.1", "!=", "1.0.0", true),
        test.param("1.0.1", "!=", "1", true),
        test.param("1", "!=", "1.0.1", true),
        test.param("1", "!=", "1.0.0.1", true),
        test.param("2", "!=", "1", true),
        test.param("2", "!=", "2.0.0.1", true),

        test.param("1.1.*", "==", "1.1.0", true),
        test.param("1.1.*", "==", "1.1.1", true),
        test.param("1.1.*", "==", "1.1.0.1", true),
        test.param("1.1.*", "==", "1.1.10", true),
        test.param("1.1.*", "==", "1.1.10.10", true),
        test.param("1.1.*", "==", "1.0.0", false),
        test.param("1.1.*", "==", "1.0.1", false),
        test.param("1.1.*", "==", "1.0.10", false),
        test.param("1.1.*", "==", "1.2.0", false),
        test.param("1.1.*", "==", "1.2.1", false),
        test.param("1.1.*", "==", "1.2.10", false),
        test.param("1.0.*", "==", "1", true),
        test.param("1.0.*", "==", "1.0", true),
        test.param("1.0.*", "==", "1.0.0", true),
        test.param("1.0.*", "==", "1.0.1", true),
        test.param("1.0.*", "==", "1.0.0.0", true),
        test.param("1.0.*", "==", "1.0.0.1", true),
        test.param("0.*", "==", "0.0", true),
        test.param("0.*", "==", "0.1", true),
        test.param("0.*", "==", "1.0", false),
        test.param("*", "==", "0", true),
        test.param("*", "==", "1", true),
        test.param("*", "==", "0.1", true),

        test.param("2", ">", "1", true),
        test.param("1.2", ">", "1.1", true),
        test.param("2", ">", "2", false),
        test.param("1", ">", "1", false),
        test.param("2.1", ">", "2.1", false),
        test.param("1.0", ">", "1.1", false),
        test.param("2.0", ">", "1.99", true),
        test.param("1.0.0", ">", "1", false),

        test.param("2", ">=", "1", true),
        test.param("1", ">=", "1", true),
        test.param("1.1", ">=", "1.1", true),
        test.param("1.1", ">=", "1.2", false),
        test.param("1.1", ">=", "1.0", true),
        test.param("1.1", ">=", "1", true),
        test.param("1.2", ">=", "2.1", false),
        test.param("1", ">=", "0.5", true),

        test.param("1.0.1", "~", "1.0.1", true),
        test.param("1.0.5", "~", "1.0.1", true),
        test.param("1.0.0", "~", "1.0.1", false),
        test.param("1.1.0", "~", "1.0.1", false),
        test.param("1.1", "~", "1.1", true),
        test.param("1.1.5", "~", "1.1", true),
        test.param("1.2", "~", "1.1", true),
        test.param("2.0", "~", "1.1", false),
        test.param("1.0", "~", "1.1", false),
        test.param("1.0.5", "~", "1.1", false),
    },
    function(lhs, op, rhs, expected)
        lhs = version.parse(lhs, true)
        rhs = version.parse(rhs, true)

        local fn = ({
            ["~"] = function(a, b) return a:compat(b) end,
            ["=="] = function(a, b) return a == b end,
            ["!="] = function(a, b) return a ~= b end,
            [">="] = function(a, b) return a >= b end,
            [">"] = function(a, b) return a > b end,
            ["<="] = function(a, b) return a <= b end,
            ["<"] = function(a, b) return a < b end,
        })[op]
        test.assertEq(fn(lhs, rhs), expected)

        local rvFn = ({
            ["=="] = function(a, b) return b == a end,
            ["!="] = function(a, b) return b ~= a end,
            [">="] = function(a, b) return b <= a end,
            [">"] = function(a, b) return b < a end,
            ["<="] = function(a, b) return b >= a end,
            ["<"] = function(a, b) return b > a end,
        })[op]
        if rvFn then
            test.assertEq(rvFn(lhs, rhs), expected)
        end
    end
)

suite:caseParams(
    "canonicalString",
    {
        test.param("1.2.3", "1.2.3"),
        test.param("1.2.0", "1.2"),
        test.param("1.0.0", "1"),
        test.param("1.0", "1"),
        test.param("1", "1"),
        test.param("1.0.1.0", "1.0.1"),
        test.param("0.0.0", "0"),
        test.param("0", "0"),
        test.param("0.0.0.0.1.0", "0.0.0.0.1"),
    },
    function (ver, expected)
        test.assertEq(version.parse(ver):canonicalString(), expected)
    end
)

suite:caseParams(
    "spec",
    {
        test.param("==1.0.0", "1.0.0", true),
        test.param("==1.0.0", "1", true),
        test.param("==1.0.0", "1.0", true),
        test.param("==1.0.0", "1.0.0.0", true),
        test.param("==1", "1.0.0", true),
        test.param("==0", "0", true),
        test.param("==0.0", "0.0", true),
        test.param("==1.0.0", "1.0.1", false),
        test.param("==1.0.1", "1.0.0", false),
        test.param("==1.0.1", "1", false),
        test.param("==1", "1.0.1", false),
        test.param("==1", "1.0.0.1", false),
        test.param("==2", "1", false),
        test.param("==2", "2.0.0.1", false),

        test.param("!=1.0.0", "1.0.0", false),
        test.param("!=1.0.0", "1", false),
        test.param("!=1.0.0", "1.0", false),
        test.param("!=1.0.0", "1.0.0.0", false),
        test.param("!=1", "1.0.0", false),
        test.param("!=0", "0", false),
        test.param("!=0.0", "0.0", false),
        test.param("!=1.0.0", "1.0.1", true),
        test.param("!=1.0.1", "1.0.0", true),
        test.param("!=1.0.1", "1", true),
        test.param("!=1", "1.0.1", true),
        test.param("!=1", "1.0.0.1", true),
        test.param("!=2", "1", true),
        test.param("!=2", "2.0.0.1", true),

        test.param("==1.1.*", "1.1.0", true),
        test.param("==1.1.*", "1.1.1", true),
        test.param("==1.1.*", "1.1.0.1", true),
        test.param("==1.1.*", "1.1.10", true),
        test.param("==1.1.*", "1.1.10.10", true),
        test.param("==1.1.*", "1.0.0", false),
        test.param("==1.1.*", "1.0.1", false),
        test.param("==1.1.*", "1.0.10", false),
        test.param("==1.1.*", "1.2.0", false),
        test.param("==1.1.*", "1.2.1", false),
        test.param("==1.1.*", "1.2.10", false),
        test.param("==1.0.*", "1", true),
        test.param("==1.0.*", "1.0", true),
        test.param("==1.0.*", "1.0.0", true),
        test.param("==1.0.*", "1.0.1", true),
        test.param("==1.0.*", "1.0.0.0", true),
        test.param("==1.0.*", "1.0.0.1", true),
        test.param("==0.*", "0.0", true),
        test.param("==0.*", "0.1", true),
        test.param("==0.*", "1.0", false),
        test.param("==*", "0", true),
        test.param("==*", "1", true),
        test.param("==*", "0.1", true),

        test.param(">1", "2", true),
        test.param(">1.1", "1.2", true),
        test.param(">2", "2", false),
        test.param(">1", "1", false),
        test.param(">2.1", "2.1", false),
        test.param(">1.1", "1.0", false),
        test.param(">1.99", "2.0", true),
        test.param(">1", "1.0.0", false),

        test.param(">=1", "2", true),
        test.param(">=1", "1", true),
        test.param(">=1.1", "1.1", true),
        test.param(">=1.2", "1.1", false),
        test.param(">=1.0", "1.1", true),
        test.param(">=1", "1.1", true),
        test.param(">=2.1", "1.2", false),
        test.param(">=0.5", "1", true),

        test.param("<2", "1", true),
        test.param("<1.2", "1.1", true),
        test.param("<2", "2", false),
        test.param("<1", "1", false),
        test.param("<2.1", "2.1", false),
        test.param("<1.0", "1.1", false),
        test.param("<2.0", "1.99", true),
        test.param("<1.0.0", "1", false),

        test.param("<=2", "1", true),
        test.param("<=1", "1", true),
        test.param("<=1.1", "1.1", true),
        test.param("<=1.1", "1.2", false),
        test.param("<=1.1", "1.0", true),
        test.param("<=1.1", "1", true),
        test.param("<=1.2", "2.1", false),
        test.param("<=1", "0.5", true),

        test.param("~1.0.1", "1.0.1", true),
        test.param("~1.0.1", "1.0.5", true),
        test.param("~1.0.1", "1.0.0", false),
        test.param("~1.0.1", "1.1.0", false),
        test.param("~1.1", "1.1", true),
        test.param("~1.1", "1.1.5", true),
        test.param("~1.1", "1.2", true),
        test.param("~1.1", "2.0", false),
        test.param("~1.1", "1.0", false),
        test.param("~1.1", "1.0.5", false),

        test.param("==1, ==1", "1", true),
        test.param("==1, ==1", "2", false),
        test.param("==1, ==2", "1", false),
        test.param("==1, ==2", "2", false),

        test.param("==1, !=1", "1", false),

        test.param(">1, >2", "3", true),
        test.param(">1, >2", "2", false),

        test.param(">1, >=2", "2", true),
        test.param(">1, >=2", "1", false),

        test.param(">=1, >2", "3", true),
        test.param(">=1, >2", "2", false),

        test.param(">=1, >1", "2", true),
        test.param(">=1, >1", "1", false),

        test.param(">=1, >=2", "2", true),
        test.param(">=1, >=2", "1", false),

        test.param(">=1, <=1", "0", false),
        test.param(">=1, <=1", "1", true),
        test.param(">=1, <=1", "2", false),
        test.param(">1, <1", "1", false),
        test.param(">=1, !=1", "2", true),
        test.param(">=1, !=1", "1", false),
        test.param("<=1, !=1", "0", true),
        test.param("<=1, !=1", "1", false),
    },
    function (specs, ver, expected)
        print(specs, ver, expected)
        local spec = version.parseSpec(specs)
        test.assertEq(spec:matches(version.parse(ver)), expected)
    end
)
