local dom = require "ammgui.dom"
local fun = require "ammcore.fun"
local log = require "ammcore.log"

--- Tab switcher.
---
--- !doctype module
--- @class ammgui.dom.tabs
local ns = {}

local logger = log.Logger:New()

--- @class ammgui.dom.tabs.Tab: ammgui.dom.FunctionalParamsWithChildren
--- @field title ammgui.dom.AnyNode
--- @field key any

--- @class ammgui.dom.tabs.TabsManualParams: ammgui.dom.FunctionalParams
--- @field currentTab any
--- @field setCurrentTab fun(currentTab: any)
--- @field additionalTabs ammgui.dom.AnyNode?
--- @field small boolean?
--- @field fullHeight boolean?
--- @field class string?
--- @field [integer] ammgui.dom.tabs.Tab

--- @class ammgui.dom.tabs.TabsParams: ammgui.dom.FunctionalParams
--- @field initialTab any
--- @field additionalTabs ammgui.dom.AnyNode?
--- @field small boolean?
--- @field fullHeight boolean?
--- @field class string?
--- @field [integer] ammgui.dom.tabs.Tab

--- @param ctx ammgui.Context
--- @param currentTab any
--- @param setCurrentTab fun(currentTab: any)?
--- @return ammgui.dom.AnyNode
local function _tabsInner(ctx, params, currentTab, setCurrentTab)
    local fullHeight = params.fullHeight or false
    return dom.div {
        class = { "__amm_tabs", fullHeight and "__amm_tabs__full", params.class },
        dom.div {
            class = { "__amm_tabs__tabs", params.small and "small" },
            dom.map(params, function(tab, i)
                if i % 2 == 1 then
                    if i == #params then
                        return dom.list {
                            key = "__amm_tabs__tab_spacer",
                            dom.div { class = "__amm_tabs__tab_spacer" },
                            tab,
                        }
                    else
                        return dom.div {
                            class = {
                                "__amm_tabs__tab",
                                tab.key == currentTab and "__amm_tabs__tab__current",
                            },
                            key = tab.key,
                            onClick = function()
                                if setCurrentTab then
                                    setCurrentTab(tab.key)
                                end
                            end,
                            tab,
                        }
                    end
                end
            end),
        },
        -- dom.div {
        --     class = "__amm_tabs__tabs_sep",
        -- },
        dom.map(params, function(tab, i)
            if i % 2 == 0 then
                return dom.div {
                    class = {
                        "__amm_tabs__content",
                        fullHeight and "__amm_tabs__content__full",
                        tab.key == currentTab and "__amm_tabs__content__current",
                    },
                    key = tab.key,
                    tab,
                }
            end
        end),
    }
end

--- @param ctx ammgui.Context
--- @return ammgui.dom.AnyNode
local function _tabsManual(ctx, params)
    return _tabsInner(ctx, params, params.currentTab, params.setCurrentTab)
end

local tabsManual = dom.Functional(_tabsManual)

--- @param ctx ammgui.Context
--- @return ammgui.dom.AnyNode
local function _tabs(ctx, params)
    local currentTab, setCurrentTab = ctx:useState(params.initialTab)
    return _tabsInner(ctx, params, currentTab, setCurrentTab)
end

local tabs = dom.Functional(_tabs)

--- @param params ammgui.dom.tabs.TabsManualParams | ammgui.dom.tabs.TabsParams
local function makeTabs(params)
    params = fun.t.copy(params)
    local children = {}
    for i, v in ipairs(params) do
        if not v.key then
            logger:warning("All tabs must have a unique key.")
            v.key = i
        end
        if not params.currentTab then
            params.currentTab = v.key
        end
        if not params.initialTab then
            params.initialTab = v.key
        end
        table.insert(children, dom.list { key = v.key, v.title or string.format("Tab %s", i) })
        table.insert(children, dom.list(v))
        params[i] = nil
    end
    if params.additionalTabs then
        table.insert(children, params.additionalTabs)
        params.additionalTabs = nil
    end
    return fun.a.extend(params, children)
end

--- Create a tab switcher.
---
--- Accepts an array of tabs. Each tab is a lua table with array items representing
--- its body; it must have a unique ``key`` and ``title`` properties.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    local tabs = dom.Tabs {
---        {
---            key = 1,
---            title = "Tab 1",
---            dom.div { "Body of tab 1." },
---        },
---        {
---            key = 2,
---            title = "Tab 2",
---            dom.div { "Body of tab 2." },
---        },
---    }
---
--- **Example: selecting an initial tab**
---
--- You can pass key of the tab that will be displayed when component
--- is first mounted via the ``initialTab`` property:
---
--- .. code-block:: lua
---
---    local tabs = dom.Tabs {
---        initialTab = 2,
---        -- ...
---    }
---
--- **Example: smaller tabs**
---
--- Sometimes you want your tabs to look smaller, so that they don't draw too much
--- attention from other content. You can pass the ``small`` property in these cases:
---
--- .. code-block:: lua
---
---    local tabs = dom.Tabs {
---        small = true,
---        -- ...
---    }
---
--- **Example: additional buttons in tabs row**
---
--- You can pass a list of nodes to the ``additionalTabs`` property. These nodes
--- will be displayed in the tabs row to the right of actual tabs:
---
--- .. code-block:: lua
---
---    local tabs = dom.Tabs {
---        additionalTabs = dom.list {
---            dom.button { "Save" },
---            dom.button { "Load" },
---        },
---        -- ...
---    }
---
--- These nodes will not have any additional behavior, you will need to program them
--- using callbacks.
---
--- @param params ammgui.dom.tabs.TabsParams
--- @return ammgui.dom.FunctionalNode
function ns.Tabs(params)
    return tabs(makeTabs(params))
end

--- Create a tab switcher that you can manually control via callbacks.
---
--- This component behaves similar to `Tabs`, but it takes two additional properties:
---
--- - ``currentTab`` should contain key of the currently selected tab,
--- - ``setCurrentTab`` should contain a callback that will be invoked when the user
---   clicks on another tab.
---
--- **Example: manually controlling tabs**
---
--- .. code-block:: lua
---
---    local myTabs = dom.Functional(function(ctx, params)
---        -- We have full control over which tab is selected.
---        local currentTab, setCurrentTab = ctx:useState(1);
---
---        -- We can use `setCurrentTab` in other components.
---        -- For example, we can create a button that sends us
---        -- to the first tab:
---        local homeButton = dom.button {
---            "Home",
---            onClick = function()
---                setCurrentTab(1)
---            end
---        }
---
---        return dom.div {
---            homeButton,
---
---            -- We pass `currentTab` and `setCurrentTab` to `TabsManual`,
---            -- thus controlling it from the current component.
---            dom.TabsManual {
---                currentTab = currentTab,
---                setCurrentTab = setCurrentTab,
---                {
---                    key = 1,
---                    title = "Tab 1",
---                    dom.div { "Body of tab 1." },
---                },
---                {
---                    key = 2,
---                    title = "Tab 2",
---                    dom.div { "Body of tab 2." },
---                },
---            }
---        }
---    end)
---
--- @param params ammgui.dom.tabs.TabsManualParams
--- @return ammgui.dom.FunctionalNode
function ns.TabsManual(params)
    return tabsManual(makeTabs(params))
end

return ns
