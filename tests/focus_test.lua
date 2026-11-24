local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.playerSpells = { [147362] = true }
Mocks.cooldowns[147362] = { start = Mocks.time, duration = 15 }
MinimizerDB.enableFocusFace = true

Mocks.CreateTestUnit("focus", { name = "Focus Mob", level = 70, faction = "Horde", guid = "focus_guid" })
Mocks.CreateTestNameplate("focus")
addonTable.Focus:UpdateFace()

local portrait = _G.MinimizerFocusPortrait
local cooldown = _G.MinimizerFocusCooldown
check(portrait ~= nil and portrait:IsShown() == true, "Focus: muestra portrait cuando esta habilitado y existe focus")
check(addonTable.Focus.Pips == nil, "Focus: no posee ni consume una coleccion de Pips")
check(addonTable.Focus.Halo == nil, "Focus: no consume el componente Halo")
check(addonTable.Overlays.Get("Focus") == addonTable.Focus, "Focus: esta registrado en Overlays")

local source = assert(io.open("Overlays/Focus.lua", "r")):read("*a")
check(source:match("frame:SetParent%(%s*plate%s*%)"), "Focus: portrait usa la nameplate como contexto")
check(not source:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Focus: no fuerza HIGH")
check(source:match("frame:SetFrameLevel%(%s*plateLevel%s*%+%s*1%s*%)"), "Focus: portrait conserva FrameLevel relativo")
check(source:match('glow:SetTexture%(%s*["\']Interface\\\\Buttons\\\\WHITE8x8["\']%s*%)'), "Focus: usa un relleno circular solido")
check(source:match('glowMask:SetTexture%(%s*["\']Interface\\\\Masks\\\\CircleMaskScalable["\']'), "Focus: enmascara el glow con un circulo")
check(source:match("glow:AddMaskTexture%(%s*glowMask%s*%)"), "Focus: aplica la mascara al relleno")
check(not source:match("UI%-ActionButton%-Border"), "Focus: ya no usa el contorno cuadrado")
check(source:match("glow:SetVertexColor%(%s*1%.0%s*,%s*0%.78%s*,%s*0%.05%s*,%s*1%.0%s*%)"), "Focus: aplica el color amarillo al glow")
check(source:match("glowFrame:SetFrameLevel%(%s*plateLevel%s*%+%s*3%s*%)"), "Focus: el glow usa la capa superior")
check(source:match('CreateFrame%(%s*["\']Frame["\']%s*,%s*["\']MinimizerFocusGlow["\']'), "Focus: el glow vive en un frame independiente")

local glowFrame = _G.MinimizerFocusGlow
check(glowFrame ~= nil and glowFrame:IsShown() == true, "Focus: muestra el glow independiente")
check(glowFrame and glowFrame:GetParent() == _G.C_NamePlate.GetNamePlateForUnit("focus"), "Focus: ancla el glow a la plate del focus")
check(glowFrame and glowFrame:GetFrameLevel() == ((_G.C_NamePlate.GetNamePlateForUnit("focus"):GetFrameLevel() or 0) + 3), "Focus: glow queda sobre target-of-target")

MinimizerDB.enableFocusFace = false
addonTable.Focus:UpdateFace()
check(portrait:IsShown() == false, "Focus: se oculta cuando face esta deshabilitado")
check(glowFrame:IsShown() == false, "Focus: el glow se oculta cuando face esta deshabilitado")

T.finish("FOCUS TESTS")
