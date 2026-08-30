-- tests/test_all.lua
-- Runner global existente: cada archivo se ejecuta en un proceso Lua independiente.
-- Esto conserva el aislamiento que ya tenia la suite y evita crear un segundo runner.

local tests = {
    "tests/smoke_test.lua",
    "tests/classification_test.lua",
    "tests/utils_test.lua",
    "tests/interrupt_test.lua",
    "tests/decision_test.lua",
    "tests/cast_test.lua",
    "tests/threat_test.lua",
    "tests/absorb_test.lua",
    "tests/lifecycle_test.lua",
    "tests/overlays_test.lua",
    "tests/target_test.lua",
    "tests/focus_test.lua",
    "tests/widgets_test.lua",
    "tests/pips_test.lua",
    "tests/wheel_test.lua",
    "tests/menu_test.lua",
    "tests/equivalence_test.lua",
    "tests/friendly_filter_safety_net_test.lua",
    "tests/threat_monitor/stable_state_test.lua",
    "tests/benchmark/benchmark.lua",
}

local failures = {}

print("Running tests...")
for _, t in ipairs(tests) do
    io.write("- ", t, " ... ")
    io.flush()
    local cmd = string.format('lua "%s" 2>&1', t)
    local handle = io.popen(cmd)
    local out = handle:read("*a") or ""
    handle:close()

    local found = false
    for line in out:gmatch("([^\n\r]+)") do
        if line:find("FAIL") then
            found = true
            break
        end
    end

    if found then
        print("FAIL")
        table.insert(failures, { test = t, output = out })
    else
        print("OK")
    end
end

if #failures == 0 then
    print("\nAll tests passed.")
    os.exit(0)
end

print("\n=== FAILURES SUMMARY ===")
for _, f in ipairs(failures) do
    print("\n-- " .. f.test)
    for line in f.output:gmatch("([^\n\r]+)") do
        if line:find("FAIL") then
            print(line)
        end
    end
end

os.exit(1)
