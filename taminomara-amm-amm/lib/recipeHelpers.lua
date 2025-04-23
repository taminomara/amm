local class = require "ammcore.class"
local fun = require "ammcore.fun"

--- Helpers for passing recipes around the network.
local recipeHelpers = {}

--- A serializeable recipe class.
---
--- There's no easy way to get a recipe by its internal name, so we make do...
---
--- @class recipeHelpers.Recipe: ammcore.class.Base
recipeHelpers.Recipe = class.create("Recipe")

--- @param recipe Recipe-Class
function recipeHelpers.Recipe:New(recipe)
    self = class.Base.New(self)

    self.hash = recipe.hash
    self.name = recipe.name
    self.duration = recipe.duration
    self.ingredients = recipe:getIngredients()
    self.products = recipe:getProducts()

    return self
end

--- @param recipes Recipe-Class[]
function recipeHelpers.Recipe:NewArray(recipes)
    return fun.a.map(recipes, self.New, self)
end

return recipeHelpers
