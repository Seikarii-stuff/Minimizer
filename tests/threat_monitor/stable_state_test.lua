-- tests/threat_monitor/stable_state_test.lua
-- Verify memory stability when threat monitor runs with static units
local Mocks = dofile('tests/wow_mock.lua')
local addon = {}
local function LoadAddonFile(path)
  local f, e = loadfile(path)
  if not f then error('load error: '..e) end
  f('Minimizer', addon)
end
-- Load all addon Lua files via toc (fallback if filelist not available)
local files = {}
local tocPath = 'Minimizer.toc'
local fh = io.open(tocPath, 'r')
if fh then
  for line in fh:lines() do
    local trimmed = line:match('^%s*(.-)%s*$')
    trimmed = trimmed:gsub('\\\\', '/'):gsub('^%./', '')
    if trimmed ~= '' and not trimmed:match('^#') and trimmed:match('%.lua$') then
      table.insert(files, trimmed)
    end
  end
  fh:close()
end
for _, f in ipairs(files) do LoadAddonFile(f) end
Mocks.FireEvent('ADDON_LOADED', 'Minimizer')

local unit = 'nameplate1'
Mocks.CreateTestUnit(unit, {name='Enemy', level=70, health=100, healthMax=100, inCombat=true, canAttackPlayer=true, threatSituation=1})
Mocks.CreateTestNameplate(unit)
Mocks.FireEvent('NAME_PLATE_UNIT_ADDED', unit)

local initialMem = collectgarbage('count')
local ticks = 1000
for i=1,ticks do
  Mocks.AdvanceTime(0.1)
  if addon.Dispatcher and addon.Dispatcher.ApplyToAll then
    addon.Dispatcher.ApplyToAll()
  end
end
local finalMem = collectgarbage('count')
local diff = finalMem - initialMem
assert(diff <= 5, 'Memory drift too high: '..diff..'KB')
print('Stable state test passed, memory drift '..diff..'KB')
