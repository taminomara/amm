local class = require "ammcore/util/class"

--- Helpers for keeping track of machines.
local machineWatcher = {}

--- Scans network for machines of specific kind, and invokes callbacks
--- when a new machine appears or an old one disappears.
---
--- @class machineWatcher.MachineWatcher: class.Base
machineWatcher.MachineWatcher = class.create("MachineWatcher")

--- @generic T: machineWatcher.MachineWatcher
--- @param self T
--- @param nick string|Object-Class
--- @return T
function machineWatcher.MachineWatcher:New(nick)
    self = class.Base.New(self)

    --- @private
    --- @type string|Object-Class
    self._nick = nick

    --- @private
    --- @type table<integer, Object>
    self._machines = {}

    return self
end

--- Scan network and update the list of machines.
function machineWatcher.MachineWatcher:discover()
    local machines = {}

    for _, machine in ipairs(component.proxy(component.findComponent(self._nick)) --[[ @as Object[] ]]) do
        machines[machine.hash] = machine
        if not self._machines[machine.hash] then
            self:_added(machine)
        else
            self:_updated(machine)
        end
    end

    for _, machine in self._machines do
        if not machines[machine.hash] then
            self:_removed(machine)
        end
    end

    self._machines = machines
end

--- Called when a new machine appears.
---
--- @protected
--- @param machine Object
function machineWatcher.MachineWatcher:_added(machine)
    -- nothing to do here
end

--- Called when an old machine is seen again during discovery.
---
--- @protected
--- @param machine Object
function machineWatcher.MachineWatcher:_updated(machine)
    -- nothing to do here
end

--- Called when a machine disappears.
---
--- Note: when this function is called, `machine` is not available anymore,
--- so interacting with it will result in an error.s
---
--- @protected
--- @param machine Object
function machineWatcher.MachineWatcher:_removed(machine)
    -- nothing to do here
end

return machineWatcher
