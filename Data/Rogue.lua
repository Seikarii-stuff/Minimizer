local Core = MidnightSensei.Core

Core.RegisterSpec(4, {
    className = "Rogue",

    -- Assassination (Midnight 12.0 PASSIVE audit — April 2026)
    -- Vendetta (79140) removed — not in Assassination talent tree or spell list
    -- Kick (1766) added as isInterrupt — confirmed Assassination spell list
    -- Envenom: reverted 196819 → 32645 — session log confirms 32645 fires; altIds={276245} (second component ID)
    -- Mutilate: corrected 1752 → 1329 — session log confirms 1329 fires; altIds={5374,27576} (main-hand + off-hand hit IDs)
    -- Rupture: corrected 1943 → 199672 — Assassination spec-variant; session log confirms 199672 fires
    -- Fan of Knives (51723) added to rotational — baseline AoE builder; session log confirmed
    -- Ambush (8676) added as isUtility talentGated — situational stealth opener; not always accessible
    -- Crimson Tempest (1247227) added to rotational — nodeID 94557 non-PASSIVE ACTIVE; AoE finisher
    [1] = {
        name = "Assassination", role = "DPS",
        resourceType = 4, resourceLabel = "ENERGY", overcapAt = 100,
        majorCooldowns = {
            { id = 360194, label = "Deathmark",        expectedUses = "on CD"           },  -- nodeID 90769 non-PASSIVE ACTIVE
            { id = 385627, label = "Kingsbane",        expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 90770 non-PASSIVE ACTIVE
            { id = 381623, label = "Thistle Tea",      expectedUses = "proactive (3 charges)", talentGated = true },  -- nodeID 90756; 3 charges 1 min recharge; use proactively alongside Kingsbane/Deathmark; added 05/07/2026
            { id = 1766,   label = "Kick",             expectedUses = "situational",    isInterrupt = true },  -- confirmed Assassination spell list
            { id = 31224,  label = "Cloak of Shadows", expectedUses = "situational",   isUtility = true   },  -- defensive/immunity CD; added 05/06/2026; cross-spec
            -- Vendetta (79140) removed — not in Assassination talent tree or spell list
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 703,    label = "Garrote",          minFightSeconds = 15 },  -- confirmed spell list; opener bleed
            { id = 199672, label = "Rupture",          minFightSeconds = 15 },  -- Assassination spec-variant; session log confirmed (was 1943)
            { id = 1329,   label = "Mutilate",         minFightSeconds = 15, altIds = {5374, 27576} },  -- session log confirmed; 5374/27576 are MH+OH hit IDs (was 1752)
            { id = 32645,  label = "Envenom",          minFightSeconds = 20, altIds = {276245} },  -- session log confirmed; 276245 is second component ID (was 196819)
            { id = 51723,  label = "Fan of Knives",    minFightSeconds = 20 },                      -- baseline AoE builder; session log confirmed
            { id = 8676,   label = "Ambush",           isUtility = true, talentGated = true },      -- situational stealth opener; not always accessible
            { id = 1247227,label = "Crimson Tempest",  minFightSeconds = 20, talentGated = true },  -- nodeID 94557 non-PASSIVE ACTIVE; AoE finisher
        },
        priorityNotes = {
            "Maintain Garrote and Rupture on all targets — core bleed damage",
            "Mutilate to build combo points — primary builder",
            "Envenom at 4-5 combo points — primary finisher and damage amp",
            "Deathmark doubles all bleeds — use with Kingsbane for burst",
            "Crimson Tempest for AoE — keeps bleeds rolling on multiple targets",
        },
        scoreWeights = { cooldownUsage = 30, activity = 35, resourceMgmt = 25, procUsage = 10 },
        sourceNote = "Midnight 12.0 verified against full Assassination talent tree snapshot v1.4.3 103 nodes (April 2026)",
    },

    -- Outlaw (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (102 nodes, descriptions) — FLAGGED: 0
    -- Roll the Bones corrected 315508 → 1214909 — confirmed Outlaw spell list
    -- Blade Rush (271877) added to majorCooldowns — nodeID 90649 non-PASSIVE ACTIVE
    -- Keep It Rolling (381989) added to majorCooldowns — nodeID 90652 non-PASSIVE ACTIVE
    -- Kick (1766) added as isInterrupt — confirmed Outlaw spell list
    -- Killing Spree (51690) added as talentGated CD — nodeID 94565 INACTIVE this build
    -- Between the Eyes corrected 199804 → 315341 — Outlaw spec-variant confirmed spell list
    -- Dispatch: reverted 196819 → 2098 — session log confirms 2098 fires (196819 correction was wrong)
    -- Sinister Strike: corrected 1752 → 193315 — session log confirmed
    -- Pistol Shot (185763) added to rotational — confirmed Outlaw spell list; builder/proc spender
    -- Thistle Tea (1298826) ADDED 09/06/2026 — same node (90756) as Assassination's Thistle Tea,
    --   but a DIFFERENT spell ID: Outlaw/Subtlety's version is manually cast (no auto-drink-at-low-
    --   energy clause), unlike Assassination's 381623 which auto-triggers below 30 energy. Confirmed
    --   via in-game tooltip; expected to be used regularly, not held.
    [2] = {
        name = "Outlaw", role = "DPS",
        resourceType = 4, resourceLabel = "ENERGY", overcapAt = 100,
        majorCooldowns = {
            { id = 13750,   label = "Adrenaline Rush",  expectedUses = "on CD"          },  -- nodeID 90659 non-PASSIVE ACTIVE
            { id = 1214909, label = "Roll the Bones",   expectedUses = "keep refreshed" },  -- confirmed Outlaw spell list (was 315508)
            { id = 13877,   label = "Blade Flurry",     expectedUses = "AoE on CD"      },  -- baseline confirmed Outlaw spell list
            { id = 271877,  label = "Blade Rush",       expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 90649 non-PASSIVE ACTIVE
            { id = 381989,  label = "Keep It Rolling",  expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 90652 non-PASSIVE ACTIVE
            { id = 51690,   label = "Killing Spree",    expectedUses = "burst windows (talent)", talentGated = true },  -- nodeID 94565 INACTIVE this build
            { id = 1766,    label = "Kick",             expectedUses = "situational",    isInterrupt = true },
            { id = 31224,   label = "Cloak of Shadows", expectedUses = "situational",   isUtility = true   },  -- added 05/06/2026; cross-spec
            { id = 14185,   label = "Preparation",      expectedUses = "situational (boss fights)", isUtility = true, talentGated = true, altIds = {1277933} },  -- CD reset utility; added 05/06/2026
            { id = 1298826, label = "Thistle Tea",      expectedUses = "on CD (3 charges)", talentGated = true },  -- nodeID 90756; manual-cast variant (not auto-drink like Assassination's 381623); ADDED 09/06/2026
        },
        rotationalSpells = {
            { id = 193315, label = "Sinister Strike",  minFightSeconds = 15 },  -- session log confirmed (was 1752)
            { id = 185763, label = "Pistol Shot",      minFightSeconds = 15 },
            { id = 315341, label = "Between the Eyes", minFightSeconds = 20 },
            { id = 2098,   label = "Dispatch",         minFightSeconds = 20 },  -- session log confirmed (was 196819)
        },
        priorityNotes = {
            "Keep Roll the Bones active — reroll for better buffs with Keep It Rolling",
            "Adrenaline Rush on cooldown — massive Energy regeneration burst",
            "Between the Eyes on cooldown during Adrenaline Rush for burst",
            "Sinister Strike / Pistol Shot to build combo points",
            "Dispatch at 5+ combo points — primary finisher",
            "Killing Spree for burst when talented",
            "Blade Flurry for any 2+ target situation",
            "Thistle Tea on cooldown when talented — regular Energy refill, not just emergencies",
        },
        scoreWeights = { cooldownUsage = 35, activity = 35, resourceMgmt = 20, procUsage = 10 },
        sourceNote = "Midnight 12.0 verified against full Outlaw talent tree snapshot v1.4.3 102 nodes (April 2026)",
    },

    -- Subtlety (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (105 nodes, descriptions) — FLAGGED: 0
    -- Symbols of Death (212283) removed — not in Subtlety talent tree or spell list
    -- Kick (1766) added as isInterrupt — confirmed Subtlety spell list
    -- Nightblade (195452) removed from rotational — not in Subtlety talent tree or spell list
    -- Backstab: corrected 1752 → 53 — session log confirmed; suppressIfTalent=200758 (Gloomblade) retained
    --   Gloomblade is a choice node replacing Backstab; only one tracked depending on talent.
    -- Goremaw's Bite (426591) added as talentGated CD — nodeID 94581 INACTIVE this build
    -- Shuriken Storm (197835) added to rotational — confirmed Sub spell list; AoE builder
    -- Secret Technique (280719) added to majorCooldowns talentGated — session log confirmed; guide showed 280720 (off by one)
    -- Black Powder (319175) added to rotational — baseline Subtlety AoE finisher; top M+ ability (29% damage)
    -- Unseen Blade (441144) + Coup de Grace (441776) — both passive Trickster procs; not tracked
    -- Thistle Tea (1298826) ADDED 09/06/2026 — same node (90756) as Assassination's Thistle Tea,
    --   but manually cast (no auto-drink-at-low-energy clause). Confirmed via in-game tooltip;
    --   expected to be used regularly, not held.
    [3] = {
        name = "Subtlety", role = "DPS",
        resourceType = 4, resourceLabel = "ENERGY", overcapAt = 100,
        majorCooldowns = {
            { id = 185313, label = "Shadow Dance",   expectedUses = "burst windows"           },  -- baseline confirmed Sub spell list
            { id = 121471, label = "Shadow Blades",  expectedUses = "on CD"                   },  -- nodeID 90726 non-PASSIVE ACTIVE
            { id = 426591, label = "Goremaw's Bite",    expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 94581 INACTIVE this build
            { id = 280719, label = "Secret Technique", expectedUses = "on CD (talent)", talentGated = true },  -- session log confirmed (guide showed 280720)
            { id = 1766,   label = "Kick",             expectedUses = "situational",    isInterrupt = true },
            { id = 31224,  label = "Cloak of Shadows", expectedUses = "situational",   isUtility = true   },  -- added 05/06/2026; cross-spec
            { id = 1298826, label = "Thistle Tea",     expectedUses = "on CD (3 charges)", talentGated = true },  -- nodeID 90756; manual-cast variant (not auto-drink like Assassination's 381623); ADDED 09/06/2026
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 185438, label = "Shadowstrike",   minFightSeconds = 20 },  -- confirmed Sub spell list; Stealth builder
            { id = 53,     label = "Backstab",       minFightSeconds = 15,
              suppressIfTalent = 200758 },   -- session log confirmed (was 1752); Gloomblade replaces Backstab as primary builder
            { id = 200758, label = "Gloomblade",     minFightSeconds = 15, talentGated = true },  -- choice node replacing Backstab
            { id = 196819, label = "Eviscerate",     minFightSeconds = 20 },  -- confirmed Sub spell list; primary finisher
            { id = 319175, label = "Black Powder",   minFightSeconds = 20 },  -- baseline AoE finisher; top M+ ability
            { id = 197835, label = "Shuriken Storm", minFightSeconds = 20 },  -- confirmed Sub spell list; AoE builder
        },
        priorityNotes = {
            "Shadow Dance for burst — spend with Shadowstrike inside every window",
            "Shadow Blades on cooldown — sustained burst and CP generation",
            "Shadowstrike inside Shadow Dance, Backstab (or Gloomblade) outside",
            "Eviscerate at 5+ combo points — primary finisher",
            "Goremaw's Bite on cooldown when talented",
            "Shuriken Storm as AoE builder at 3+ targets",
            "Thistle Tea on cooldown when talented — regular Energy refill, not just emergencies",
        },
        scoreWeights = { cooldownUsage = 35, activity = 40, resourceMgmt = 25 },
        sourceNote = "Midnight 12.0 verified against full Subtlety talent tree snapshot v1.4.3 105 nodes (April 2026)",
    },
})
