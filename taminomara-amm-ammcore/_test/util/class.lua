local test = require "ammtest/index"
local class = require "ammcore/util/class"

local suite = test.suite("class")

suite:case("Base", function ()
    test.assertEq(tostring(class.Base), "Base")
    test.assertEq(tostring(class.Base:New()), "Base()")
    test.assertEq(class.Base.__name, "Base")
    test.assertEq(class.Base:New().__name, "Base")
    test.assertEq(class.Base.__class, class.Base)
    test.assertEq(class.Base:New().__class, class.Base)
    test.assertNil(class.Base.__base)
    test.assertNil(class.Base:New().__base)
    test.assertEq(class.Base.__module, "ammcore/util/class")
    test.assertEq(class.Base:New().__module, "ammcore/util/class")
    test.assertEq(class.Base.__fullname, "ammcore/util/class:Base")
    test.assertEq(class.Base:New().__fullname, "ammcore/util/class:Base")
    test.assertTrue(class.isChildOf(class.Base, class.Base))
    test.assertTrue(class.isChildOf(class.Base:New(), class.Base))
    test.assertTrue(class.isChildOf(class.Base:New(), class.Base:New()))
end)

suite:case("create", function()
    local C = class.create("C")

    test.assertEq(tostring(C), "C")
    test.assertEq(tostring(C:New()), "C()")
    test.assertEq(C.__name, "C")
    test.assertEq(C:New().__name, "C")
    test.assertEq(C.__class, C)
    test.assertEq(C:New().__class, C)
    test.assertEq(C.__base, class.Base)
    test.assertEq(C:New().__base, class.Base)
    test.assertEq(C.__module, "ammcore/_test/util/class")
    test.assertEq(C:New().__module, "ammcore/_test/util/class")
    test.assertEq(C.__fullname, "ammcore/_test/util/class:C")
    test.assertEq(C:New().__fullname, "ammcore/_test/util/class:C")
end)

suite:case("New", function()
    local C = class.create("C")
    C.foo = 1

    function C:New()
        self = class.Base.New(self)
        test.assertEq(self.__class, C)
        test.assertNotEq(self, C)
        self.foo = self.foo + 1
        return self
    end

    local c = C:New()
    test.assertEq(C.foo, 1)
    test.assertEq(c.foo, 2)
end)

suite:case("fields", function()
    local C = class.create("C")

    C.foo = 1
    function C:bar() return self.foo end

    local c = C:New()

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
    test.assertEq(c.foo, 3)
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

    local d = D:New()

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
    local C = class.create("C")

    function C:New(foo)
        self = class.Base.New(self)
        self.foo = foo
        return self
    end

    function C:__tostring()
        return string.format("%s(%s)", self.__name, self.foo)
    end

    local c = C:New("meow")

    test.assertEq(tostring(C), "C")
    test.assertEq(tostring(c), "C(meow)")
end)

suite:case("__initSubclass", function()
    local C = class.create("C")

    local n = 0

    function C:__initSubclass()
        n = n + 1
        self.n = n
    end

    local D = class.create("D", C)
    test.assertEq(D.n, 1)
    local E = class.create("E", C)
    test.assertEq(E.n, 2)
    local F = class.create("F", E)
    test.assertEq(F.n, 3)
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
