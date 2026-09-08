local Core = MidnightSensei.Core

Core.RegisterSpec(1, {
    className = "Warrior",

    -- Arms (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (99 nodes, descriptions)
    -- Bladestorm (227847) RESTORED 09/06/2026 — choice node 90441 with Ravager (228920);
    --   confirmed active via in-game tooltip (Rank 1/1, 1.5 min CD). Prior "not in Arms
    --   talent tree" note from the v1.4.3 snapshot audit was incorrect or predated the
    --   finalized tree. Mutual suppressIfTalent added both directions.
    -- Warbreaker (262161) removed — not in Arms talent tree or spell list
    -- Avatar (107574) confirmed non-PASSIVE ACTIVE nodeID 110176
    -- Ravager (228920) added as talentGated CD — nodeID 90441 non-PASSIVE ACTIVE
    -- Demolish (436358) added as talentGated CD — nodeID 94818 non-PASSIVE ACTIVE
    -- Shockwave (46968) added as talentGated CD — non-PASSIVE ACTIVE; shared class node
    -- Colossus Smash (167105) added to rotational — nodeID 90290 non-PASSIVE ACTIVE
    -- Overpower (7384) added to rotational — nodeID 90271 non-PASSIVE ACTIVE
    -- Rend (772) added to rotational — nodeID 109391 non-PASSIVE ACTIVE
    -- Cleave (845) added to rotational — confirmed combat cast ID x1; talentGated
    -- Die by the Sword (118038) added to majorCooldowns as isUtility — confirmed id=118038; personal defensive
    -- Flags: Battlefield Commander/Deep Wounds/Mortal Wounds — Causes/Grants = effect
    --   descriptions only, no spell-replacement pattern. No suppressIfTalent needed.
    [1] = {
        name = "Arms", role = "DPS",
        resourceType = 1, resourceLabel = "RAGE", overcapAt = 100,
        majorCooldowns = {
            { id = 107574, label = "Avatar",     expectedUses = "on CD", talentGated = true },  -- nodeID 110176 non-PASSIVE ACTIVE; class talent
            { id = 228920, label = "Ravager",    expectedUses = "on CD (talent)", talentGated = true, suppressIfTalent = 227847 },  -- nodeID 90441 non-PASSIVE ACTIVE; choice node with Bladestorm
            { id = 227847, label = "Bladestorm", expectedUses = "on CD (talent)", talentGated = true, suppressIfTalent = 228920 },  -- nodeID 90441 non-PASSIVE ACTIVE; choice node with Ravager; RESTORED 09/06/2026
            { id = 436358, label = "Demolish",   expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 94818 non-PASSIVE ACTIVE
            { id = 46968,  label = "Shockwave",     expectedUses = "situational",    talentGated = true, isUtility = true, hasCombatValue = true },  -- AoE stun + damage; aimed/held for packs — never penalised
            { id = 118038, label = "Die by the Sword", expectedUses = "situational",    isUtility = true    },  -- confirmed id=118038; personal defensive — tracked, never penalised
            { id = 97462,  label = "Rallying Cry",     expectedUses = "situational",    isUtility = true, talentGated = true },  -- confirmed id=97462; party HP utility; talent gated (May 2026)
            { id = 1277297, label = "Ignore Pain",    expectedUses = "physical hits",   talentGated = true },  -- absorb shield for Arms; Midnight 12.0 class talent; proactive mitigation
            -- Warbreaker (262161) removed — not in Arms talent tree or spell list
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 12294,  label = "Mortal Strike",  minFightSeconds = 15 },  -- nodeID 90270 non-PASSIVE ACTIVE
            { id = 167105, label = "Colossus Smash", minFightSeconds = 20 },  -- nodeID 90290 non-PASSIVE ACTIVE
            { id = 7384,   label = "Overpower",      minFightSeconds = 15 },  -- nodeID 90271 non-PASSIVE ACTIVE
            { id = 772,    label = "Rend",            minFightSeconds = 15 },                      -- nodeID 109391 non-PASSIVE ACTIVE
            { id = 163201, label = "Execute",         minFightSeconds = 45 },                      -- confirmed spell list; execute phase
            { id = 845,    label = "Cleave",          minFightSeconds = 20, talentGated = true },  -- confirmed combat cast ID x1; AoE filler
        },
        priorityNotes = {
            "Maintain Rend on target — DoT setup before Colossus Smash",
            "Mortal Strike on cooldown — primary damage and healing debuff",
            "Colossus Smash to open damage windows — high priority",
            "Overpower on cooldown — free proc-based filler",
            "Execute during execute phase — replaces Mortal Strike below 20%",
            "Cleave on cooldown when talented — AoE filler",
            "Avatar and Ravager/Bladestorm (whichever is talented) for burst — align with Colossus Smash",
            "Shockwave on cooldown when talented — AoE stun and damage",
            "Die by the Sword situationally — personal defensive, no penalty for unused",
            "Pool Rage for Colossus Smash windows — avoid overcapping at 100",
        },
        scoreWeights = { cooldownUsage = 35, activity = 40, resourceMgmt = 25 },
        sourceNote = "Midnight 12.0 verified against full Arms talent tree snapshot v1.4.3 99 nodes (April 2026)",
    },

    -- Fury (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (101 nodes, descriptions)
    -- Onslaught (315720) removed — not in Fury talent tree or spell list
    -- Avatar (107574) added to majorCooldowns — nodeID 90415 non-PASSIVE ACTIVE
    -- Odyn's Fury (385059) added to majorCooldowns — nodeID 110203 non-PASSIVE ACTIVE
    -- Demolish (436358) added as talentGated CD — nodeID 94818 non-PASSIVE ACTIVE
    -- Shockwave (46968) added as talentGated CD — non-PASSIVE ACTIVE; shared class node
    -- Champion's Spear (376079) added as talentGated CD — non-PASSIVE ACTIVE; shared class node
    -- Raging Blow (85288) added to rotational — nodeID 90396 non-PASSIVE ACTIVE
    -- Berserker Stance (386196) added to rotational — nodeID 90325 non-PASSIVE ACTIVE
    -- Rend (772) added to rotational — non-PASSIVE ACTIVE; shared class node, DoT maintenance
    -- Whirlwind added to rotational — two combat cast IDs confirmed: 199667 (primary) and 190411 (altId)
    -- Execute (280735) added to rotational — confirmed combat cast ID; Improved Execute (316402) is PASSIVE
    -- Enrage uptime buff: 184362 retained (VERIFY — spell list shows 184361; 184362 may be enhanced version)
    -- Ravager (228920) / Bladestorm (227847) ADDED 09/06/2026 — choice node pair, same as Arms;
    --   never previously added to Fury at all (not a stale removal, just missed). User confirmed
    --   live in-game. Mutual suppressIfTalent added both directions.
    -- Flags: Battlefield Commander/Deep Wounds — Grants/Causes = effect descriptions only
    [2] = {
        name = "Fury", role = "DPS",
        resourceType = 1, resourceLabel = "RAGE", overcapAt = 100,
        majorCooldowns = {
            { id = 1719,   label = "Recklessness",    expectedUses = "on CD"           },  -- nodeID 90412 non-PASSIVE ACTIVE
            { id = 107574, label = "Avatar",           expectedUses = "on CD", talentGated = true },  -- nodeID 90415 non-PASSIVE ACTIVE; class talent
            { id = 385059, label = "Odyn's Fury",      expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 110203 non-PASSIVE ACTIVE
            { id = 436358, label = "Demolish",         expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 94818 non-PASSIVE ACTIVE
            { id = 46968,  label = "Shockwave",        expectedUses = "situational",    talentGated = true, isUtility = true, hasCombatValue = true },  -- AoE stun + damage; aimed/held for packs — never penalised
            { id = 376079, label = "Champion's Spear",     expectedUses = "on CD (talent)", talentGated = true },  -- non-PASSIVE ACTIVE; shared class node
            { id = 97462,  label = "Rallying Cry",         expectedUses = "situational",    isUtility = true, talentGated = true },  -- confirmed id=97462; party HP utility; talent gated (May 2026)
            { id = 184364, label = "Enraged Regeneration", expectedUses = "situational",    healerConditional = true, talentGated = true },  -- confirmed id=184364; personal healing CD; talent gated (May 2026)
            { id = 107570, label = "Storm Bolt",          expectedUses = "situational",    isUtility = true, hasCombatValue = true, talentGated = true },  -- class talent; AoE stun + damage; added 05/06/2026
            { id = 228920, label = "Ravager",    expectedUses = "on CD (talent)", talentGated = true, suppressIfTalent = 227847 },  -- choice node with Bladestorm; ADDED 09/06/2026
            { id = 227847, label = "Bladestorm", expectedUses = "on CD (talent)", talentGated = true, suppressIfTalent = 228920 },  -- choice node with Ravager; ADDED 09/06/2026
            -- Onslaught (315720) removed — not in Fury talent tree or spell list
        },
        uptimeBuffs = {
            { id = 184362, label = "Enrage", targetUptime = 60, castSpellIds = {23881, 184367}, buffDuration = 8 },  -- Bloodthirst and Rampage both apply/extend Enrage
        },
        rotationalSpells = {
            { id = 23881,  label = "Bloodthirst",     minFightSeconds = 15 },  -- nodeID 90392 non-PASSIVE ACTIVE; primary Enrage trigger
            { id = 184367, label = "Rampage",          minFightSeconds = 20 },  -- nodeID 90408 non-PASSIVE ACTIVE; primary Rage spender
            { id = 85288,  label = "Raging Blow",      minFightSeconds = 15 },  -- nodeID 90396 non-PASSIVE ACTIVE; core filler
            { id = 386196, label = "Berserker Stance", minFightSeconds = 15 },  -- nodeID 90325 non-PASSIVE ACTIVE
            { id = 772,    label = "Rend",             minFightSeconds = 15, talentGated = true },  -- non-PASSIVE ACTIVE; shared class node; DoT maintenance
            { id = 199667, label = "Whirlwind",        minFightSeconds = 15, altIds = {190411} },   -- two combat cast IDs confirmed: 199667 and 190411; AoE filler
            { id = 280735, label = "Execute",           minFightSeconds = 45 },                      -- confirmed combat cast ID; Improved Execute (316402) is PASSIVE
        },
        priorityNotes = {
            "Bloodthirst on cooldown — primary Enrage trigger and Rage builder",
            "Rampage to refresh Enrage and spend Rage — never sit on 100 Rage",
            "Raging Blow as filler during Enrage — high priority",
            "Whirlwind on cooldown — AoE filler, applies Whirlwind buff for cleave",
            "Execute during execute phase — high priority below 20% HP",
            "Maintain Rend for the DoT when talented",
            "Recklessness to align with Enrage and trinkets for burst",
            "Odyn's Fury, Avatar, Champion's Spear, and Ravager/Bladestorm (whichever is talented) on cooldown when talented",
            "Shockwave and Demolish inside burst windows when talented",
        },
        scoreWeights = { cooldownUsage = 30, mitigationUptime = 25, activity = 25, resourceMgmt = 20 },
        sourceNote = "Midnight 12.0 verified against full Fury talent tree snapshot v1.4.3 101 nodes (April 2026)",
    },

    -- Protection (Midnight 12.0 PASSIVE audit — April 2026)
    -- Verified against v1.4.3 talent snapshot (102 nodes, descriptions)
    -- Last Stand (12975) removed — talent tree shows 1243659 Last Stand as PASSIVE INACTIVE
    -- Demolish (436358) added as talentGated CD — nodeID 94818 non-PASSIVE ACTIVE
    -- Demoralizing Shout (1160) added to majorCooldowns — nodeID 90305 non-PASSIVE ACTIVE; debuff CD
    -- Disrupting Shout (386071) added as isInterrupt — nodeID 107579 non-PASSIVE ACTIVE
    -- Revenge (6572) added to rotational — nodeID 90298 non-PASSIVE ACTIVE; core Rage spender
    -- Rend (772) suppressIfTalent=6343 — Thunder Clap (nodeID 90343) auto-applies Rend on every
    --   cast when talented; suppressed when TC is taken; tracked only if TC is not taken
    -- Shield Slam (23922) baseline confirmed in spell list; not in talent tree node — fine
    -- Storm Bolt (107570) added as isUtility talentGated — nodeID 90337; 27s CD stun; 94% adoption;
    --   tracked as CC mechanism, never penalised
    -- Flags: Battlefield Commander/Deep Wounds/Intimidating Shout — Causes/Grants = effect
    --   descriptions only, no spell-replacement pattern. No suppressIfTalent needed.
    [3] = {
        name = "Protection", role = "TANK",
        resourceType = 1, resourceLabel = "RAGE", overcapAt = 100,
        majorCooldowns = {
            { id = 871,    label = "Shield Wall",        expectedUses = "big hits",        healerConditional = true },  -- nodeID 90302 non-PASSIVE ACTIVE; reactive — 90% credit if unused on a kill
            { id = 107574, label = "Avatar",             expectedUses = "on CD", talentGated = true },  -- nodeID 90433 non-PASSIVE ACTIVE; class talent
            { id = 190456, label = "Ignore Pain",        expectedUses = "physical hits"   },  -- nodeID 90295 non-PASSIVE ACTIVE
            { id = 1160,   label = "Demoralizing Shout", expectedUses = "on CD"           },  -- nodeID 90305 non-PASSIVE ACTIVE
            { id = 436358, label = "Demolish",           expectedUses = "on CD (talent)", talentGated = true },  -- nodeID 94818 non-PASSIVE ACTIVE
            { id = 386071, label = "Disrupting Shout",   expectedUses = "situational",    isInterrupt = true },  -- nodeID 107579 non-PASSIVE ACTIVE
            { id = 107570, label = "Storm Bolt",   expectedUses = "situational",    isUtility = true, hasCombatValue = true, talentGated = true },  -- nodeID 90337; 27s CD stun + damage; tracked as CC, never penalised
            { id = 97462,  label = "Rallying Cry", expectedUses = "situational",    isUtility = true, talentGated = true },  -- confirmed id=97462; party HP utility; talent gated (May 2026)
            { id = 46968,  label = "Shockwave",    expectedUses = "situational",    talentGated = true, isUtility = true, hasCombatValue = true },  -- AoE stun + damage; aimed/held for packs — never penalised
            { id = 228920, label = "Ravager",      expectedUses = "on CD (talent)", talentGated = true, hasCombatValue = true },  -- spinning weapon; AoE damage + Rage; situational — bonus credit, never penalised
            { id = 385952, label = "Shield Charge", expectedUses = "situational",   talentGated = true },  -- mobility + damage; Prot Warrior talent
            { id = 12323,  label = "Piercing Howl", expectedUses = "situational",  isUtility = true, talentGated = true },  -- AoE slowing shout; added 05/06/2026
            -- Last Stand (12975) removed — confirmed PASSIVE in talent tree
        },
        uptimeBuffs = {
            { id = 132404, label = "Shield Block", targetUptime = 50, castSpellId = 2565, buffDuration = 6 },  -- cast 2565 applies buff 132404 for 6s
        },
        rotationalSpells = {
            { id = 6343,  label = "Thunder Clap", minFightSeconds = 15 },  -- nodeID 90343 non-PASSIVE ACTIVE talent; auto-applies Rend on all targets when talented
            { id = 23922, label = "Shield Slam",  minFightSeconds = 15 },  -- baseline confirmed spell list
            { id = 6572,  label = "Revenge",      minFightSeconds = 15 },  -- nodeID 90298 non-PASSIVE ACTIVE; core Rage spender
            { id = 772,   label = "Rend",         minFightSeconds = 15, talentGated = true, suppressIfTalent = 6343 },  -- suppressed when Thunder Clap is taken (auto-applied); tracked only without TC
        },
        tankMetrics = { targetMitigationUptime = 50 },
        priorityNotes = {
            "Maintain Shield Block for physical mitigation (tracked via uptimeBuffs)",
            "Shield Slam on cooldown — primary Rage generator and damage",
            "Thunder Clap on cooldown — AoE damage, slowing, and auto-applies Rend when talented",
            "Revenge to spend Rage — free when proc fires",
            "Ignore Pain to absorb incoming physical hits",
            "Demoralizing Shout on cooldown — damage reduction for the group",
            "Shield Wall for heavy magic or unavoidable damage",
            "Demolish inside burst windows when talented",
        },
        scoreWeights = { cooldownUsage = 30, mitigationUptime = 35, activity = 20, resourceMgmt = 15 },
        sourceNote = "Midnight 12.0 verified against full Protection talent tree snapshot v1.4.3 102 nodes (April 2026); May 2026 second-pass",
    },
})
