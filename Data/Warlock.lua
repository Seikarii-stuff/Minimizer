local Core = MidnightSensei.Core

Core.RegisterSpec(9, {
    className = "Warlock",

    -- Affliction (PASSIVE audit complete — April 2026)
    -- Verified against full Affliction talent tree snapshot 103 nodes
    -- Wither (445468): nodeID 94840 confirmed non-PASSIVE ACTIVE ✅
    -- Drain Soul 388667: nodeID 72045 confirmed PASSIVE — removed from rotational
    --   686 (baseline) remains as the trackable cast ID
    -- All other entries confirmed non-PASSIVE from talent snapshot
    -- Curse of Tongues + Curse of Exhaustion: both 86%+ adoption on Archon (May 2026 audit)
    --   situational debuffs — tracked as isUtility, never penalised; bonus credit if used
    --   spell IDs confirmed by Archon (May 2026 audit); monitor for reports of wrong tracking
    [1] = {
        name = "Affliction", role = "DPS",
        resourceType = 7, resourceLabel = "SOUL SHARDS", overcapAt = 5,
        majorCooldowns = {
            { id = 205180,  label = "Summon Darkglare",      expectedUses = "on CD"                                    },  -- nodeID 72034 non-PASSIVE ACTIVE
            { id = 442726,  label = "Malevolence",           expectedUses = "on CD",          talentGated = true        },  -- nodeID 94842; shared class talent — talentGated to avoid tracking grayed cross-spec spell
            { id = 1257052, label = "Dark Harvest",          expectedUses = "on CD (talent)", talentGated = true        },  -- nodeID 109860 non-PASSIVE ACTIVE
            { id = 445468,  label = "Wither",                expectedUses = "on CD (talent)", talentGated = true        },  -- nodeID 94840 non-PASSIVE ACTIVE confirmed
            { id = 1714,    label = "Curse of Tongues",      expectedUses = "situational",    isUtility = true          },  -- confirmed id=1714 by Archon (May 2026); 87% adoption; debuff slows cast speed; never penalised
            { id = 334275,  label = "Curse of Exhaustion",   expectedUses = "situational",    isUtility = true          },  -- confirmed id=334275 by Archon (May 2026); 87% adoption; debuff slows movement; never penalised
        },
        rotationalSpells = {
            { id = 980,     label = "Agony",               minFightSeconds = 15, hasCombatValue = true, isUtility = true },  -- DoT; bonus credit, never penalised — other talents auto-apply or replace it
            { id = 48181,   label = "Haunt",               minFightSeconds = 20 },  -- nodeID 72032 non-PASSIVE ACTIVE
            { id = 1259790, label = "Unstable Affliction",  minFightSeconds = 15 },  -- nodeID 109862 non-PASSIVE ACTIVE
            { id = 686,     label = "Drain Soul",           minFightSeconds = 15, altIds = {388667} },  -- baseline spell list; 388667 = Archon alt ID (nodeID 72045)
            { id = 27243,   label = "Seed of Corruption",   minFightSeconds = 30 },  -- nodeID 72050 non-PASSIVE ACTIVE
        },
        uptimeBuffs = {},
        procBuffs = {
            { id = 108558, label = "Nightfall", maxStackTime = 12 },  -- nodeID 72047 PASSIVE ACTIVE — proc aura, VERIFY C_UnitAuras
        },
        priorityNotes = {
            "Maintain Agony, Corruption, and Unstable Affliction on all targets (not directly tracked)",
            "Haunt on cooldown for the damage amp window",
            "Drain Soul as primary filler — generates Soul Shards on kill",
            "Pool Soul Shards before burst windows — avoid overcapping",
            "Align Malevolence and Dark Harvest with Darkglare for stacked burst",
            "Malefic Rapture to spend Soul Shards during Darkglare windows",
            "Seed of Corruption for AoE — spreads Corruption to all nearby targets",
            "Spend Nightfall procs immediately on Shadow Bolt",
        },
        scoreWeights = { cooldownUsage = 35, procUsage = 15, activity = 30, resourceMgmt = 20 },
        sourceNote = "Midnight 12.0 verified against full Affliction talent tree snapshot 103 nodes (April 2026); May 2026 second-pass",
    },

    -- Demonology (Full talent tree pass — April 2026)
    -- Verified against full talent tree snapshot (104 nodes, ACTIVE + INACTIVE)
    -- Hand of Gul'dan: talent version is 105174 (nodeID 101891) — tracking both
    --   172 (baseline) and 105174 (talent empowered) for full coverage
    -- Summon Vilefiend: correct Midnight 12.0 ID confirmed as 1251778 (nodeID 109252)
    --   was previously 264119 (wrong) then removed — now restored with correct ID
    -- Reign of Tyranny: INACTIVE in this build — added as talentGated CD (nodeID 110201)
    -- Dark Harvest 1257052: removed — Affliction only, not a Demonology ability (May 2026)
    -- Demonbolt 264178: not in talent tree — baseline spell, no change
    [2] = {
        name = "Demonology", role = "DPS",
        resourceType = 7, resourceLabel = "SOUL SHARDS", overcapAt = 5,
        majorCooldowns = {
            { id = 265187,  label = "Summon Demonic Tyrant",  expectedUses = "on CD"                                              },  -- nodeID 101905 — not PASSIVE
            { id = 104316,  label = "Call Dreadstalkers",     expectedUses = "on CD"                                              },  -- nodeID 101894 — not PASSIVE
            { id = 1276672, label = "Summon Doomguard",       expectedUses = "situational", talentGated = true, isUtility = true  },  -- nodeID 101917; situational — community consensus not always pressed every pull
            { id = 1276467, label = "Grimoire: Fel Ravager",  expectedUses = "situational", talentGated = true, isUtility = true  },  -- nodeID 110197; choice node with Imp Lord; purges 1 beneficial magic effect
            { id = 1276452, label = "Grimoire: Imp Lord",     expectedUses = "situational", talentGated = true, isUtility = true  },  -- nodeID 110197; choice node with Fel Ravager; spell ID 1276452
            -- Removed (confirmed PASSIVE via talent snapshot):
            -- Diabolic Ritual 428514 — PASSIVE (nodeID 94855)
            -- Summon Vilefiend 1251778 — PASSIVE (nodeID 109252)
            -- Reign of Tyranny 1276748 — PASSIVE (nodeID 110201)
            -- Removed (Affliction only):
            -- Malevolence 442726 — Affliction only; not a Demonology ability
        },
        rotationalSpells = {
            { id = 196277,  label = "Implosion",       minFightSeconds = 15 },                          -- nodeID 101893
            { id = 105174,  label = "Hand of Gul'dan", minFightSeconds = 15, talentGated = true },      -- nodeID 101891; confirmed cast ID in Demonology
            { id = 264130,  label = "Power Siphon",    minFightSeconds = 20, talentGated = true },      -- destroys 2 Wild Imps to generate Demonic Core stacks; use before Demonbolt
            { id = 264178,  label = "Demonbolt",       minFightSeconds = 20 },                          -- baseline; Demonic Core spender
            -- Doom (460551) removed — appears as damage tick in logs but not directly cast via UNIT_SPELLCAST_SUCCEEDED
            -- Applied automatically; cannot be tracked via cast detection. Re-add if confirmed castable via /ms verify.
            -- Dark Harvest 1257052 removed — Affliction only; not a Demonology ability
        },
        procBuffs = {
            { id = 267102, label = "Demonic Core", maxStackTime = 20 },  -- confirmed spell list
        },
        priorityNotes = {
            "Stack demons before Demonic Tyrant — Tyrant extends all active pet durations",
            "Use Implosion at 6+ Wild Imps for maximum damage",
            "Call Dreadstalkers on cooldown — core damage and imp generation",
            "Hand of Gul'dan to summon imps and enable Implosion windows — primary shard spender",
            "Spend Demonic Core procs on Demonbolt — don't sit on stacks",
            "Summon Doomguard is situational when talented — use on important pulls",
            "Avoid Soul Shard overcap — spend with Hand of Gul'dan",
        },
        scoreWeights = { cooldownUsage = 35, procUsage = 25, activity = 25, resourceMgmt = 15 },
        sourceNote = "Midnight 12.0 verified against full talent tree passive audit (April 2026)",
    },

    -- Destruction (Full talent tree pass — April 2026)
    -- Verified against full talent tree (103 nodes) and spell snapshot
    -- v1.4.3 snapshot: Wither (445468) confirmed non-PASSIVE ACTIVE — added to majorCooldowns
    --   (was in Affliction spec DB but missing from Destruction — shared cross-spec node)
    --   Wither [Replaces] Corruption tooltip — Corruption not tracked in Destruction, no suppressIfTalent needed
    -- Malevolence: corrected 458355 → 442726 (nodeID 94842 ACTIVE)
    -- Havoc (80240) removed — not in Destruction talent tree or spell list in Midnight 12.0
    -- Immolate (348) removed from rotational — not in Destruction spell list or talent tree
    -- Incinerate: spell list shows 686 as "Incinerate" for Destruction (spec-variant baseline)
    -- Diabolic Ritual (428514) removed — confirmed PASSIVE (nodeID 94855)
    -- Devastation (454735) removed — confirmed PASSIVE (nodeID 110281)
    -- Conflagrate (17962) added to rotational — nodeID 72068 ACTIVE; core builder
    -- Shadowburn (17877) added to rotational — nodeID 72060 ACTIVE; execute finisher
    -- Rain of Fire (5740) added as talentGated rotational — nodeID 72069 ACTIVE
    [3] = {
        name = "Destruction", role = "DPS",
        resourceType = 7, resourceLabel = "SOUL SHARDS", overcapAt = 5,
        majorCooldowns = {
            { id = 1122,   label = "Summon Infernal",  expectedUses = "on CD"           },  -- nodeID 71985 — not PASSIVE
            { id = 442726, label = "Malevolence",      expectedUses = "on CD",          talentGated = true },  -- nodeID 94842; shared class talent — talentGated to avoid tracking grayed cross-spec spell
            { id = 152108, label = "Cataclysm",        expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 71974 — not PASSIVE
            { id = 445468, label = "Wither",           expectedUses = "on CD (talent)", talentGated = true },  -- non-PASSIVE ACTIVE; confirmed v1.4.3 snapshot — shared node with Affliction
            -- Diabolic Ritual 428514 — PASSIVE (nodeID 94855)
            -- Devastation 454735 — PASSIVE (nodeID 110281)
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 686,    label = "Incinerate",   minFightSeconds = 15, altIds = {29722} },      -- spell list confirmed; altId 29722 per Archon (May 2026)
            { id = 116858, label = "Chaos Bolt",   minFightSeconds = 20 },                      -- nodeID 110282 ACTIVE; primary spender
            { id = 17962,  label = "Conflagrate",  minFightSeconds = 15 },                      -- nodeID 72068 ACTIVE; core builder
            { id = 6353,   label = "Soul Fire",    minFightSeconds = 20, talentGated = true },  -- high-damage cast; generates Burning Ember; use on cooldown when talented
            { id = 17877,  label = "Shadowburn",   minFightSeconds = 20, talentGated = true },  -- nodeID 72060 ACTIVE; execute finisher
            { id = 5740,   label = "Rain of Fire", minFightSeconds = 30, talentGated = true, altIds = {1214467} },  -- nodeID 72069 ACTIVE; AoE
        },
        priorityNotes = {
            "Maintain Immolate on all targets for shard generation (not directly tracked)",
            "Conflagrate on cooldown — generates Backdraft charges for Incinerate",
            "Do not waste Backdraft — cast Incinerate or Chaos Bolt while active",
            "Chaos Bolt is the primary shard spender — align with Summon Infernal and Malevolence",
            "Cataclysm on cooldown for AoE shard generation and Immolate spread when talented",
            "Shadowburn on low-health targets when talented — execute replacement",
            "Avoid Soul Shard overcap — spend with Chaos Bolt",
        },
        scoreWeights = { cooldownUsage = 35, activity = 40, resourceMgmt = 25 },
        sourceNote = "Midnight 12.0 verified against full Destruction talent tree snapshot 103 nodes (April 2026)",
    },
})
