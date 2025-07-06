--- @namespace ammcore.class

local fun = require "ammcore.fun"
local bootloader = require "ammcore.bootloader"

--- Allows creating classes using metatable mechanism.
---
---
--- Creating a class
--- ----------------
---
--- You can create a new class by calling `create`.
--- Unless specified, the new class will inherit `Base`,
--- so you can annotate it accordingly:
---
--- .. code-block:: lua
---
---    local class = require "ammcore.class"
---
---    --- @class Foo: Base
---    local Foo = class.create("Foo")
---
---    function Foo:doSomething()
---        print("Doing something in Foo")
---    end
---
---
--- Instantiating a class
--- ---------------------
---
--- You can now create instances of your class by simply calling it:
---
--- .. code-block:: lua
---
---    local foo = Foo()
---
---
--- Initializing a class
--- --------------------
---
--- You can initialize new instance of a class by specifying an ``__init`` method:
---
--- .. code-block:: lua
---
---    function Foo:__init()
---        -- Initialize the new instance.
---        self.beep = "boop"
---    end
---
---    print(Foo().beep) -- prints `boop`
---
---
--- Inheritance
--- -----------
---
--- You can provide a base class to `create` to inherit from it:
---
--- .. code-block:: lua
---
---    --- @class Bar: Foo
---    local Bar = class.create("Bar", Foo)
---
--- You can override methods and properties of the base class:
---
--- .. code-block:: lua
---
---    function Bar:doSomething()
---        print("Doing something in Bar")
---        -- Call the super function.
---        Foo.doSomething(self)
---    end
---
---    Bar():doSomething() -- prints `Doing something in Bar`, then
---                        -- prints `Doing something in Foo`
---
---
--- Multiple inheritance and mixins
--- -------------------------------
---
--- This module does not support multiple inheritance. There is a mechanism
--- for emulating it, though.
---
--- Mixins are tables that can contain arbitrary functions or data. They are not
--- classes themselves, rather, they're similar to interfaces with default
--- implementations.
---
--- Let's create a simple mixin:
---
--- .. code-block:: lua
---
---    --- This is a mixin. Notice that it's not inherited from `Base`,
---    --- and we don't use `create` to make it.
---    ---
---    --- @class PrettyPrintable
---    local PrettyPrintable = {}
---
---    --- A function declared in the mixin.
---    function PrettyPrintable:pretty()
---        print("Default implementation for 'pretty'")
---    end
---
--- When creating a new class, you can pass mixins after the base class. All functions
--- and data in mixin tables will be copied to the class table:
---
--- .. code-block:: lua
---
---    --- This is a class that inherits `Foo`, and uses mixin `PrettyPrintable`.
---    ---
---    --- @class Baz: Foo, PrettyPrintable
---    local Baz = class.create("Baz", Foo, PrettyPrintable)
---
--- All members of `PrettyPrintable` were copied to `Baz`,
--- meaning that we can use them as usual:
---
---    Baz():pretty() -- prints `Default implementation for 'pretty'`
---
--- Notice that mixins are not true superclasses. `isChildOf` will not detect them,
--- and any changes made to them will not propagate to their children:
---
--- .. code-block:: lua
---
---    print(class.isChildOf(Baz, PrettyPrintable)) -- prints `false`
---
---    PrettyPrintable.newField = "newValue"
---    print(Baz.newField) -- prints `nil`
---
---
--- Declaring class methods
--- -----------------------
---
--- Class methods take class as a first parameter, instead of a class instance.
--- Lua doesn't distinguish between normal methods and class methods,
--- so it is possible to pass an instance to a class method:
---
--- .. code-block:: lua
---
---    function Foo:ClassMethod()
---        print(self)
---    end
---
---    Foo:ClassMethod() --> prints `Foo`
---    Foo():ClassMethod() --> prints `Foo()`
---
--- Here, `ClassMethod` expects that `self` is `Foo`, but instead
--- it is an instance of `Foo`.
---
--- To avoid errors, you can always get the class by its instance using the `__class`
--- attribute:
---
--- .. code-block:: lua
---
---    function Foo:ClassMethod()
---        local self = self.__class -- Make sure we're working with a class.
---        print(self)
---    end
---
---    Foo:ClassMethod() --> prints `Foo`
---    Foo():ClassMethod() --> also prints `Foo`
---
---
--- Declaring metamethods
--- ---------------------
---
--- You can declare metamethods which will be applied to class instances:
---
--- .. code-block:: lua
---
---    Point = class.create("Point")
---
---    function Point:__init(x, y)
---        self.x, self.y = x, y
---    end
---
---    function Point:__tostring()
---        return string.format("Point(%s, %s)", self.x, self.y)
---    end
---
---    print(Point(0, 0)) --> prints `Point(0, 0)`
---
--- Metamethods only act on class instances:
---
--- .. code-block:: lua
---
---    print(Point) --> doesn't call `__tostring`, just prints `Point`
---
--- .. warning::
---
---    You should declare all metamethods before subclassing or instantiating
---    a class, otherwise they will not be inherited correctly.
local ns = {}

