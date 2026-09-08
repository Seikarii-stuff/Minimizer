local Core = MidnightSensei.Core

Core.RegisterSpec(5, {
    className = "Priest",

    -- Discipline (Midnight 12.0 PASSIVE audit — April 2026)
    -- Power Word: Barrier (62618) ADDED 09/06/2026 — confirmed active talent (Rank 0/1, 3 min CD
    --   raid barrier); prior "not in tree" note was wrong or predated the finalized tree.
    -- Inner Focus (390693) and Holy Ray (372969) confirmed PASSIVE 09/06/2026 via in-game tooltip.
    -- Evangelism ID corrected 246287 → 472433 — nodeID 82577 non-PASSIVE ACTIVE
    -- Rapture (47536) removed — not in Discipline talent tree or spell list
    -- Schism (204263) removed — not in Discipline talent tree or spell list
    -- Power Infusion (10060) added to majorCooldowns — nodeID 82556 non-PASSIVE ACTIVE
    -- Atonement (194384) removed from uptimeBuffs — not in tree/spell list; applied to others not self
    -- Power Word: Radiance (194509) added to rotational — nodeID 82593 non-PASSIVE ACTIVE
    -- Penance (47540) added to rotational — baseline confirmed spell list; primary damage/heal cast
    -- Mind Blast (8092) added to rotational — nodeID 82713 non-PASSIVE ACTIVE
    -- Shadow Word: Death (32379) added to rotational — nodeID 82712 non-PASSIVE ACTIVE
    -- Void Shield (1205350) added to rotational — confirmed spell list (May 2026)
    -- Shadow Word: Pain (589) added to rotational — confirmed Disc cast for Atonement (May 2026)
    [1] = {
        name = "Discipline", role = "HEALER",
        resourceType = 0,
        majorCooldowns = {
            { id = 421453, label = "Ultimate Penitence", expectedUses = "ramp windows"                                    },  -- nodeID 82564 non-PASSIVE ACTIVE
            { id = 33206,  label = "Pain Suppression",   expectedUses = "tank busters",   healerConditional = true        },  -- nodeID 82587 non-PASSIVE ACTIVE
            { id = 472433, label = "Evangelism",         expectedUses = "ramp windows"                                    },  -- nodeID 82577 non-PASSIVE ACTIVE (was 246287)
            { id = 10060,  label = "Power Infusion",     expectedUses = "burst windows",  talentGated = true              },  -- nodeID 82556 non-PASSIVE ACTIVE; class talent
            { id = 73325,  label = "Leap of Faith",     expectedUses = "situational",    isUtility = true, talentGated = true },  -- grip utility; added 05/06/2026; cross-spec with Holy
            { id = 586,    label = "Fade",               expectedUses = "situational",    isUtility = true, talentGated = true },  -- threat drop + movement; added 05/06/2026
            { id = 19236,  label = "Desperate Prayer",  expectedUses = "defensive",      healerConditional = true, talentGated = true },  -- personal defensive; added 05/06/2026
            { id = 62618,  label = "Power Word: Barrier", expectedUses = "situational",  isUtility = true, talentGated = true },  -- 3 min CD raid-wide 20% DR barrier; ADDED 09/06/2026
            -- Rapture (47536) removed — not in talent tree or spell list
            -- Schism (204263) removed — not in talent tree or spell list
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 47540,  label = "Penance",              minFightSeconds = 15 },  -- baseline confirmed spell list; primary damage/heal
            { id = 194509, label = "Power Word: Radiance", minFightSeconds = 20 },  -- nodeID 82593 non-PASSIVE ACTIVE; AoE Atonement applicator
            { id = 8092,   label = "Mind Blast",           minFightSeconds = 20, talentGated = true },  -- nodeID 82713 non-PASSIVE ACTIVE; class talent
            { id = 32379,   label = "Shadow Word: Death", minFightSeconds = 20 },  -- nodeID 82712 non-PASSIVE ACTIVE
            { id = 1205350, label = "Void Shield",        minFightSeconds = 20 },  -- confirmed spell list (May 2026)
            { id = 589,     label = "Shadow Word: Pain",  minFightSeconds = 15 },  -- confirmed Disc cast for Atonement (May 2026)
        },
        healerMetrics = { targetOverheal = 20, targetActivity = 90, targetManaEnd = 5 },
        priorityNotes = {
            "Ramp Atonements before damage windows with Power Word: Shield and Shadow Mend",
            "Evangelism extends all active Atonements — use at peak ramp before burst",
            "Power Word: Radiance to apply Atonement to multiple targets quickly",
            "Penance on cooldown — primary damage and direct healing cast",
            "Mind Blast and Shadow Word: Death for Insanity generation and damage during ramp",
            "Pain Suppression for tank busters",
            "Power Infusion during peak damage windows",
            "Ultimate Penitence as major ramp cooldown",
            "Power Word: Barrier for predictable heavy raid-wide damage when talented",
        },
        scoreWeights = { cooldownUsage = 30, efficiency = 25, activity = 25, responsiveness = 20 },
        sourceNote = "Midnight 12.0 verified against full Discipline talent tree snapshot v1.4.3 111 nodes (April 2026)",
    },

    -- Holy (Midnight 12.0 PASSIVE audit — April 2026)
    -- Prayer of Mending corrected 33076 → 17 — 33076 is the Disc spec-variant; 17 confirmed in Holy spell list
    -- Power Infusion (10060) added to majorCooldowns — nodeID 82556 non-PASSIVE ACTIVE
    -- Guardian Spirit (47788) added to majorCooldowns — nodeID 82637 non-PASSIVE ACTIVE
    -- Holy Word: Serenity (2050) added to rotational — nodeID 82638 non-PASSIVE ACTIVE
    -- Holy Word: Sanctify (34861) added to rotational — nodeID 82631 non-PASSIVE ACTIVE
    -- Holy Fire (14914) added to rotational — nodeID 108730 non-PASSIVE ACTIVE; CDR filler
    -- Halo (120517) added to rotational — nodeID 108724 non-PASSIVE ACTIVE
    [2] = {
        name = "Holy", role = "HEALER",
        resourceType = 0,
        majorCooldowns = {
            { id = 64843,  label = "Divine Hymn",       expectedUses = "heavy raid damage",   healerConditional = true        },  -- nodeID 82621 non-PASSIVE ACTIVE
            { id = 200183, label = "Apotheosis",         expectedUses = "high damage phases",  healerConditional = true        },  -- nodeID 82614 non-PASSIVE ACTIVE
            { id = 47788,  label = "Guardian Spirit",    expectedUses = "tank emergencies",    healerConditional = true        },  -- nodeID 82637 non-PASSIVE ACTIVE
            { id = 10060,  label = "Power Infusion",     expectedUses = "burst windows",       talentGated = true              },  -- nodeID 82556 non-PASSIVE ACTIVE; class talent
            { id = 19236,  label = "Desperate Prayer",  expectedUses = "defensive",           healerConditional = true        },  -- confirmed id=19236; 1.2 min CD personal defensive; no penalty on successful fight
            { id = 73325,  label = "Leap of Faith",    expectedUses = "situational",         isUtility = true, talentGated = true },  -- grip utility; added 05/06/2026; cross-spec with Disc
            -- Prayer of Mending: 33076 removed — Disc spec-variant; 17 is Holy baseline (rotational)
        },
        rotationalSpells = {
            { id = 17,     label = "Prayer of Mending",  minFightSeconds = 15 },  -- confirmed Holy spell list; keep bouncing
            { id = 2050,   label = "Holy Word: Serenity", minFightSeconds = 15 },  -- nodeID 82638 non-PASSIVE ACTIVE
            { id = 34861,  label = "Holy Word: Sanctify", minFightSeconds = 15 },  -- nodeID 82631 non-PASSIVE ACTIVE
            { id = 14914,  label = "Holy Fire",           minFightSeconds = 15 },  -- nodeID 108730 non-PASSIVE ACTIVE; reduces Holy Word CDs
            { id = 120517, label = "Halo",                minFightSeconds = 20, talentGated = true },  -- nodeID 108724 non-PASSIVE ACTIVE
            { id = 88625,  label = "Holy Word: Chastise", minFightSeconds = 20, talentGated = true, hasCombatValue = true, isUtility = true },  -- reduces Holy Word CDs via Answered Prayers; bonus credit, never penalised
            { id = 596,    label = "Prayer of Healing",   minFightSeconds = 20, healerConditional = true },  -- AoE group heal; use when multiple targets are injured
            -- Holy Nova (132157) excluded — situational; M+ vs raid usage varies too widely; same treatment as Scorch
        },
        healerMetrics = { targetOverheal = 25, targetActivity = 85, targetManaEnd = 10 },
        priorityNotes = {
            "Keep Prayer of Mending bouncing at all times — instant, never waste charges",
            "Holy Word: Serenity and Sanctify on cooldown — they reduce each other's CD via Apotheosis",
            "Holy Fire on cooldown — reduces all Holy Word cooldowns via Answered Prayers",
            "Apotheosis for burst damage phases — resets and reduces Holy Word CDs",
            "Guardian Spirit on the tank for emergencies",
            "Divine Hymn for heavy raid-wide burst damage",
            "Power Infusion during Apotheosis for maximum throughput",
            "Halo on cooldown when talented — strong AoE healing",
        },
        scoreWeights = { cooldownUsage = 25, efficiency = 30, activity = 25, responsiveness = 20 },
        sourceNote = "Midnight 12.0 verified against full Holy Paladin talent tree snapshot v1.4.3 103 nodes (April 2026)",
    },

    -- Shadow (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (114 nodes, descriptions) — FLAGGED: 0
    -- Removed:  Shadow Word: Pain (589), Vampiric Touch (34914) from uptimeBuffs — enemy debuffs
    -- Removed:  debuffUptime from scoreWeights
    -- Added:    rotationalSpells: Shadow Word: Pain (589), Vampiric Touch (34914),
    --           Devouring Plague (335467), Mind Blast (8092)
    -- Halo (120644) added as talentGated rotational — nodeID 94697 non-PASSIVE ACTIVE
    --   Shadow spec-variant (different ID from Holy's 120517)
    [3] = {
        name = "Shadow", role = "DPS",
        resourceType = 13, resourceLabel = "INSANITY", overcapAt = 90,
        majorCooldowns = {
            { id = 228260,  label = "Voidform",        expectedUses = "on CD", minFightSeconds = 60 },  -- renamed from Void Eruption in 12.0
            { id = 10060,   label = "Power Infusion",  expectedUses = "on CD", minFightSeconds = 60, talentGated = true },  -- class talent, sync with Voidform
            { id = 263165,  label = "Void Torrent",    expectedUses = "on CD", talentGated = true },    -- Voidweaver only
            { id = 1227280, label = "Tentacle Slam",   expectedUses = "on CD", talentGated = true },    -- renamed from Shadow Crash in 12.0
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 589,    label = "Shadow Word: Pain",  minFightSeconds = 15,
              suppressIfTalent = 238558 },   -- Misery (238558): VT auto-applies SW:Pain passively
            { id = 34914,  label = "Vampiric Touch",     minFightSeconds = 15,
              suppressIfTalent = 1227280 },  -- Tentacle Slam auto-applies VT to up to 6 targets
            { id = 335467, label = "Shadow Word: Madness", minFightSeconds = 20 },
            { id = 8092,   label = "Mind Blast",           minFightSeconds = 20, talentGated = true },  -- class talent; nodeID 82713
            { id = 15407,  label = "Mind Flay",            minFightSeconds = 15 },                      -- baseline filler
            { id = 32379,  label = "Shadow Word: Death",   minFightSeconds = 20, talentGated = true },  -- class talent; nodeID 82712
            { id = 450983, label = "Void Blast",           minFightSeconds = 20, talentGated = true, altIds = {450405} },  -- Voidweaver: empowered MB during Voidform
            { id = 1242173, label = "Void Volley",         minFightSeconds = 20, talentGated = true },  -- Voidweaver AoE
            { id = 120644, label = "Halo",                 minFightSeconds = 30, talentGated = true },  -- Shadow spec-variant; nodeID 94697 non-PASSIVE ACTIVE
        },
        priorityNotes = {
            "Cast Vampiric Touch to apply Shadow Word: Pain automatically (Misery talent)",
            "Without Misery: manually cast Shadow Word: Pain as opener DoT",
            "Tentacle Slam applies Vampiric Touch to up to 6 targets automatically (talent)",
            "Without Tentacle Slam: manually cast Vampiric Touch as opener DoT",
            "Enter Voidform on cooldown — primary damage cooldown in Midnight 12.0",
            "Power Infusion on cooldown — sync with Voidform for maximum burst",
            "Shadow Word: Madness to spend Insanity — never overcap at 90",
            "Mind Blast on cooldown for Insanity generation",
            "Mind Flay as filler when no higher-priority cast is available",
            "Shadow Word: Death on cooldown — execute below 20% HP",
            "Void Blast during Voidform (Voidweaver) — empowered Mind Blast",
            "Void Volley on cooldown (Voidweaver) — AoE damage",
            "Void Torrent on cooldown (Voidweaver) — strong channel, do not cancel",
            "Tentacle Slam on cooldown (talent) — applies Vampiric Touch to up to 6 targets",
            "Halo on cooldown when talented — strong AoE damage",
        },
        scoreWeights = { cooldownUsage = 25, activity = 35, resourceMgmt = 25, procUsage = 15 },
        sourceNote = "Midnight 12.0 verified against full Shadow talent tree snapshot v1.4.3 114 nodes (April 2026)",
    },
})
