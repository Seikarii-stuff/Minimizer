local Core = MidnightSensei.Core

Core.RegisterSpec(13, {
    className = "Evoker",

    -- Devastation (Midnight 12.0 PASSIVE audit — April 2026; May 2026 tooltip pass)
    -- All majorCooldowns confirmed non-PASSIVE or baseline (Fire Breath, Deep Breath not in talent tree — baseline spells)
    -- Pyre (357211) added to rotational — non-PASSIVE ACTIVE nodeID 93334
    -- Quell (351338) added as isInterrupt — non-PASSIVE ACTIVE nodeID 93332
    -- Zephyr (374227) added to majorCooldowns as isUtility — nodeID 93346; 2 min CD; talentGated; 97.8% adoption
    -- Rescue (370665) added to majorCooldowns as isUtility talentGated — 1 min CD; movement + self/ally cleanse; all specs
    -- Cauterizing Flame (374251) added to majorCooldowns as isUtility — regular spell; all specs; id confirmed in-game
    -- Expunge (365585) added to majorCooldowns as isUtility — id confirmed; altId 360823=Naturalize replaces it when talented
    -- Confirmed PASSIVE (May 2026): Lay Waste, Heavy Wingbeats, Clobbering Sweep, Panacea, Bountiful Bloom,
    --   Blast Furnace, Leaping Flames, Ignition Rush — none tracked
    -- VERIFY resource enum: resourceType 17 pending in-game confirmation
    [1] = {
        name = "Devastation", role = "DPS",
        resourceType = 17, resourceLabel = "ESSENCE", overcapAt = 6,  -- VERIFY resource enum
        majorCooldowns = {
            { id = 375087, label = "Dragonrage",     expectedUses = "on CD"         },  -- non-PASSIVE ACTIVE nodeID 93331
            { id = 357208, label = "Fire Breath",    expectedUses = "on CD"         },  -- baseline confirmed spell list
            { id = 359073, label = "Eternity Surge", expectedUses = "on CD"         },  -- non-PASSIVE ACTIVE nodeID 93275
            { id = 357210, label = "Deep Breath",    expectedUses = "burst windows" },  -- baseline confirmed spell list
            { id = 351338, label = "Quell",    expectedUses = "situational",  isInterrupt = true              },  -- non-PASSIVE ACTIVE nodeID 93332
            { id = 374227, label = "Zephyr",          expectedUses = "AoE damage phases", isUtility = true, talentGated = true },  -- nodeID 93346; 2 min CD; reduces AoE damage taken 20%; tracked, never penalised
            { id = 370665, label = "Rescue",          expectedUses = "situational",       isUtility = true, talentGated = true },  -- 1 min CD; movement + self/ally cleanse; tracked, never penalised
            { id = 374251, label = "Cauterizing Flame", expectedUses = "situational",     isUtility = true,                    },  -- confirmed id=374251; tracked, never penalised
            { id = 365585, label = "Expunge",         expectedUses = "situational",       isUtility = true, altIds = {360823} },  -- 365585 confirmed; 360823=Naturalize (replaces Expunge when talented); tracked, never penalised
            { id = 374968, label = "Time Spiral",    expectedUses = "situational",       isUtility = true, talentGated = true },  -- group movement CD reset; added 05/06/2026
        },
        rotationalSpells = {
            { id = 361469, label = "Living Flame",  minFightSeconds = 20, altIds = {1265867} },  -- baseline confirmed spell list; 1265867=Azure Sweep PASSIVE proc fires in place of Living Flame (May 2026)
            { id = 356995, label = "Disintegrate",  minFightSeconds = 20 },  -- baseline confirmed spell list
            { id = 357211, label = "Pyre",          minFightSeconds = 20, talentGated = true },  -- non-PASSIVE ACTIVE nodeID 93334; AoE spender
        },
        priorityNotes = {
            "Fire Breath and Eternity Surge on cooldown — highest priority empowered spells",
            "Dragonrage for burst — maximize empowered cast rate inside window",
            "Disintegrate as primary filler — strong sustained channel",
            "Living Flame as filler when moving — do not cap Essence",
            "Pyre for AoE when talented — replaces Living Flame in cleave",
            "Deep Breath for AoE on stacked targets",
        },
        scoreWeights = { cooldownUsage = 35, activity = 30, resourceMgmt = 25, procUsage = 10 },
        sourceNote = "Midnight 12.0 verified against full Devastation talent tree snapshot v1.4.3 122 nodes (April 2026); May 2026 tooltip pass",
    },

    -- Preservation (Midnight 12.0 PASSIVE audit — April 2026; May 2026 tooltip pass)
    -- Emerald Communion (370960) removed — not in Preservation talent tree or spell list
    -- Tip the Scales: was 374348 (Renewing Blaze in spell list) — corrected to 370553 (nodeID 93350 non-PASSIVE)
    -- Time Dilation (357170) added — non-PASSIVE ACTIVE nodeID 93336
    -- Temporal Anomaly (373861) added to rotational — non-PASSIVE ACTIVE nodeID 93257
    -- Echo (364343) added to rotational — non-PASSIVE ACTIVE nodeID 93339; core mechanic
    -- Temporal Barrier (1291636) added — non-PASSIVE ACTIVE nodeID 93258; absorb + Echo on up to 5 targets (patch 12.0)
    -- Resonating Sphere removed from game (patch 12.0) — was not tracked
    -- Energy Cycles removed from game (patch 12.0) — was not tracked
    -- Verdant Embrace (360995) added to rotational — nodeID 93341; talentGated; 15s CD instant heal; 100% adoption
    -- Zephyr (374227) added to majorCooldowns as isUtility — nodeID 93346; 2 min CD; talentGated; 100% adoption
    -- Stasis (370537) added to majorCooldowns — 1.5 min CD; stores last 3 spell casts and releases simultaneously; major burst CD
    -- Rescue (370665) added to majorCooldowns as isUtility talentGated — 1 min CD; movement + self/ally cleanse; all specs
    -- Cauterizing Flame (374251) added to majorCooldowns as isUtility — regular spell; all specs; id confirmed in-game
    -- Expunge (365585) added to majorCooldowns as isUtility — id confirmed; altId 360823=Naturalize replaces it when talented
    -- Confirmed PASSIVE (May 2026): Call of Ysera, Dream of Simulacrum, Life-Giver's Flame, Lifebind — none tracked
    [2] = {
        name = "Preservation", role = "HEALER",
        resourceType = 17, resourceLabel = "ESSENCE", overcapAt = 6,
        majorCooldowns = {
            { id = 363534,  label = "Rewind",            expectedUses = "emergency",     healerConditional = true },  -- non-PASSIVE ACTIVE nodeID 93337
            { id = 355936,  label = "Dream Breath",      expectedUses = "on CD AoE"                              },  -- non-PASSIVE ACTIVE nodeID 93240
            { id = 370553,  label = "Tip the Scales",    expectedUses = "burst ramp"                             },  -- non-PASSIVE ACTIVE nodeID 93350 (was 374348 — wrong)
            { id = 357170,  label = "Time Dilation",     expectedUses = "emergency HoT",  healerConditional = true              },  -- non-PASSIVE ACTIVE nodeID 93336
            { id = 1291636, label = "Temporal Barrier",  expectedUses = "on CD (talent)", talentGated = true                    },  -- non-PASSIVE ACTIVE nodeID 93258; absorb + Echo 30% on up to 5 allies
            { id = 374227,  label = "Zephyr",            expectedUses = "AoE damage phases",  isUtility = true, talentGated = true },  -- nodeID 93346; 2 min CD; tracked, never penalised
            { id = 359816,  label = "Dream Flight",      expectedUses = "heavy AoE damage",    healerConditional = true, talentGated = true },  -- flies in a line healing all party; major AoE heal CD
            { id = 370537,  label = "Stasis",            expectedUses = "burst ramp"                                              },  -- 1.5 min CD; stores last 3 casts and releases simultaneously; major burst window
            { id = 370665,  label = "Rescue",            expectedUses = "situational",         isUtility = true, talentGated = true },  -- 1 min CD; movement + self/ally cleanse; tracked, never penalised
            { id = 374251,  label = "Cauterizing Flame", expectedUses = "situational",         isUtility = true                     },  -- confirmed id=374251; tracked, never penalised
            { id = 365585,  label = "Expunge",           expectedUses = "situational",         isUtility = true, altIds = {360823}  },  -- 365585 confirmed; 360823=Naturalize (replaces Expunge when talented); tracked, never penalised
            -- Emerald Communion (370960) removed — not in Preservation talent tree or spell list
        },
        rotationalSpells = {
            { id = 366155, label = "Reversion",        minFightSeconds = 20 },  -- non-PASSIVE ACTIVE nodeID 93338
            { id = 355913, label = "Emerald Blossom",  minFightSeconds = 30 },  -- baseline confirmed spell list
            { id = 373861, label = "Temporal Anomaly", minFightSeconds = 20 },  -- non-PASSIVE ACTIVE nodeID 93257
            { id = 364343, label = "Echo",             minFightSeconds = 15 },                      -- non-PASSIVE ACTIVE nodeID 93339; core mechanic
            { id = 360995, label = "Verdant Embrace", minFightSeconds = 20, talentGated = true },  -- nodeID 93341; 15s CD instant heal; 100% adoption
        },
        healerMetrics = { targetOverheal = 30, targetActivity = 80, targetManaEnd = 10 },
        priorityNotes = {
            "Reversion on cooldown — primary single-target HoT filler",
            "Verdant Embrace on cooldown when talented — instant 15s CD targeted heal",
            "Emerald Blossom for group healing efficiency",
            "Dream Breath on cooldown — primary AoE healing",
            "Echo before high-throughput spells to amplify effect",
            "Temporal Anomaly for group HoT spread",
            "Tip the Scales for instant empowered cast during burst",
            "Rewind is a true emergency — save for near-wipes only",
            "Time Dilation to extend a teammate's HoT in critical moments",
        },
        scoreWeights = { cooldownUsage = 30, efficiency = 30, activity = 25, responsiveness = 15 },
        sourceNote = "Midnight 12.0 verified against full Preservation talent tree snapshot v1.5.0 123 nodes (April 2026); May 2026 tooltip pass",
    },

    -- Augmentation (Midnight 12.0 PASSIVE audit — April 2026; May 2026 tooltip pass)
    -- Eruption: was 359618 — talent tree confirms 395160 (nodeID 93200 non-PASSIVE). Corrected.
    -- Time Skip (404977) added to majorCooldowns — non-PASSIVE ACTIVE nodeID 93232
    -- Blistering Scales (360827) added to majorCooldowns — non-PASSIVE ACTIVE nodeID 93209; party defensive
    -- Quell (351338) added as isInterrupt — non-PASSIVE ACTIVE nodeID 93199
    -- Bestow Weyrnstone (408233) added to majorCooldowns as isUtility — nodeID 93382; 54s CD; talentGated; 82% adoption
    -- Rescue (370665) added to majorCooldowns as isUtility talentGated — 1 min CD; movement + self/ally cleanse; all specs
    -- Cauterizing Flame (374251) added to majorCooldowns as isUtility — regular spell; all specs; id confirmed in-game
    -- Expunge (365585) added to majorCooldowns as isUtility — id confirmed; altId 360823=Naturalize replaces it when talented
    -- Timelessness (412710) ADDED 09/06/2026 — confirmed active talent (Rank 0/1; enchants an ally,
    --   reducing their threat 30% for 1.1hr). Ally-targeted like Rescue, but the cast still fires
    --   UNIT_SPELLCAST_SUCCEEDED on the caster — same detection mechanism, should track fine.
    --   Verify with /ms verify on next use since this was never tracked before at all.
    -- Confirmed PASSIVE (May 2026): Fate Mirror, Duplicate (Apex Talent), Imminent Destruction,
    --   Ricocheting Pyroblast, Defy Fate, Stretch Time — none tracked
    [3] = {
        name = "Augmentation", role = "DPS",
        resourceType = 17, resourceLabel = "ESSENCE", overcapAt = 6,
        majorCooldowns = {
            { id = 403631, label = "Breath of Eons",    expectedUses = "burst windows",     altIds = {442204} },  -- non-PASSIVE ACTIVE nodeID 93234; altId 442204 per Archon (May 2026)
            { id = 395152, label = "Ebon Might",        expectedUses = "on CD"             },  -- non-PASSIVE ACTIVE nodeID 93198
            { id = 409311, label = "Prescience",        expectedUses = "pre-burst"         },  -- non-PASSIVE ACTIVE nodeID 93358
            { id = 404977, label = "Time Skip",         expectedUses = "on CD",            talentGated = true, suppressIfTalent = 412713 },  -- non-PASSIVE ACTIVE nodeID 93232; replaced by Interwoven Threads (412713) PASSIVE
            { id = 360827, label = "Blistering Scales", expectedUses = "party mitigation", talentGated = true },  -- non-PASSIVE ACTIVE nodeID 93209
            { id = 351338, label = "Quell",             expectedUses = "situational",      isInterrupt = true              },  -- non-PASSIVE ACTIVE nodeID 93199
            { id = 408233, label = "Bestow Weyrnstone", expectedUses = "situational",      isUtility = true, talentGated = true },  -- nodeID 93382; 54s CD; transport utility; tracked, never penalised
            { id = 370665, label = "Rescue",            expectedUses = "situational",      isUtility = true, talentGated = true },  -- 1 min CD; movement + self/ally cleanse; tracked, never penalised
            { id = 374251, label = "Cauterizing Flame", expectedUses = "situational",      isUtility = true,                    },  -- confirmed id=374251; tracked, never penalised
            { id = 365585, label = "Expunge",           expectedUses = "situational",      isUtility = true, altIds = {360823}  },  -- 365585 confirmed; 360823=Naturalize (replaces Expunge when talented); tracked, never penalised
            { id = 406732, label = "Spatial Paradox",  expectedUses = "situational",      isUtility = true, talentGated = true },  -- Aug class talent; added 05/06/2026
            { id = 412710, label = "Timelessness",     expectedUses = "situational",      isUtility = true, talentGated = true },  -- ally-targeted threat reduction; cast fires on caster same as Rescue; ADDED 09/06/2026
        },
        uptimeBuffs = {
            { id = 395152, label = "Ebon Might", targetUptime = 70, castSpellId = 395152, buffDuration = 10 },  -- 10s base duration; recast every ~30s
        },
        rotationalSpells = {
            { id = 396286, label = "Upheaval",  minFightSeconds = 20 },  -- non-PASSIVE ACTIVE nodeID 93203
            { id = 395160, label = "Eruption",  minFightSeconds = 20 },  -- non-PASSIVE ACTIVE nodeID 93200 (was 359618 — wrong)
        },
        priorityNotes = {
            "Ebon Might on cooldown — core party amplification buff (tracked via uptimeBuffs)",
            "Prescience before burst cooldowns to amplify allies",
            "Upheaval and Eruption for personal damage contribution",
            "Breath of Eons for peak burst — aligns with lust",
            "Time Skip on cooldown when talented — significant throughput increase",
            "Blistering Scales on the most targeted ally when talented",
            "Maintain Ebon Might uptime at 70%+ for maximum support value",
        },
        scoreWeights = { cooldownUsage = 35, mitigationUptime = 30, activity = 25, resourceMgmt = 10 },
        sourceNote = "Midnight 12.0 verified against full Augmentation talent tree snapshot v1.5.0 114 nodes (April 2026); May 2026 tooltip pass",
    },
})
