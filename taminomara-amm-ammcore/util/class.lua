local debugHelpers = require "ammcore/util/debugHelpers"

--- Support library for OOP in lua.
---
---
--- # Creating a class
---
--- You can create a new class by calling `class.create`.
--- Unless specified, the new class will inherit `class.Base`,
--- so you can annotate it accordingly:
---
--- ```
--- --- @class Foo: class.Base
--- local Foo = class.create("Foo")
---
--- function Foo:doSomething()
---     print("Doing something in Foo")
--- end
--- ```
---
---
--- # Instantiating a class
---
--- You can now create instances of your class by calling `New`.
--- Note that all class methods (i.e. methods that accept class as a first
--- parameter, rather than a class instance) start with a capital letter:
---
--- ```
--- local foo = Foo:New()
--- ```
---
---
--- # Inheriting a class
---
--- You can provide a base class to `class.create` to inherit from it:
---
--- ```
--- --- @class Bar: Foo
--- local Bar = class.create("Bar", Foo)
--- ```
---
--- You can override methods and properties of the base class:
---
--- ```
--- function Bar:doSomething()
---     print("Doing something in Bar")
---     -- Call the super function.
---     Foo.doSomething(self)
--- end
--- ```
---
--- Similarly, you can override `New`:
---
--- ```
--- function Bar:New()
---     -- Replace `self` with a new instance of `Bar`.
---     self = Foo.New(self)
---     -- Initialize the new instance.
---     self.beep = "boop"
---     -- Don't forget to return `self`.
---     return self
--- end
--- ```
---
---
--- # Declaring class methods
---
--- Class methods take class as a first parameter, instead of a class instance.
--- Lua doesn't distinguish between normal methods and class methods,
--- so it is possible to pass an instance to a class method:
---
--- ```
--- function Foo:ClassMethod()
---     print(self)
--- end
---
--- Foo:ClassMethod() --> prints `Foo`
--- Foo:New():ClassMethod() --> prints `Foo()`
--- ```
---
--- Here, `ClassMethod` expects that `self` is `Foo`, but instead
--- it is an instance of `Foo`.
---
--- To avoid errors, you can always get the class by its instance using the `__class`
--- attribute:
---
--- ```
--- function Foo:ClassMethod()
---     self = self.__class -- Make sure we're working with a class.
---     print(self)
--- end
---
--- Foo:ClassMethod() --> prints `Foo`
--- Foo:New():ClassMethod() --> also prints `Foo`
--- ```
---
---
--- # Declaring metamethods
---
--- You can declare metamethods which will be applied to class instances:
---
--- ```
--- Point = class.create("Point")
---
--- function Point:New(x, y)
---     self = class.Base.New(self)
---     self.x, self.y = x, y
---     return self
--- end
---
--- function Point:__tostring()
---     return string.format("Point(%s, %s)", self.x, self.y)
--- end
---
--- print(Point:New(0, 0)) --> prints `Point(0, 0)`
--- ```
---
--- Metamethods only act on class instances:
---
--- ```
--- print(Point) --> doesn't call `__tostring`, just prints `Point`
--- ```
---
--- Note that you should declare all metamethods before subclassing or instantiating
--- a class, otherwise they will not be inherited correctly.
local class = {}

--- Base class for all classes.
---
--- @class class.Base
class.Base = setmetatable({}, { __name = "Base", __tostring = function(self) return self.__name end })

--- Name of the class.
---
--- @type string
class.Base.__name = "Base"

--- Name of the module this class was defined in.
---
--- @type string
class.Base.__module = debugHelpers.getMod()

--- Full name of the class.
---
--- @type string
class.Base.__fullname = class.Base.__module .. "." .. class.Base.__name

--- Function for converting class instances to strings.
---
--- @return string
function class.Base:__tostring() return string.format("%s()", self.__name) end

--- Where to find attributes that are missing in a class instance.
--- By default, they are searched in the class table.
---
--- You can redefine this as a function that takes a key and returns a value.
--- Do not redefine as a table, otherwise it will not be inherited properly.
---
--- @type table | fun(k: string): any
class.Base.__index = class.Base

--- Always points to the class itseld.
---
--- Do not redefine, otherwise inheritance will break.
---
--- @type class.Base
class.Base.__class = class.Base

--- Always points to the base class.
---
--- Do not redefine, otherwise inheritance will break.
---
--- @type class.Base?
class.Base.__base = nil

--- A class method that will be called whenever a new subclass is created.
---
--- Whenever a new subclass is created using this class as a base,
--- this method is called with subclass being `self`. Specifically,
--- this method is called from `class.create`, so the subclass
--- will not have any properties or methods present.
---
--- @protected
function class.Base:__initSubclass() end

--- Constructor.
---
--- @generic T: class.Base
--- @param self T
--- @return T
function class.Base:New()
    return setmetatable({}, self.__class)
end

--- Create a new class. Optionally takes a base class.
---
--- @param name string Class name, used for debug.
--- @param base class.Base? Base class, defaults to `class.Base`.
--- @param ... any Other arguments will be passed to `base.__initSubclass`.
--- @return any
function class.create(name, base, ...)
    if type(name) ~= "string" then error("Class name must be a string") end
    base = base or class.Base
    if not class.isChildOf(base, class.Base) then error("Class base must be a class") end
    if not rawequal(base, base.__class) then error("Class base must be a class, got an instance") end

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
    cls.__module = debugHelpers.getMod(2)
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
        __tostring = function(self) return self.__name end
    })

    --- Run `__initSubclass` on the base class.
    --- @diagnostic disable-next-line: invisible, redundant-parameter
    base.__initSubclass(cls, ...)

    return cls
end

--- Check if `cls` inherits `base`.
---
--- @param cls class.Base
--- @param base class.Base
function class.isChildOf(cls, base)
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

return class
