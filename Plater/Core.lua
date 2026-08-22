local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Core = Minimizer.Core or {}
Minimizer.Modules = Minimizer.Modules or {}
Minimizer.ModuleList = Minimizer.ModuleList or {}

local type = type
local pcall = pcall
local GetTime = GetTime

local _module_error_throttle = {}
local _MODULE_ERROR_THROTTLE_SECONDS = 10

function Minimizer.Core.RegisterModule(name, module)
    if type(name) ~= "string" or type(module) ~= "table" then return end
    Minimizer.Modules[name] = module
    module.MinimizerModuleName = name
    Minimizer.ModuleList[#Minimizer.ModuleList + 1] = module
end

function Minimizer.Core.UpdateModules(unit, nameplate, snapshot)
    local list = Minimizer.ModuleList
    for i = 1, #list do
        local module = list[i]
        if type(module.UpdateNamePlate) == "function" then
            local ok, err = pcall(module.UpdateNamePlate, module, unit, nameplate, snapshot)
            if not ok then
                local name = module.MinimizerModuleName or "?"
                local now = GetTime and GetTime() or 0
                local last = _module_error_throttle[name]
                if not last or (now - last) >= _MODULE_ERROR_THROTTLE_SECONDS then
                    _module_error_throttle[name] = now
                    print("|cffff4444Minimizer|r: Error in module " .. name .. ": " .. tostring(err))
                end
            end
        end
    end
end

