local fragmentBackend = require "ammgui._impl.backend.fragment"
local fun = require "ammcore.fun"

--- Component that represents a list of other components without an enclosing DOM node.
---
--- !doctype module
--- @class ammgui.component.fragment
local ns = {}

--- Parameters for a fragment component.
---
--- See `fragment` for details.
---
--- @class ammgui.component.fragment.FragmentParams: ammgui.component.Params
--- @field [integer] ammgui.component.Any Children.

--- Component that represents a list of other components without an enclosing DOM node.
---
--- See `fragment` for details.
---
--- @class ammgui.component.fragment.Fragment: ammgui.component.fragment.FragmentParams, ammgui.component.Component
--- @field package _isComponent true
--- @field package _backend ammgui._impl.backend.fragment.FragmentComponent

--- Concatenate an array of components into a single component without enclosing
--- them into a DOM node.
---
--- This utility is helpful when you need to return multiple nodes from a function,
--- but don't want to wrap them into a ``<div>``.
---
--- It can also be used to add keys or refs to an existing node.
---
--- .. tip::
---
---    Lua arrays don't work nicely with `nil` values. If you have an array
---    of ``{ 1, 2, nil, 4 }``, Lua will think that array has only two elements.
---
---    To avoid potential mistakes, prefer using `map` or functional utilities
---    from `ammcore.fun` to avoid manual table insertions.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    local tabSet = dom.Functional(function()
---        return dom.fragment {
---            dom.text { class = "tab", "Tab 1" },
---            dom.text { class = "tab", "Tab 2" },
---            dom.text { class = "tab", "Tab 3" },
---        }
---    end)
---
--- **Example: handling functional component's body**
---
--- Here, we create a functional component that accepts children
--- and wraps them in a ``div``. We use `fragment` to extract passed children
--- and group them into a single fragment.
---
--- .. code-block:: lua
---
---    local tab = dom.Functional(function(ctx, params)
---        return dom.div {
---            dom.h1 { params.title },
---            dom.fragment(params),
---        }
---    end)
---
--- We can now use our ``tab`` component like so:
---
--- .. code-block:: lua
---
---    tab {
---        title = "Tab 1",
---        dom.p { "This is tab's body." }
---        dom.p { "We can pass multiple nodes here." }
---        dom.p { "All of them will end up in a fragment." }
---    }
---
--- @param params ammgui.component.fragment.FragmentParams
--- @return ammgui.component.fragment.Fragment
function ns.fragment(params)
    -- Note: we don't modify `params` in-place because it's a common pattern to pass
    -- functional component's params into `fragment`.
    local component = fun.a.copy(params) --[[ @as ammgui.component.fragment.Fragment ]]
    component._isComponent = true
    component._backend = fragmentBackend.fragmentComponent
    component.key = params.key
    return component
end

--- A helper that applies a function to each element of an array,
--- and gathers results into a `fragment`.
---
--- This is a useful function that helps with building lists of components
--- from arrays of data.
---
--- Note that the mapper function can return `nil` to skip a node.
---
--- **Example:**
---
--- Let's suppose that you have an array of recipes, and you want to display them.
--- For each recipe, you need to create a DOM node with recipe's description,
--- then gather these nodes into a fragment.
---
--- The naive approach would be to iterate over recipes using a for-loop,
--- and push descriptions into an array:
---
--- .. code-block:: lua
---
---    local descriptions = dom.fragment {}
---    for _, recipe in ipairs(recipes) do
---        table.insert(descriptions, dom.p { recipe.name })
---    end
---
--- This code is clunky and tedious to write. Instead, we can map an array of recipes
--- using this helper:
---
--- .. code-block:: lua
---
---    local descriptions = dom.map(recipes, function(recipe)
---        return dom.p { recipe.name }
---    )
---
--- @generic T
--- @param arr T[] array to be mapped.
--- @param fn fun(x: T, i: number): ammgui.component.Any|nil mapper.
--- @return ammgui.component.fragment.Fragment
function ns.map(arr, fn)
    local component = fun.a.map(arr, fn) --[[ @as ammgui.component.fragment.Fragment ]]
    component._isComponent = true
    component._backend = fragmentBackend.fragmentComponent
    return component
end

return ns
