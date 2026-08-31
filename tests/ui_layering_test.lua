-- tests/ui_layering_test.lua
-- Structural tests for the UI layering ownership contract.

local function read(path)
    local fh = assert(io.open(path, "r"), "cannot open " .. path)
    local content = fh:read("*a")
    fh:close()
    return content
end

local function assert_true(condition, message)
    if not condition then error("FAIL: " .. message, 0) end
    print("OK: " .. message)
end

local halo = read("Overlays/Halo.lua")
local widgets = read("Overlays/Widgets.lua")
local target = read("Overlays/Target.lua")
local focus = read("Overlays/Focus.lua")
local wheel = read("Wheel/Wheel.lua")
local pips = read("Wheel/Pips.lua")
local toc = read("Minimizer.toc")

assert_true(halo:match("Minimizer%.Halo%s*=%s*Halo"), "Halo owns its public component API")
assert_true(not halo:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Halo never imposes HIGH")
assert_true(not widgets:match("CreateHalo"), "Widgets no longer owns Halo creation")
assert_true(not widgets:match("UpdateHalo"), "Widgets no longer owns Halo updates")

assert_true(target:match("Minimizer%.Halo%.Create"), "Target consumes the reusable Halo component")
assert_true(target:match("haloFrame:SetHost%(%s*plate%s*%)"), "Target supplies the nameplate render host")
assert_true(not target:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Target does not use HIGH as a fallback")

assert_true(focus:match("frame:SetParent%(%s*plate%s*%)"), "Focus supplies the nameplate as its render parent")
assert_true(not focus:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Focus does not use HIGH as a fallback")

assert_true(wheel:match("wheelFrame:SetFrameStrata%(%s*[\"']MEDIUM[\"']%s*%)"), "Wheel uses the normal player UI strata")
assert_true(not wheel:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Wheel never uses HIGH")
assert_true(not wheel:match("wheelFrame:SetFrameLevel%(%s*100%s*%)"), "Wheel has no arbitrary global frame level")

assert_true(not pips:match("SetFrameStrata%s*%("), "Pips inherit the Wheel render context")
assert_true(pips:match("pip:SetFrameLevel%(%s*%(%s*parentFrame:GetFrameLevel"), "Pips retain a relative frame level")

local haloPos = assert(toc:find("Overlays/Halo.lua", 1, true))
local focusPos = assert(toc:find("Overlays/Focus.lua", 1, true))
local targetPos = assert(toc:find("Overlays/Target.lua", 1, true))
local wheelPos = assert(toc:find("Wheel/Wheel.lua", 1, true))
assert_true(haloPos < focusPos and haloPos < targetPos, "TOC loads Halo before its consumers")
assert_true(wheelPos < focusPos and wheelPos < targetPos, "TOC keeps player wheel before overlay consumers")

print("UI layering structural tests passed")
