local Core = MidnightSensei.Core

Core.RegisterSpec(3, {
    className = "Hunter",

    -- Beast Mastery (Midnight 12.0 PASSIVE audit — April 2026)
    -- Call of the Wild (359844) removed — not in BM talent tree or spell list
    -- Thrill of the Hunt: confirmed PASSIVE 09/06/2026 via in-game tooltip (Rank 0/2, Barbed/Cobra
    --   Shot crit chance). Correct current ID is 1265051, not the old 246152 recorded here — not tracked either way.
    -- Counter Shot (147362) added as isInterrupt — nodeID 102292 non-PASSIVE ACTIVE
    -- Cobra Shot (193455) added to rotational — nodeID 102354 non-PASSIVE ACTIVE; primary filler/Focus dump
    -- Black Arrow (466930) added to rotational — nodeID 109961 non-PASSIVE ACTIVE; new Midnight ability
    -- Wild Thrash (1264359) added to rotational — nodeID 102363 non-PASSIVE ACTIVE
    -- Multi-Shot: not available in Beast Mastery spec in Midnight 12.0 — not tracked
    -- Pack Leader / Dark Ranger hero talent active abilities — confirmed none to add
    [1] = {
        name = "Beast Mastery", role = "DPS",
        resourceType = 3, resourceLabel = "FOCUS", overcapAt = 100,
        majorCooldowns = {
            { id = 19574,  label = "Bestial Wrath",  expectedUses = "on CD"   },  -- nodeID 102340 non-PASSIVE ACTIVE
            { id = 147362, label = "Counter Shot",   expectedUses = "situational", isInterrupt = true },  -- nodeID 102292 non-PASSIVE ACTIVE
            -- Call of the Wild (359844) removed — not in BM talent tree or spell list
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 34026,   label = "Kill Command",  minFightSeconds = 15 },  -- nodeID 102346 non-PASSIVE ACTIVE
            { id = 217200,  label = "Barbed Shot",   minFightSeconds = 15 },  -- nodeID 102377 non-PASSIVE ACTIVE
            { id = 193455,  label = "Cobra Shot",    minFightSeconds = 15 },  -- nodeID 102354 non-PASSIVE ACTIVE; Focus dump/filler
            { id = 466930,  label = "Black Arrow",   minFightSeconds = 20, talentGated = true },  -- nodeID 109961 non-PASSIVE ACTIVE
            { id = 1264359, label = "Wild Thrash",   minFightSeconds = 20, talentGated = true },  -- nodeID 102363 non-PASSIVE ACTIVE
        },
        priorityNotes = {
            "Keep Barbed Shot rolling to maintain Frenzy stacks on your pet",
            "Kill Command on cooldown — primary Focus spender and damage",
            "Bestial Wrath on cooldown — aligns with pet Frenzy stacks",
            "Cobra Shot to dump Focus — never overcap at 100",
            "Black Arrow and Wild Thrash on cooldown when talented",
        },
        scoreWeights = { cooldownUsage = 30, activity = 35, resourceMgmt = 25, procUsage = 10 },
        sourceNote = "Midnight 12.0 verified against full BM Hunter talent tree snapshot v1.4.3 104 nodes (April 2026)",
    },

    -- Marksmanship (Midnight 12.0 PASSIVE audit — April 2026)
    -- Precise Shots: confirmed PASSIVE 09/06/2026 via in-game tooltip (Rank 1/1, empowers next
    --   Arcane Shot/Multi-Shot). Correct current ID is 260240, not the old 342776 recorded here — not tracked either way.
    -- Counter Shot (147362) added as isInterrupt — nodeID 102402 non-PASSIVE ACTIVE
    -- Arcane Shot (185358) added to rotational — baseline confirmed spell list; primary Focus spender
    -- Steady Shot (56641) added to rotational — confirmed spell ID; baseline filler
    -- Multi-Shot (257620) added to rotational — confirmed spell ID; AoE filler / Bulletstorm trigger
    -- Double Tap (473370) confirmed PASSIVE nodeID 109938 — not tracked
    -- Black Arrow (466932) Dark Ranger hero: replaces Kill Shot; suppressIfTalent=466932 on Kill Shot (spell ID, not node ID 94987); added 05/09/2026
    [2] = {
        name = "Marksmanship", role = "DPS",
        resourceType = 3, resourceLabel = "FOCUS", overcapAt = 100,
        majorCooldowns = {
            { id = 288613, label = "Trueshot",        expectedUses = "on CD"             },  -- nodeID 103947 non-PASSIVE ACTIVE
            { id = 257044, label = "Rapid Fire",      expectedUses = "on CD",  altIds = {257045} },  -- nodeID 103961; altId 257045 per Archon (May 2026)
            { id = 260243, label = "Volley",          expectedUses = "AoE on CD"         },  -- nodeID 103956 non-PASSIVE ACTIVE
            { id = 147362, label = "Counter Shot",    expectedUses = "situational",      isInterrupt = true },  -- nodeID 102402 non-PASSIVE ACTIVE
            { id = 212431, label = "Explosive Shot",  expectedUses = "on CD (talent)",   talentGated = true },  -- nodeID 110575 non-PASSIVE; Shrapnel Shot (473520) and Precision Detonation (471369) are PASSIVE modifiers
            -- Precise Shots (260240) — confirmed PASSIVE 09/06/2026; not tracked
        },
        rotationalSpells = {
            { id = 19434,  label = "Aimed Shot",   minFightSeconds = 20 },  -- nodeID 103982 non-PASSIVE ACTIVE
            { id = 185358, label = "Arcane Shot",  minFightSeconds = 15 },  -- baseline confirmed spell list; Focus spender
            { id = 56641,  label = "Steady Shot",  minFightSeconds = 15 },  -- confirmed spell ID; baseline filler
            { id = 257620, label = "Multi-Shot",   minFightSeconds = 20, talentGated = true },  -- confirmed spell ID; AoE filler / Bulletstorm trigger
            { id = 53351,  label = "Kill Shot",    minFightSeconds = 20, talentGated = true, suppressIfTalent = 466932 },  -- execute/opener; Dark Ranger hero replaces with Black Arrow (466932); suppress by spell ID (node ID 94987 is not a valid suppressIfTalent value)
            { id = 466932, label = "Black Arrow",  minFightSeconds = 20, talentGated = true, altIds = {466930} },  -- Dark Ranger hero replaces Kill Shot; nodeID 94987; usable >80% or <20% health; 466930 alt fires in some contexts
        },
        priorityNotes = {
            "Aimed Shot on cooldown — primary Focus spender and damage",
            "Rapid Fire on cooldown — empowered burst cast",
            "Arcane Shot to dump Focus — never overcap at 100",
            "Volley for AoE on cooldown at 3+ targets",
            "Trueshot for burst — align with trinkets and lust",
        },
        scoreWeights = { cooldownUsage = 30, activity = 35, resourceMgmt = 25, procUsage = 10 },
        sourceNote = "Midnight 12.0 verified against full MM Hunter talent tree snapshot v1.5.0 101 nodes (April 2026)",
    },

    -- Survival (Midnight 12.0 PASSIVE audit — April 2026)
    -- Coordinated Assault (360952) removed — not in Survival talent tree or spell list
    -- Kill Command corrected 34026 (BM ID) → 259489 — nodeID 102255 non-PASSIVE ACTIVE; Survival spec-variant
    -- Mongoose Bite (259387) removed — not in Survival talent tree or spell list
    -- Muzzle (187707) added as isInterrupt — nodeID 79837 non-PASSIVE ACTIVE; confirmed spell list
    -- Raptor Strike (186270) added to rotational — nodeID 102262 non-PASSIVE ACTIVE; confirmed spell list
    -- Takedown (1250646) added to rotational — nodeID 109323 non-PASSIVE ACTIVE; confirmed spell list
    -- Boomstick (1261193) added to rotational — nodeID 109324 non-PASSIVE ACTIVE; confirmed spell list
    -- Flamefang Pitch (1251592) kept out — nodeID 102252 non-PASSIVE INACTIVE in this build
    -- Sweeping Spear (99.4% adoption) confirmed PASSIVE — not tracked
    -- Mongoose Fury (100% adoption) confirmed PASSIVE — not tracked
    [3] = {
        name = "Survival", role = "DPS",
        resourceType = 3, resourceLabel = "FOCUS", overcapAt = 100,
        majorCooldowns = {
            { id = 259495, label = "Wildfire Bomb", expectedUses = "on CD"        },  -- nodeID 102264 non-PASSIVE ACTIVE
            { id = 187707, label = "Muzzle",        expectedUses = "situational", isInterrupt = true },  -- nodeID 79837 non-PASSIVE ACTIVE
            -- Coordinated Assault (360952) removed — not in Survival talent tree or spell list
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 259489,  label = "Kill Command",  minFightSeconds = 15, altIds = {259277} },  -- nodeID 102255; altId 259277 per Archon (May 2026)
            { id = 186270,  label = "Raptor Strike", minFightSeconds = 15 },  -- nodeID 102262 non-PASSIVE ACTIVE
            { id = 259495,  label = "Wildfire Bomb", minFightSeconds = 20 },  -- also rotational between CD windows
            { id = 1250646, label = "Takedown",      minFightSeconds = 20, talentGated = true, altIds = {1253859} },  -- nodeID 109323; altId 1253859 per Archon (May 2026)
            { id = 1261193, label = "Boomstick",     minFightSeconds = 20, talentGated = true, altIds = {1261215} },  -- nodeID 109324; altId 1261215 per Archon (May 2026)
        },
        priorityNotes = {
            "Wildfire Bomb on cooldown — highest priority damage ability",
            "Kill Command on cooldown — primary builder",
            "Raptor Strike to spend Focus — never overcap at 100",
            "Takedown and Boomstick on cooldown when talented",
        },
        scoreWeights = { cooldownUsage = 35, activity = 40, resourceMgmt = 25 },
        sourceNote = "Midnight 12.0 verified against full Survival Hunter talent tree snapshot v1.4.3 99 nodes (April 2026)",
    },
})
