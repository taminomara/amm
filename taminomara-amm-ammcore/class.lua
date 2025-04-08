local array = require "ammcore._util.array"
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
---    class = require "ammcore.class"
---
---    --- @class Foo: ammcore.class.Base
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
--- You can now create instances of your class by calling `New`.
--- Note that all class methods (i.e. methods that accept class as a first
--- parameter, rather than a class instance) start with a capital letter:
---
--- .. code-block:: lua
---
---    local foo = Foo:New()
---
---
--- Inheriting a class
--- ------------------
---
--- You can provide a base class to `create` to inherit from it:
---
--- .. code-block:: lua
---
---    class = require "ammcore.class"
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
--- Similarly, you can override `New`:
---
--- .. code-block:: lua
---
---    function Bar:New()
---        -- Replace `self` with a new instance of `Bar`.
---        self = Foo.New(self)
---        -- Initialize the new instance.
---        self.beep = "boop"
---        -- Don't forget to return `self`.
---        return self
---    end
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
---    Foo:New():ClassMethod() --> prints `Foo()`
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
---        self = self.__class -- Make sure we're working with a class.
---        print(self)
---    end
---
---    Foo:ClassMethod() --> prints `Foo`
---    Foo:New():ClassMethod() --> also prints `Foo`
---
---
--- Declaring metamethods
--- ---------------------
---
--- You can declare metamethods which will be applied to class instances:
---
--- .. code-block:: lua
---
---    class = require "ammcore.class"
---
---    Point = class.create("Point")
---
---    function Point:New(x, y)
---        self = class.Base.New(self)
---        self.x, self.y = x, y
---        return self
---    end
---
---    function Point:__tostring()
---        return string.format("Point(%s, %s)", self.x, self.y)
---    end
---
---    print(Point:New(0, 0)) --> prints `Point(0, 0)`
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
---
--- !doctype module
--- @class ammcore.class
local ns = {}

--- Base class for all classes.
---
--- !doc special-members
--- !doc exclude-members: __tostring
--- !doc deprecated
--- @class ammcore.class.Base
ns.Base = setmetatable({}, { __name = "Base", __tostring = function(self) return self.__name end })

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
--- You can redefine this as a function that takes a key and returns a value.
--- Do not redefine as a table, otherwise it will not be inherited properly.
---
--- !doctype const
--- @type table<string, any> | fun(self: ammcore.class.Base, k: string): any
ns.Base.__index = ns.Base

--- Always points to the class itself.
---
--- Do not redefine, otherwise inheritance will break.
---
--- !doctype const
--- @type ammcore.class.Base
ns.Base.__class = ns.Base

--- Always points to the base class.
---
--- Do not redefine, otherwise inheritance will break.
---
--- !doctype const
--- @type ammcore.class.Base?
ns.Base.__base = nil

--- Constructor.
---
--- !doctype classmethod
--- @generic T: ammcore.class.Base
--- @param self T
--- @return T
function ns.Base:New()
    --- @diagnostic disable-next-line: undefined-field
    return setmetatable({}, self.__class)
end

--- A class method that will be called whenever a new subclass is created.
---
--- Whenever a new subclass is created using this class as a base,
--- this method is called with subclass being ``self``. Specifically,
--- this method is called from `create`, so the subclass
--- will not have any properties or methods present.
---
--- !doctype classmethod
--- @generic T: ammcore.class.Base
--- @param self T
--- @param ... any all extra arguments passed to `create`.
--- @protected
function ns.Base:__initSubclass(...)
    local l = select("#", ...)
    if l > 0 then
        error(string.format(
            "__initSubclass got %s unexpected argument%s: %s",
            l,
            l == 1 and "" or "s",
            table.concat(array.map({ ... }, tostring), ", ")
        ))
    end
end

--- Create a new class. Optionally takes a base class.
---
--- @param name string class name, used for debug.
--- @param base ammcore.class.Base? base class, defaults to `Base`.
--- @param ... any other arguments will be passed to `Base.__initSubclass`.
--- @return any
function ns.create(name, base, ...)
    if type(name) ~= "string" then error("class name must be a string", 2) end
    base = base or ns.Base
    if not ns.isChildOf(base, ns.Base) then error("class base must be a class", 2) end
    if not rawequal(base, base.__class) then error("class base must be a class, got an instance", 2) end

    -- Class is a meta table for class instances.
    local cls = {}

    -- Inherit meta methods.
    for k, v in pairs(base) do
        if type(k) == "string" and k:match("^__[a-z]+$") then
            cls[k] = v
        end
    end

    -- Set meta attributes.
    cls.__name = name
    cls.__module = bootloader.getMod(2)
    cls.__fullname = cls.__module .. "." .. cls.__name
    cls.__class = cls
    cls.__base = base

    -- Set `__index` unless it's manually overloaded.
    if type(cls.__index) ~= "function" then
        cls.__index = cls
    end

    -- Class' meta table can't be its base, otherwise class will behave
    -- like a base's instance. Instead, classes have special meta tables.
    setmetatable(cls, {
        __index = base,
        __name = name,
        __tostring = function(self) return self.__name end,
    })

    -- Run `__initSubclass` on the base class.
    --- @diagnostic disable-next-line: invisible, redundant-parameter
    base.__initSubclass(cls, ...)

    return cls
end

--- Check if ``cls`` inherits ``base``.
---
--- @param cls ammcore.class.Base class or instance that is checked against ``base``.
--- @param base ammcore.class.Base expected base class.
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
