--- @namespace ammcore._test.class

local test = require "ammtest"
local class = require "ammcore.class"

local suite = test.safeSuite()

suite:case("base", function()
    class.Base()
    test.assertEq(tostring(class.Base), "Base")
    test.assertEq(tostring(class.Base()), "Base()")
    test.assertEq(class.Base.__name, "Base")
    test.assertEq(class.Base().__name, "Base")
    test.assertEq(class.Base.__class, class.Base)
    test.assertEq(class.Base().__class, class.Base)
    test.assertNil(class.Base.__base)
    test.assertNil(class.Base().__base)
    test.assertEq(class.Base.__module, "ammcore.class")
    test.assertEq(class.Base().__module, "ammcore.class")
    test.assertEq(class.Base.__fullname, "ammcore.class.Base")
    test.assertEq(class.Base().__fullname, "ammcore.class.Base")
    test.assertTrue(class.isChildOf(class.Base, class.Base))
    test.assertTrue(class.isChildOf(class.Base(), class.Base))
    test.assertTrue(class.isChildOf(class.Base(), class.Base()))
end)

suite:case("create", function()
    local C = class.create("C")

    test.assertEq(tostring(C), "C")
    test.assertEq(tostring(C()), "C()")
    test.assertEq(C.__name, "C")
    test.assertEq(C().__name, "C")
    test.assertEq(C.__class, C)
    test.assertEq(C().__class, C)
    test.assertEq(C.__base, class.Base)
    test.assertEq(C().__base, class.Base)
    test.assertEq(C.__module, "ammcore._test.class")
    test.assertEq(C().__module, "ammcore._test.class")
    test.assertEq(C.__fullname, "ammcore._test.class.C")
    test.assertEq(C().__fullname, "ammcore._test.class.C")
end)

suite:case("ctor", function()
    --- @class C: ammcore.class.Base
    local C = class.create("C")
    C.foo = 1

    function C:__init()
        test.assertEq(self.__class, C)
        test.assertNotEq(self, C)
        self.foo = self.foo + 1
    end

    local c = C()
    test.assertEq(C.foo, 1)
    test.assertEq(c.foo, 2)
end)

suite:case("fields", function()
    local C = class.create("C")

    C.foo = 1
    function C:bar() return self.foo end

    local c = C()

    test.assertEq(C.foo, 1)
    test.assertEq(c.foo, 1)
    test.assertEq(c:bar(), 1)

    c.foo = 2

    test.assertEq(C.foo, 1)
    test.assertEq(c.foo, 2)
    test.assertEq(c:bar(), 2)

    C.foo = 3

    test.assertEq(C.foo, 3)
    test.assertEq(c.foo, 2)
    test.assertEq(c:bar(), 2)

    c.foo = nil -- this is a Lua quirk

    test.assertEq(C.foo, 3)
    test.assertEq(c.foo --[[@as integer]], 3)
    test.assertEq(c:bar(), 3)
end)

suite:case("inheritance", function()
    local C = class.create("C")
    C.foo = 1
    C.bar = 2

    local D = class.create("D", C)
    D.bar = 3

    test.assertEq(D.foo, 1)
    test.assertEq(D.bar, 3)

    local d = D()

    test.assertEq(d.foo, 1)
    test.assertEq(d.bar, 3)

    d.foo = 4
    d.bar = 5

    test.assertEq(C.foo, 1)
    test.assertEq(C.bar, 2)
    test.assertEq(D.foo, 1)
    test.assertEq(D.bar, 3)
    test.assertEq(d.foo, 4)
    test.assertEq(d.bar, 5)
end)

suite:case("__tostring", function()
    --- @class C2: ammcore.class.Base
    local C = class.create("C")

    function C:__init(foo)
        self.foo = foo
    end

    function C:__tostring()
        return string.format("%s(%s)", self.__name, self.foo)
    end

    local c = C("meow")

    test.assertEq(tostring(C), "C")
    test.assertEq(tostring(c), "C(meow)")
end)

suite:case("isChildOf", function()
    local C = class.create("C")
    local D = class.create("D", C)
    local E = class.create("E", C)
    local F = class.create("F", E)

    test.assertTrue(class.isChildOf(C, class.Base))
    test.assertTrue(class.isChildOf(C, C))
    test.assertFalse(class.isChildOf(C, D))
    test.assertTrue(class.isChildOf(D, C))
    test.assertTrue(class.isChildOf(F, C))
    test.assertFalse(class.isChildOf(D, F))
    test.assertFalse(class.isChildOf(F, D))
end)

suite:case("inheritance of methods", function ()
    local A = class.create("A")
    function A:__unm()
        return "it works!"
    end

    local B = class.create("B", A)

    test.assertEq((-A()) --[[@as string]], "it works!")
    test.assertEq((-B()) --[[@as string]], "it works!")
end)

suite:case("inheritance of index", function ()
    local A = class.create("A")
    function A:__index(key)
        return "it works!"
    end

    local B = class.create("B", A)

    test.assertEq(A().x, "it works!")
    test.assertEq(B().x, "it works!")
end)

suite:case("mixins", function ()
    local M = {
        x = 1,
        y = function(self, y) return self.x + y end
    }

    local A = class.create("A", class.Base, M)

    test.assertEq(A.x, 1)
    test.assertEq(A():y(2), 3)

    M.x = 2

    test.assertEq(A.x, 1)
    test.assertEq(A():y(2), 3)

    A.x = 2

    test.assertEq(A.x, 2)
    test.assertEq(A():y(2), 4)
end)