--- Base class for all classes.
---
--- !doc special-members
--- !doc exclude-members: __tostring
--- @class Base
ns.Base = setmetatable({}, {
    __name = "Base",
    __tostring = function(self) return self.__name end,
    __call = function(_cls, ...)
        if not rawequal(_cls, ns.Base) then
            error(string.format("attempt to call a %s value", _cls), 2)
        end

        local self = setmetatable({}, ns.Base)
        ns.Base.__init(self --[[@as Base]], ...)
        return self
    end
})

--- Name of the class.
---
--- !doctype const
--- @type string
ns.Base.__name = "Base"

--- Name of the module this class was defined in.
---
--- !doctype const
--- @type string
ns.Base.__module = bootloader.getMod()

--- Full name of the class.
---
--- !doctype const
--- @type string
ns.Base.__fullname = ns.Base.__module .. "." .. ns.Base.__name

--- Function for converting class instances to strings.
---
--- @return string
function ns.Base:__tostring() return string.format("%s()", self.__name) end

--- Where to find attributes that are missing in a class instance.
--- By default, they are searched in the class table.
---
--- Note that overriding this field does not affect resolution of ``__init`` method.
---
--- !doctype const
--- @type table<string, any> | fun(self: Base, k: string): any
ns.Base.__index = ns.Base

--- Always points to the class itself.
---
--- Do not redefine, otherwise inheritance will break.
---
--- !doctype const
--- @type Base
ns.Base.__class = ns.Base

--- Always points to the base class.
---
--- Do not redefine, otherwise inheritance will break.
---
--- !doctype const
--- @type Base?
ns.Base.__base = nil

--- Constructor.
---
--- !doctype classmethod
function ns.Base:__init()
    -- nothing to do here
end

local metamethods = {
    ["__tostring"] = true,
    ["__gc"] = true,
    ["__add"] = true,
    ["__sub"] = true,
    ["__mul"] = true,
    ["__div"] = true,
    ["__mod"] = true,
    ["__pow"] = true,
    ["__unm"] = true,
    ["__idiv"] = true,
    ["__band"] = true,
    ["__bor"] = true,
    ["__bxor"] = true,
    ["__bnot"] = true,
    ["__shl"] = true,
    ["__shr"] = true,
    ["__concat"] = true,
    ["__len"] = true,
    ["__eq"] = true,
    ["__lt"] = true,
    ["__le"] = true,
    ["__index"] = true,
    ["__newindex"] = true,
    ["__call"] = true,
    ["__pairs"] = true,
    ["__close"] = true,
}

--- Create a new class. Optionally takes a base class.
---
--- @param name string class name, used for debug.
--- @param base Base? base class, defaults to `Base`.
--- @param ... table mixins.
--- @return any
function ns.create(name, base, ...)
    if type(name) ~= "string" then
        error("class name must be a string", 2)
    end

    base = base or ns.Base

    if not ns.isChildOf(base, ns.Base) then
        error("class base must be a class", 2)
    end
    if not rawequal(base, base.__class) then
        error("class base must be a class, got an instance", 2)
    end

    -- Class is a meta table for class instances.
    local cls = {}

    -- Inherit meta methods.
    for k, v in pairs(base) do
        if type(k) == "string" and metamethods[k] then
            cls[k] = v
        end
    end

    -- Inherit mixins.
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        if type(mixin) ~= "table" then
            error(string.format("mixin must be a table, got %s", type(mixin)))
        end
        if ns.isChildOf(mixin, ns.Base) then
            error(string.format("can't use class as a mixin: %s", mixin))
        end
        fun.t.update(cls, mixin)
    end

    -- Set meta attributes.
    cls.__name = name
    cls.__module = bootloader.getMod(2)
    cls.__fullname = cls.__module .. "." .. cls.__name
    cls.__class = cls
    cls.__base = base

    -- Set `__index` unless it's manually overloaded.
    if rawequal(cls.__index, base) then
        cls.__index = cls
    end

    -- Class' meta table can't be its base, otherwise class will behave
    -- like a base's instance. Instead, classes have special meta tables.
    setmetatable(cls, {
        __index = base,
        __name = name,
        __tostring = function(self) return self.__name end,
        __call = function(_cls, ...)
            if not rawequal(_cls, cls) then
                error(string.format("attempt to call a %s value", _cls), 2)
            end

            local self = setmetatable({}, cls)
            cls.__init(self, ...)
            return self
        end
    })

    return cls
end

--- Check if ``cls`` inherits ``base``.
---
--- @generic T: Base
--- @param cls Base? class or instance that is checked against ``base``.
--- @param base T expected base class.
--- @return boolean
--- @return_cast cls T
function ns.isChildOf(cls, base)
    if type(cls) ~= "table" or type(base) ~= "table" then
        return false
    end

    cls = cls.__class
    base = base.__class

    if not cls or not base then
        return false
    end

    while not rawequal(cls, nil) and not rawequal(cls, base) do
        cls = cls.__base
    end

    return rawequal(cls, base)
end

return ns
