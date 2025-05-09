local test = require "ammtest"
local selector = require "ammgui._impl.css.selector"

local suite = test.suite()

suite:caseParams(
    "match",
    {
        test.param(
            ".top_bar .top_bar_elem.top_bar_elem_search input:focus",
            {
                { elem = "body", classes = {}, pseudo = {} },
                { elem = "div", classes = { top_bar = true }, pseudo = {} },
                { elem = "div", classes = { top_bar_elem = true, top_bar_elem_search = true }, pseudo = {} },
                { elem = "div", classes = {}, pseudo = {} },
                { elem = "input", classes = { search = true }, pseudo = { enabled = true, focus = true } },
            },
            true
        ),
        test.param(
            ".top_bar .top_bar_elem.top_bar_elem_search input:focus",
            {
                { elem = "body", classes = {}, pseudo = {} },
                { elem = "div", classes = { top_bar = true }, pseudo = {} },
                { elem = "div", classes = { top_bar_elem = true, top_bar_elem_search = true }, pseudo = {} },
                { elem = "div", classes = {}, pseudo = {} },
                { elem = "input", classes = { search = true }, pseudo = { enabled = true, focus = true } },
                { elem = "span", classes = {}, pseudo = {} },
            },
            false
        ),
        test.param(
            ".top_bar .top_bar_elem.top_bar_elem_search input:focus *",
            {
                { elem = "body", classes = {}, pseudo = {} },
                { elem = "div", classes = { top_bar = true }, pseudo = {} },
                { elem = "div", classes = { top_bar_elem = true, top_bar_elem_search = true }, pseudo = {} },
                { elem = "div", classes = {}, pseudo = {} },
                { elem = "input", classes = { search = true }, pseudo = { enabled = true, focus = true } },
                { elem = "span", classes = {}, pseudo = {} },
            },
            true
        ),
        test.param(
            "input:focus",
            {
                { elem = "body", classes = {}, pseudo = {} },
                { elem = "input", classes = { search = true }, pseudo = { enabled = true, focus = true } },
            },
            true
        ),
        test.param(
            "input:focus",
            {
                { elem = "body", classes = {}, pseudo = {} },
                { elem = "input", classes = { search = true }, pseudo = { enabled = true } },
            },
            false
        ),
        test.param(
            ".top_bar .top_bar_elem.top_bar_elem_search *",
            {
                { elem = "body", classes = {}, pseudo = {} },
                { elem = "div", classes = { top_bar = true }, pseudo = {} },
                { elem = "div", classes = { top_bar_elem = true, top_bar_elem_search = true }, pseudo = {} },
                { elem = "div", classes = {}, pseudo = {} },
                { elem = "input", classes = { search = true }, pseudo = { enabled = true, focus = true } },
                { elem = "span", classes = {}, pseudo = {} },
            },
            true
        ),
        test.param(
            ".top_bar .top_bar_elem.top_bar_elem_search input:focus",
            {
                { elem = "body", classes = {}, pseudo = {} },
                { elem = "div", classes = { top_bar = true }, pseudo = {} },
                { elem = "div", classes = { top_bar_elem_2 = true, top_bar_elem_search = true }, pseudo = {} },
                { elem = "div", classes = {}, pseudo = {} },
                { elem = "input", classes = { search = true }, pseudo = { enabled = true, focus = true } },
            },
            false
        ),
        test.param(
            "div div",
            {
                { elem = "div", classes = {}, pseudo = {} },
                { elem = "div", classes = {}, pseudo = {} },
            },
            true
        ),
        test.param(
            "div * div",
            {
                { elem = "div", classes = {}, pseudo = {} },
                { elem = "div", classes = {}, pseudo = {} },
            },
            false
        ),
        test.param(
            "div * div",
            {
                { elem = "div", classes = {}, pseudo = {} },
                { elem = "aside", classes = {}, pseudo = {} },
                { elem = "div", classes = {}, pseudo = {} },
            },
            true
        ),
    },
    function(s, path, expected)
        test.assertEq(selector.parse(s, 0, 0):match(path), expected)
    end
)

suite:caseParams(
    "specificity",
    {
        test.param("", 0, 0),
        test.param("*", 0, 0),
        test.param("div", 0, 1),
        test.param("div div", 0, 2),
        test.param(".cls", 1, 0),
        test.param("div.cls", 1, 1),
        test.param(":root", 1, 0),
        test.param("form input:hover", 1, 2),
    },
    function(s, c, e)
        local compiled = selector.parse(s, 0, 0)
        test.assertEq(compiled.classSpecificity, c)
        test.assertEq(compiled.elemSpecificity, e)
    end
)

suite:caseParams(
    "ordering",
    {
        test.param({"", 0, 0}, "<", {"", 0, 0}, false),
        test.param({"", 0, 0}, ">", {"", 0, 0}, false),
        test.param({"", 0, 0}, "<", {"div", 0, 0}, true),
        test.param({"", 0, 0}, ">", {"div", 0, 0}, false),
        test.param({"", 0, 1}, "<", {"div", 0, 0}, true),
        test.param({"", 0, 1}, ">", {"div", 0, 0}, false),
        test.param({"", 1, 0}, "<", {"div", 0, 0}, false),
        test.param({"", 1, 0}, ">", {"div", 0, 0}, true),
        test.param({".cls", 0, 0}, "<", {"div", 0, 0}, false),
        test.param({".cls", 0, 0}, ">", {"div", 0, 0}, true),
        test.param({".cls", 0, 0}, "<", {".cls2", 0, 0}, false),
        test.param({".cls", 0, 0}, ">", {".cls2", 0, 0}, false),
        test.param({".cls", 0, 0}, "<", {"div.cls2", 0, 0}, true),
        test.param({".cls", 0, 0}, ">", {"div.cls2", 0, 0}, false),
    },
    function(lhs, op, rhs, expected)
        lhs = selector.parse(table.unpack(lhs))
        rhs = selector.parse(table.unpack(rhs))

        local fn = ({
            [">"] = function(a, b) return a > b end,
            ["<"] = function(a, b) return a < b end,
        })[op]
        test.assertEq(fn(lhs, rhs), expected)

        local rvFn = ({
            [">"] = function(a, b) return b < a end,
            ["<"] = function(a, b) return b > a end,
        })[op]
        if rvFn then
            test.assertEq(rvFn(lhs, rhs), expected)
        end
    end
)
