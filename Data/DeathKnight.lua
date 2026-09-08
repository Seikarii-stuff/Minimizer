local Core = MidnightSensei.Core

Core.RegisterSpec(6, {
    className = "Death Knight",

    -- Blood (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (108 nodes, descriptions) — FLAGGED: 0
    -- Abomination Limb (383269) removed — not in Blood talent tree or spell list
    -- Bonestorm (194844) removed — not in Blood talent tree or spell list
    -- Reaper's Mark (439843) added to majorCooldowns — nodeID 95062 non-PASSIVE ACTIVE
    -- Mind Freeze (47528) added as isInterrupt — nodeID 76084 non-PASSIVE ACTIVE
    -- Blood Shield (77535) removed from uptimeBuffs — proc absorb, not a persistent aura
    -- Consumption (1263824) added as talentGated CD — nodeID 102244 non-PASSIVE INACTIVE this build
    -- rotationalSpells added: Marrowrend, Heart Strike, Blood Boil, Death Strike — all missing entirely
    -- Icebound Fortitude (48792) added to majorCooldowns healerConditional — reactive personal defensive
    -- Anti-Magic Shell (48707) added to majorCooldowns healerConditional — reactive magic absorb
    -- Death and Decay (43265) added to rotational talentGated — AoE situational
    [1] = {
        name = "Blood", role = "TANK",
        resourceType = 6, resourceLabel = "RUNIC POWER", overcapAt = 100,
        majorCooldowns = {
            { id = 49028,   label = "Dancing Rune Weapon", expectedUses = "on CD"           },  -- nodeID 76138 non-PASSIVE ACTIVE
            { id = 55233,   label = "Vampiric Blood",      expectedUses = "big damage"      },  -- nodeID 76173 non-PASSIVE ACTIVE
            { id = 439843,  label = "Reaper's Mark",       expectedUses = "on CD", talentGated = true },  -- nodeID 95062; class talent
            { id = 1263824, label = "Consumption",         expectedUses = "on CD (talent)", talentGated = true     },  -- nodeID 102244; damage + mitigation
            { id = 48792,   label = "Icebound Fortitude",  expectedUses = "big damage",     healerConditional = true },  -- reactive personal defensive
            { id = 48707,   label = "Anti-Magic Shell",    expectedUses = "magic damage",   healerConditional = true },  -- reactive magic absorb
            { id = 47528,   label = "Mind Freeze",         expectedUses = "situational",    isInterrupt = true       },  -- nodeID 76084 non-PASSIVE ACTIVE
            { id = 109199,  label = "Gauntlet's Grasp",    expectedUses = "situational",    talentGated = true       },  -- Rider hero talent; ~99.8% adoption; confirmed id=109199 (May 2026)
            { id = 1263569, label = "Abomination Limb",  expectedUses = "situational", talentGated = true, isUtility = true, hasCombatValue = true, suppressIfTalent = 108199 },  -- Midnight 12.0 ID; choice node with Gorefiend's Grasp; suppress when Gorefiend's Grasp taken
            { id = 108199,  label = "Gorefiend's Grasp", expectedUses = "situational", talentGated = true, isUtility = true, suppressIfTalent = 1263569 },  -- group grip utility; choice node with Abomination Limb; suppress when Abomination Limb taken
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 195182, label = "Marrowrend",  minFightSeconds = 15 },  -- nodeID 76168 non-PASSIVE ACTIVE; Bone Shield builder
            { id = 206930, label = "Heart Strike", minFightSeconds = 15 },  -- nodeID 76169 non-PASSIVE ACTIVE; primary RP generator
            { id = 50842,  label = "Blood Boil",  minFightSeconds = 15 },  -- nodeID 76170 non-PASSIVE ACTIVE; DoT and AoE threat
            { id = 49998,  label = "Death Strike",    minFightSeconds = 15 },                      -- nodeID 76071 non-PASSIVE ACTIVE; primary self-heal
            { id = 43265,  label = "Death and Decay", minFightSeconds = 20, talentGated = true },  -- AoE situational
        },
        tankMetrics = { targetMitigationUptime = 50 },
        priorityNotes = {
            "Death Strike on incoming damage — primary self-heal, generates Blood Shield",
            "Marrowrend to maintain Bone Shield stacks — core mitigation",
            "Heart Strike on cooldown — primary Runic Power generator",
            "Blood Boil on cooldown — DoT and AoE threat",
            "Dancing Rune Weapon on cooldown — parry and Rune regeneration",
            "Vampiric Blood for sustained dangerous phases",
            "Reaper's Mark on cooldown",
            "Consumption on cooldown when talented — damage and instant Blood Plague burst",
            "Icebound Fortitude for big physical damage windows",
            "Anti-Magic Shell for magic-heavy damage windows",
            "Death and Decay for AoE threat and damage when talented",
        },
        scoreWeights = { cooldownUsage = 30, mitigationUptime = 35, activity = 20, resourceMgmt = 15 },
        sourceNote = "Midnight 12.0 verified against full Blood talent tree snapshot v1.4.3 108 nodes (April 2026)",
    },

    -- Frost (Midnight 12.0 PASSIVE audit — April 2026)
    -- Breath of Sindragosa (1249658) added to majorCooldowns — nodeID 76093 non-PASSIVE ACTIVE
    -- Reaper's Mark (439843) added to majorCooldowns — nodeID 95062 non-PASSIVE ACTIVE
    -- Mind Freeze (47528) added as isInterrupt — nodeID 76084 non-PASSIVE ACTIVE
    -- Howling Blast (49184) added to rotational — nodeID 76114 non-PASSIVE ACTIVE; primary AoE + Rime proc consumer
    -- Frostscythe (207230) added to rotational — nodeID 76113 non-PASSIVE ACTIVE; AoE alternative to Obliterate
    -- Killing Machine procBuff: 59052 primary; altId 51128 added (talent tree nodeID 76117) — VERIFY closed May 2026
    -- Rime procBuff: 51124 primary; altId 59057 added (spell list variant) — VERIFY closed May 2026
    -- Remorseless Winter (196771) added to rotational — combat cast ID 196771 (spellbook 196770); session log x39; baseline not talent-gated
    -- Frostbane (1228433) added to rotational talentGated — altIds={1228436}; both IDs seen in session log (x2 each)
    -- Glacial Advance (194913) added to rotational talentGated — AoE; session log x2
    [2] = {
        name = "Frost", role = "DPS",
        resourceType = 6, resourceLabel = "RUNIC POWER", overcapAt = 100,
        majorCooldowns = {
            { id = 51271,  label = "Pillar of Frost",       expectedUses = "on CD"          },  -- nodeID 101929 non-PASSIVE ACTIVE
            { id = 47568,  label = "Empower Rune Weapon",   expectedUses = "on CD"          },  -- nodeID 76096 non-PASSIVE ACTIVE
            { id = 279302, label = "Frostwyrm's Fury",      expectedUses = "burst windows"  },  -- nodeID 76106 non-PASSIVE ACTIVE
            { id = 1249658,label = "Breath of Sindragosa",  expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 76093 non-PASSIVE ACTIVE
            { id = 439843, label = "Reaper's Mark",         expectedUses = "on CD", talentGated = true },  -- nodeID 95062; class talent
            { id = 47528,  label = "Mind Freeze",           expectedUses = "situational",    isInterrupt = true },  -- nodeID 76084 non-PASSIVE ACTIVE
        },
        rotationalSpells = {
            { id = 49020,  label = "Obliterate",   minFightSeconds = 15 },  -- nodeID 76116 non-PASSIVE ACTIVE; primary damage
            { id = 49143,  label = "Frost Strike",  minFightSeconds = 20 },  -- nodeID 76115 non-PASSIVE ACTIVE; Runic Power dump
            { id = 49184,  label = "Howling Blast", minFightSeconds = 15 },  -- nodeID 76114 non-PASSIVE ACTIVE; AoE + Rime proc consumer
            { id = 207230, label = "Frostscythe",       minFightSeconds = 20, talentGated = true },  -- nodeID 76113 non-PASSIVE ACTIVE; AoE alt
            { id = 196771, label = "Remorseless Winter", minFightSeconds = 20 },                       -- combat cast ID; spellbook 196770; baseline; session log x39
            { id = 1228433, label = "Frostbane",         minFightSeconds = 20, talentGated = true, altIds = {1228436} },  -- both IDs seen in session log x2
            { id = 194913, label = "Glacial Advance",    minFightSeconds = 20, talentGated = true },  -- AoE; session log x2
        },
        procBuffs = {
            { id = 59052, label = "Killing Machine",      maxStackTime = 10, altIds = {51128} },  -- altId 51128 (talent tree nodeID 76117); VERIFY closed May 2026
            { id = 51124, label = "Rime (Howling Blast)", maxStackTime = 15, altIds = {59057} },  -- altId 59057 (spell list variant); VERIFY closed May 2026
        },
        priorityNotes = {
            "Spend Killing Machine procs with Obliterate immediately",
            "Spend Rime procs with Howling Blast — do not sit on them",
            "Obliterate on cooldown — primary damage and proc driver",
            "Frost Strike to dump Runic Power — avoid overcapping at 100",
            "Pillar of Frost for burst — align with Empower Rune Weapon and trinkets",
            "Breath of Sindragosa: do not break early — maximise channel duration",
        },
        scoreWeights = { cooldownUsage = 25, procUsage = 30, activity = 25, resourceMgmt = 20 },
        sourceNote = "Midnight 12.0 verified against full Frost DK talent tree snapshot v1.4.3 107 nodes (April 2026)",
    },

    -- Unholy (Midnight 12.0 PASSIVE audit — April 2026)
    -- Apocalypse (275699) removed — not in Unholy talent tree or spell list
    -- Unholy Assault (207289) removed — not in Unholy talent tree or spell list
    -- Dark Transformation: corrected 63560 → 1233448 — nodeID 76185 non-PASSIVE ACTIVE; confirmed spell list
    --   Note: 63560 may be an old ID or unused variant — 1233448 is what the spellbook reports
    -- Mind Freeze (47528) added as isInterrupt — nodeID 76084 non-PASSIVE ACTIVE
    -- Outbreak (77575) added to majorCooldowns — nodeID 76189 non-PASSIVE ACTIVE; critical DoT applicator
    -- Soul Reaper (343294) added to majorCooldowns — nodeID 76179 non-PASSIVE ACTIVE; execute CD
    -- Festering Strike: corrected 85092 → 316239 → 85948 — 85948 is what fires in UNIT_SPELLCAST_SUCCEEDED; 316239 kept as altId (talent-modified variant)
    -- Putrefy (1247378) added to rotational — nodeID 108129 non-PASSIVE ACTIVE; confirmed spell list
    -- Festering Scythe (458128) added to rotational talentGated — Rider of the Apocalypse hero spec; rotational not a CD
    -- Death Strike (49998) added to rotational talentGated — survival/self-heal Runic Power spender; session log x3
    -- Death and Decay (43265) added to rotational talentGated — AoE situational; session log x2
    -- Epidemic (207317) added to rotational — baseline AoE Runic Power spender; not talent-gated
    -- Necrotic Coil (1242174) added to rotational talentGated — Forbidden Knowledge talent (nodeID 110354); replaces Death Coil during 30s AotD window
    [3] = {
        name = "Unholy", role = "DPS",
        resourceType = 6, resourceLabel = "RUNIC POWER", overcapAt = 100,
        majorCooldowns = {
            { id = 42650,   label = "Army of the Dead",    expectedUses = "pre-pull / burst" },  -- nodeID 76196 non-PASSIVE ACTIVE
            { id = 1233448, label = "Dark Transformation", expectedUses = "on CD"            },  -- nodeID 76185 non-PASSIVE ACTIVE (was 63560 — wrong ID)
            { id = 77575,   label = "Outbreak",            expectedUses = "DoT application"  },  -- nodeID 76189 non-PASSIVE ACTIVE
            { id = 343294,  label = "Soul Reaper",         expectedUses = "execute phase",  talentGated = true },  -- nodeID 76179 non-PASSIVE ACTIVE
            { id = 47528,   label = "Mind Freeze",         expectedUses = "situational",    isInterrupt = true },  -- nodeID 76084 non-PASSIVE ACTIVE
            -- Apocalypse (275699) removed — not in Unholy talent tree or spell list
            -- Unholy Assault (207289) removed — not in Unholy talent tree or spell list
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 85948,   label = "Festering Strike", minFightSeconds = 15, altIds = {316239} },  -- 85948 confirmed via verify; 316239 was previously tracked but never fires (talent-modified variant kept as altId)
            { id = 55090,   label = "Scourge Strike",   minFightSeconds = 15 },  -- nodeID 76190 non-PASSIVE ACTIVE; wound popper
            { id = 47541,   label = "Death Coil",       minFightSeconds = 20 },  -- confirmed spell list; Runic Power dump
            { id = 1247378, label = "Putrefy",          minFightSeconds = 20, talentGated = true },  -- nodeID 108129 non-PASSIVE ACTIVE
            { id = 49998,   label = "Death Strike",     minFightSeconds = 30, talentGated = true },  -- survival/self-heal RP spender; session log x3
            { id = 43265,   label = "Death and Decay",  minFightSeconds = 30, talentGated = true },  -- AoE situational; session log x2
            { id = 458128,  label = "Festering Scythe", minFightSeconds = 20, talentGated = true },  -- Rider of the Apocalypse hero spec; rotational not a CD
            { id = 207317,  label = "Epidemic",         minFightSeconds = 20 },                      -- baseline AoE Runic Power spender; not talent-gated
            { id = 1242174, label = "Necrotic Coil",    minFightSeconds = 30, talentGated = true },  -- Forbidden Knowledge (nodeID 110354); replaces Death Coil during 30s AotD window
        },
        priorityNotes = {
            "Apply Festering Wounds with Festering Strike before Scourge Strike",
            "Pop Festering Wounds with Scourge Strike — aim for batches of 4-8",
            "Outbreak to reapply Virulent Plague when it drops",
            "Dark Transformation on cooldown — empowers ghoul for burst",
            "Death Coil (single-target) or Epidemic (AoE) to dump Runic Power — avoid overcapping at 100",
            "Necrotic Coil replaces Death Coil during Army of the Dead window (Forbidden Knowledge talent)",
            "Festering Scythe on cooldown when Rider of the Apocalypse is talented",
            "Soul Reaper at execute range when talented",
            "Army of the Dead on pull or major burst window",
        },
        scoreWeights = { cooldownUsage = 25, activity = 35, resourceMgmt = 25, procUsage = 15 },
        sourceNote = "Midnight 12.0 verified against full Unholy DK talent tree snapshot v1.4.3 106 nodes (April 2026)",
    },
})
