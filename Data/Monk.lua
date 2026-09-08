local Core = MidnightSensei.Core

Core.RegisterSpec(10, {
    className = "Monk",

    -- Brewmaster (Midnight 12.0 PASSIVE audit — April 2026; May 2026 Archon sweep)
    -- Celestial Brew (322507) ADDED 09/06/2026 — confirmed active talent (Rank 0/1, 1.5 min CD
    --   absorb shield); prior "not in tree" note was wrong or predated the finalized tree; expected
    --   to be used regularly, not held.
    -- Exploding Keg (325153) added to majorCooldowns — nodeID 101197 non-PASSIVE ACTIVE
    -- Black Ox Brew (115399) added to majorCooldowns talentGated — May 2026; Spell ID confirmed in-game tooltip;
    --   2 min CD; refills Energy + all Purifying Brew charges + 1 Celestial Brew/Infusion charge; expected on longer fights
    -- Celestial Infusion (1241059) added to majorCooldowns — nodeID 101067 non-PASSIVE ACTIVE
    -- Spear Hand Strike (116705) added as isInterrupt — nodeID 101152 non-PASSIVE ACTIVE
    -- Ironskin Brew (215479) removed from uptimeBuffs — not in Midnight 12.0 talent tree or spell list
    -- Breath of Fire (115181) added to rotational — nodeID 101069 non-PASSIVE ACTIVE
    -- Tiger Palm (100780) added to rotational — baseline confirmed spell list; primary filler/energy builder
    -- Blackout Kick (100784) added to rotational — baseline confirmed spell list; core filler; combat cast ID 205523 (altId)
    -- Expel Harm (322101) added to rotational — baseline confirmed; 5s CD energy spender, consumes Healing Spheres (Gift of the Ox)
    [1] = {
        name = "Brewmaster", role = "TANK",
        resourceType = 1, resourceLabel = "ENERGY", overcapAt = 100,
        majorCooldowns = {
            { id = 132578,  label = "Invoke Niuzao",     expectedUses = "burst damage"           },  -- nodeID 101075 non-PASSIVE ACTIVE
            { id = 115203,  label = "Fortifying Brew",   expectedUses = "emergency"              },  -- nodeID 101173 non-PASSIVE ACTIVE
            { id = 325153,  label = "Exploding Keg",     expectedUses = "on CD", talentGated = true          },  -- nodeID 101197 non-PASSIVE ACTIVE; confirmed talentGated 1 min CD (May 2026)
            { id = 115399,  label = "Black Ox Brew",     expectedUses = "on CD (2 min)", talentGated = true },  -- Spell ID confirmed in-game; 2 min CD; refills Energy + Purifying Brew charges
            { id = 1241059, label = "Celestial Infusion",expectedUses = "on CD"         },  -- nodeID 101067 non-PASSIVE ACTIVE
            { id = 116705,  label = "Spear Hand Strike", expectedUses = "situational",  isInterrupt = true },  -- nodeID 101152 non-PASSIVE ACTIVE
            { id = 322960,  label = "Fortifying Brew: Determination", expectedUses = "emergency", talentGated = true, healerConditional = true },  -- enhanced Fortifying Brew; major personal defensive CD
            { id = 116847,  label = "Rushing Jade Wind",  expectedUses = "situational",  talentGated = true, isUtility = true, altIds = {148187} },
            { id = 322507,  label = "Celestial Brew",     expectedUses = "on CD (talent)", talentGated = true },  -- 1.5 min CD absorb shield; expected regularly, not held; ADDED 09/06/2026
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 121253, label = "Keg Smash",      minFightSeconds = 15 },  -- nodeID 101088 non-PASSIVE ACTIVE; primary Brew generator
            { id = 119582, label = "Purifying Brew", minFightSeconds = 20 },  -- nodeID 101064 non-PASSIVE ACTIVE; clears Heavy/Severe stagger
            { id = 115181, label = "Breath of Fire", minFightSeconds = 15 },  -- nodeID 101069 non-PASSIVE ACTIVE; AoE damage and debuff
            { id = 100780, label = "Tiger Palm",     minFightSeconds = 15 },  -- baseline confirmed spell list; primary filler
            { id = 100784, label = "Blackout Kick",  minFightSeconds = 15, altIds = {205523} },  -- baseline confirmed spell list; core filler
            { id = 322101, label = "Expel Harm",     minFightSeconds = 15 },  -- baseline; 5s CD, consumes Healing Spheres (Gift of the Ox)
        },
        tankMetrics = { targetMitigationUptime = 60 },
        priorityNotes = {
            "Purifying Brew to clear Heavy or Severe Stagger — don't let it sit",
            "Keg Smash on cooldown — primary Brew charge generator and damage",
            "Breath of Fire on cooldown — AoE damage and debuff",
            "Tiger Palm and Blackout Kick as fillers between cooldowns",
            "Expel Harm on cooldown — consumes Healing Spheres (Gift of the Ox) for self-healing",
            "Invoke Niuzao for heavy sustained damage phases",
            "Black Ox Brew on cooldown when talented — immediately resets Purifying Brew charges for stagger clearing",
            "Exploding Keg and Celestial Infusion on cooldown",
            "Celestial Brew on cooldown when talented — regular absorb shield, not just for emergencies",
            "Fortifying Brew for true emergencies",
        },
        scoreWeights = { cooldownUsage = 30, mitigationUptime = 35, activity = 20, resourceMgmt = 15 },
        sourceNote = "Midnight 12.0 verified against full Brewmaster talent tree snapshot v1.4.3 117 nodes (April 2026); May 2026 Archon sweep",
    },

    -- Mistweaver (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (124 nodes, descriptions) — FLAGGED: 0
    -- Invoke Yu'lon (322118) ADDED 09/06/2026 — confirmed active talent, choice node with
    --   Invoke Chi-Ji at the same node; prior "not in tree" note was wrong or predated the
    --   finalized tree. Mutual suppressIfTalent added both directions.
    -- Invoke Chi-Ji (325197) added to majorCooldowns — nodeID 101129 non-PASSIVE ACTIVE
    -- Life Cocoon (116849) added to majorCooldowns — nodeID 101096 non-PASSIVE ACTIVE
    -- Celestial Conduit (443028) added to majorCooldowns — nodeID 110067 non-PASSIVE ACTIVE
    -- Sheilun's Gift (399491) added to majorCooldowns — nodeID 101120 non-PASSIVE ACTIVE
    -- Spear Hand Strike (116705) added as isInterrupt — baseline confirmed Mistweaver spell list
    -- Renewing Mist corrected 119611 → 115151 — 119611 is wrong ID; 115151 confirmed Mistweaver spell list
    -- Enveloping Mist (124682) added to rotational — nodeID 101134 non-PASSIVE ACTIVE
    -- Mana Tea (115294) added to majorCooldowns — confirmed spell ID; mana recovery CD
    -- Soothing Mist (115175) added to rotational — nodeID 101143; 10.2s channel; auto-channels from Enveloping Mist/Vivify targets; manual casts also tracked
    [2] = {
        name = "Mistweaver", role = "HEALER",
        resourceType = 0,
        majorCooldowns = {
            { id = 115310, label = "Revival",           expectedUses = "raid emergency",   healerConditional = true        },  -- nodeID 101131 non-PASSIVE ACTIVE
            { id = 116680, label = "Thunder Focus Tea", expectedUses = "on CD"                                             },  -- nodeID 101133 non-PASSIVE ACTIVE
            { id = 115294, label = "Mana Tea",          expectedUses = "mana recovery",  altIds = {115869}              },  -- confirmed spell ID; use on cooldown to sustain mana
            { id = 325197, label = "Invoke Chi-Ji",     expectedUses = "sustained AoE",    healerConditional = true, talentGated = true, suppressIfTalent = 322118 },  -- nodeID 101129 non-PASSIVE ACTIVE; choice node with Invoke Yu'lon
            { id = 322118, label = "Invoke Yu'lon, the Jade Serpent", expectedUses = "sustained AoE", healerConditional = true, talentGated = true, suppressIfTalent = 325197 },  -- choice node with Invoke Chi-Ji; ADDED 09/06/2026
            { id = 116849, label = "Life Cocoon",       expectedUses = "tank emergencies",  healerConditional = true        },  -- nodeID 101096 non-PASSIVE ACTIVE
            { id = 399491, label = "Sheilun's Gift",    expectedUses = "on CD"                                             },  -- nodeID 101120 non-PASSIVE ACTIVE; draws in mist clouds for burst heal
            { id = 443028, label = "Celestial Conduit", expectedUses = "on CD (talent)",   talentGated = true              },  -- nodeID 110067 non-PASSIVE ACTIVE
            { id = 388615, label = "Restoral",          expectedUses = "emergency AoE",    talentGated = true, healerConditional = true },  -- channel heal + dispels all magic debuffs from group; major emergency CD
            { id = 116705, label = "Spear Hand Strike", expectedUses = "situational",       isInterrupt = true              },
        },
        rotationalSpells = {
            { id = 115151, label = "Renewing Mist",   minFightSeconds = 15 },  -- baseline confirmed Mistweaver spell list (was 119611 — wrong ID)
            { id = 107428, label = "Rising Sun Kick",  minFightSeconds = 15 },  -- nodeID 101186 non-PASSIVE ACTIVE
            { id = 124682, label = "Enveloping Mist",  minFightSeconds = 20 },  -- nodeID 101134 non-PASSIVE ACTIVE; primary ST heal
            { id = 115175, label = "Soothing Mist",   minFightSeconds = 20 },  -- nodeID 101143; 10.2s channel; auto-channels from Enveloping Mist/Vivify — manual casts also fire SPELLCAST_SUCCEEDED
        },
        healerMetrics = { targetOverheal = 25, targetActivity = 85, targetManaEnd = 10 },
        priorityNotes = {
            "Keep Renewing Mist rolling on as many injured targets as possible",
            "Rising Sun Kick on cooldown — damage amp and healing bonus",
            "Enveloping Mist for sustained single-target healing",
            "Thunder Focus Tea on cooldown — empowers next major heal",
            "Mana Tea on cooldown — mana recovery, do not let charges sit",
            "Sheilun's Gift on cooldown — draws in mist clouds for burst healing",
            "Life Cocoon on the tank for heavy damage",
            "Invoke Chi-Ji or Invoke Yu'lon (whichever is talented) for sustained AoE healing phases",
            "Revival for emergency full-group healing — do not hold it",
        },
        scoreWeights = { cooldownUsage = 25, efficiency = 30, activity = 25, responsiveness = 20 },
        sourceNote = "Midnight 12.0 verified against full Mistweaver talent tree snapshot v1.4.3 124 nodes (April 2026)",
    },

    -- Windwalker (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (129 nodes, descriptions) — FLAGGED: 0
    -- Storm, Earth and Fire (137639) removed — not in Windwalker talent tree or spell list
    -- Serenity (152173) removed — not in Windwalker talent tree or spell list
    -- Zenith (1249625) added to majorCooldowns — nodeID 101053 non-PASSIVE ACTIVE
    -- Slicing Winds (1217413) added as talentGated CD — nodeID 102250 INACTIVE this build
    -- Spear Hand Strike (116705) added as isInterrupt — nodeID 110098 non-PASSIVE ACTIVE
    -- Combo Breaker: BoK (116768) removed from procBuffs — not in talent tree or spell list
    -- Tiger Palm (100780) added to rotational — baseline confirmed WW spell list
    -- Blackout Kick (100784) added to rotational — baseline confirmed WW spell list
    -- Whirling Dragon Punch (152175) added to rotational — nodeID 101207 non-PASSIVE ACTIVE
    -- Touch of Death (322109) added to majorCooldowns — confirmed spell ID; 3 min CD; 99.6% adoption
    -- Improved Touch of Death (322113) confirmed PASSIVE nodeID 101140 — expands health threshold to 15%
    [3] = {
        name = "Windwalker", role = "DPS",
        resourceType = 12, resourceLabel = "CHI", overcapAt = 6,
        majorCooldowns = {
            { id = 123904,  label = "Invoke Xuen",       expectedUses = "burst windows"           },  -- nodeID 101243 non-PASSIVE ACTIVE
            { id = 1249625, label = "Zenith",            expectedUses = "on CD"                   },  -- nodeID 101053 non-PASSIVE ACTIVE
            { id = 322109,  label = "Touch of Death",    expectedUses = "on CD"                   },  -- confirmed spell ID; 3 min CD; usable below 15% HP (Improved Touch of Death PASSIVE)
            { id = 1217413, label = "Slicing Winds",     expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 102250 INACTIVE this build
            { id = 116705,  label = "Spear Hand Strike", expectedUses = "situational",    isInterrupt = true },  -- nodeID 110098 non-PASSIVE ACTIVE
        },
        rotationalSpells = {
            { id = 113656, label = "Fists of Fury",        minFightSeconds = 15 },  -- nodeID 101218 non-PASSIVE ACTIVE
            { id = 107428, label = "Rising Sun Kick",       minFightSeconds = 15 },  -- nodeID 101186 non-PASSIVE ACTIVE
            { id = 152175, label = "Whirling Dragon Punch", minFightSeconds = 15, talentGated = true },  -- nodeID 101207 non-PASSIVE ACTIVE
            { id = 100780, label = "Tiger Palm",            minFightSeconds = 15 },  -- baseline confirmed WW spell list
            { id = 100784, label = "Blackout Kick",         minFightSeconds = 15, altIds = {205523} },  -- baseline confirmed WW spell list
            { id = 392983, label = "Strike of the Windlord", minFightSeconds = 20, talentGated = true, hasCombatValue = true, isUtility = true },  -- major AoE damage + knock up; situational — bonus credit, never penalised
        },
        priorityNotes = {
            "Fists of Fury on cooldown — highest damage ability",
            "Rising Sun Kick on cooldown — damage and Mortal Wounds debuff",
            "Whirling Dragon Punch on cooldown when talented",
            "Tiger Palm and Blackout Kick as fillers — generate Chi and procs",
            "Zenith on cooldown — major burst window",
            "Invoke Xuen for additional burst — align with Zenith",
            "Touch of Death on cooldown — usable below 15% HP; 3 min CD",
            "Slicing Winds on cooldown when talented",
            "Never overcap Chi at 6",
        },
        scoreWeights = { cooldownUsage = 35, procUsage = 15, activity = 35, resourceMgmt = 15 },
        sourceNote = "Midnight 12.0 verified against full Windwalker talent tree snapshot v1.4.3 129 nodes (April 2026)",
    },
})
