local gui = require "ammgui"
local dom = require "ammgui.dom"
local fun = require "ammcore.fun"

event.ignoreAll()
event.clear()

-- Page
local page = dom.functional(function(ctx, params)
    return dom.div {
        dom.h1 { "Manufacturer control" },
        dom.p {
            dom.em { "recipe = " }, params.recipe.name,
        },
        dom.h2 { "Available recipes" },
        dom.list(fun.a.map(params.recipes, function(recipe)
            return dom.p {
                recipe.name,
                onClick = function() params.setRecipe() end
            }
        end)),
    }
end)

-- Controller
local gpu = assert(computer.getPCIDevices(classes.FINComputerGPUT2)[1])
local screen = assert(computer.getPCIDevices(classes.Build_ScreenDriver_C)[1])
gpu:bindScreen(screen)

local manufacturer = component.proxy(assert(component.findComponent(classes.Manufacturer)[1])) --[[ @as Manufacturer ]]

local function setRecipe(recipe)
    manufacturer:setRecipe(recipe)
end

local function makeData()
    return {
        recipe = manufacturer:getRecipe(),
        recipes = manufacturer:getRecipes(),
        setRecipe = setRecipe
    }
end

local app = gui.App:New(gpu, page, makeData())

event.listen(manufacturer)
event.registerListener({ sender = manufacturer, event = "ProductionChanged" }, function()
    app:setData(makeData())
end)

app:start()
future.loop()
