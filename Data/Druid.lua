local Core = MidnightSensei.Core

Core.RegisterSpec(11, {
    className = "Druid",

    -- Balance (Midnight 12.0 rotation guide pass — April 2026)
    -- Rotation priority sourced from Icy Veins / Wowhead Balance Druid guide
    -- Starfall moved from majorCooldowns to rotationalSpells — it's a spender, not a burst CD
    -- Force of Nature (205636) added as talentGated CD — appears in both hero talent priority lists
    -- Fury of Elune (202770) added to rotational — high priority during Eclipse in both priority lists
    -- Wrath (5176) added to rotational — baseline filler, primary AP generator
    -- Hero talent builds differ (Incarnation vs Celestial Alignment) — both talentGated
    -- CA (194223) is a prerequisite node for Incarnation — IsTalentActive returns true on both builds
    -- suppressIfTalent = 102560 on CA: if Incarnation is taken, CA is suppressed from tracking
    [1] = {
        name = "Balance", role = "DPS",
        resourceType = 8, resourceLabel = "ASTRAL POWER", overcapAt = 90,
        majorCooldowns = {
            { id = 194223, label = "Celestial Alignment",          expectedUses = "on CD",          talentGated = true, suppressIfTalent = 102560 },  -- CA build; suppress when Incarnation taken (CA is a prereq node — IsTalentActive returns true on both builds)
            -- Orbital Strike: confirmed PASSIVE 09/06/2026 via in-game tooltip; correct current ID is 390378, not the old 383410 recorded here — not tracked either way
            { id = 102560, label = "Incarnation: Chosen of Elune", expectedUses = "on CD (talent)", talentGated = true },  -- Incarnation build; confirmed fires UNIT_SPELLCAST_SUCCEEDED (verify 2x)
            { id = 205636, label = "Force of Nature",              expectedUses = "on CD (talent)",  talentGated = true, isUtility = true, hasCombatValue = true },  -- treants root + damage; optional — not widely used on cooldown
            { id = 391528, label = "Convoke the Spirits",         expectedUses = "burst windows",   talentGated = true },  -- nodeID 88206 non-PASSIVE ACTIVE; added May 2026
            { id = 78675,  label = "Solar Beam",                  expectedUses = "situational",     talentGated = true, isInterrupt = true },  -- silence/interrupt; informational only — no penalty
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 8921,   label = "Moonfire",      minFightSeconds = 15 },                      -- priority #1 — maintain DoT
            { id = 93402,  label = "Sunfire",       minFightSeconds = 15 },                      -- priority #2 — maintain DoT
            { id = 202770, label = "Fury of Elune", minFightSeconds = 20, talentGated = true },  -- priority #3 — use during Eclipse
            { id = 191034, label = "Starfall",  minFightSeconds = 20 },                                                   -- priority #8 — AoE AP spender
            { id = 78674,  label = "Starsurge", minFightSeconds = 20, suppressIfTalent = 1271206 },                   -- priority #9 — main ST spender; suppress when Star Cascade (1271206) auto-fires it passively
            { id = 5176,   label = "Wrath",     minFightSeconds = 15, orGroup = "filler", suppressIfTalent = 429523, altIds = {190984} }, -- Solar Eclipse filler; 190984 = Eclipse:Wrath combat cast ID (spellbook=5176 differs from UNIT_SPELLCAST_SUCCEEDED in Midnight 12.0); suppress when Lunar Calling (429523)
            { id = 194153, label = "Starfire",  minFightSeconds = 15, orGroup = "filler" },                           -- Lunar Eclipse filler / AoE; live-verified cast ID 194153
            { id = 274281, label = "New Moon",      minFightSeconds = 20, talentGated = true },  -- cycles through New/Half/Full Moon charges; use on cooldown
            { id = 88747,  label = "Wild Mushroom", minFightSeconds = 20, talentGated = true },  -- place under target for AoE damage; triggers on movement
        },
        priorityNotes = {
            "Maintain Moonfire and Sunfire on all targets — refresh within pandemic (not directly tracked)",
            "Fury of Elune during Eclipse or before Force of Nature when talented",
            "Force of Nature when not in Eclipse and about to enter Solar Eclipse",
            "Celestial Alignment / Incarnation as burst window — use Force of Nature first",
            "Starfall to consume Starweaver's Warp procs and for AoE",
            "Starsurge as main spender — use on movement, near AP cap, or Starweaver's Weft procs",
            "Wrath to generate Astral Power — never overcap at 90",
        },
        scoreWeights = { cooldownUsage = 30, activity = 35, resourceMgmt = 25, procUsage = 10 },
        sourceNote = "Midnight 12.0 verified against full Balance talent tree snapshot v1.4.3 113 nodes (April 2026)",
    },

    -- Feral (PASSIVE audit — April 2026; May 2026 Archon sweep)
    -- Incarnation: Avatar of Ashamane (102543) ADDED 09/06/2026 — confirmed active talent via
    --   in-game tooltip (Rank 0/1, "Replaces Berserk", 2 min CD); prior "not in tree" finding was
    --   wrong or predated the finalized tree. Berserk (106951) updated with suppressIfTalent.
    --   Also shares nodeID 82114 with Convoke the Spirits (391528) below — same choice-node pattern
    --   already coded for Guardian's Incarnation/Convoke pair — so mutual suppressIfTalent applied
    --   here too. This part is inferred from the node-ID match, not directly user-confirmed;
    --   verify in-game if this turns out wrong.
    -- Predatory Swiftness (69369) removed from procBuffs — not in talent tree or spell list, VERIFY never confirmed
    -- Frantic Frenzy (1243807) added as talentGated CD — non-PASSIVE ACTIVE nodeID 82111, confirmed spell list
    -- Feral Frenzy (274837) added as talentGated CD — non-PASSIVE ACTIVE nodeID 82112, confirmed spell list
    -- Primal Wrath (285381) added as talentGated rotational — non-PASSIVE ACTIVE nodeID 82120; AoE finisher
    -- Ravage (441583) added as altId on Ferocious Bite — May 2026; Druid of the Claw hero talent PASSIVE proc
    --   Auto-attack proc makes next Ferocious Bite fire as Ravage (441583) instead; counted alongside Ferocious Bite
    --   Archon reported ID 441591 — WRONG; in-game tooltip confirms Spell ID 441583 for both Feral and Guardian
    [2] = {
        name = "Feral", role = "DPS",
        resourceType = 4, resourceLabel = "ENERGY", overcapAt = 100,
        majorCooldowns = {
            { id = 5217,   label = "Tiger's Fury",       expectedUses = "on CD"          },  -- non-PASSIVE ACTIVE nodeID 82124
            { id = 106951, label = "Berserk",             expectedUses = "burst windows",  suppressIfTalent = 102543 },  -- non-PASSIVE ACTIVE nodeID 82101; replaced on the bar when Incarnation: Avatar of Ashamane is talented
            { id = 391528, label = "Convoke the Spirits", expectedUses = "burst windows",  talentGated = true, suppressIfTalent = 102543 },  -- non-PASSIVE ACTIVE nodeID 82114; choice node with Incarnation: Avatar of Ashamane
            { id = 102543, label = "Incarnation: Avatar of Ashamane", expectedUses = "on CD (talent)", talentGated = true, suppressIfTalent = 391528 },  -- nodeID 82114; choice node with Convoke; replaces Berserk on the bar; ADDED 09/06/2026
            { id = 1243807, label = "Frantic Frenzy", expectedUses = "on CD (talent)", talentGated = true, altIds = {1244079} },         -- non-PASSIVE ACTIVE nodeID 82111; replaces Feral Frenzy; altId 1244079 per Archon (May 2026)
            { id = 274837,  label = "Feral Frenzy",  expectedUses = "on CD (talent)", talentGated = true, suppressIfTalent = 1243807 },  -- non-PASSIVE ACTIVE nodeID 82112; suppress when Frantic Frenzy taken (Frantic replaces Feral — IsTalentActive returns true on both)
            { id = 61336,   label = "Survival Instincts", expectedUses = "situational", isUtility = true },  -- confirmed id=61336; reactive personal defensive — tracked but never penalised
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 1079,   label = "Rip",            minFightSeconds = 15 },                      -- non-PASSIVE ACTIVE nodeID 82222
            { id = 1822,   label = "Rake",           minFightSeconds = 15 },                      -- non-PASSIVE ACTIVE nodeID 82199
            { id = 22568,  label = "Ferocious Bite", minFightSeconds = 20, altIds = {441583} },  -- baseline; Ravage (441583) PASSIVE proc fires in place of Ferocious Bite when proc is active
            { id = 5221,   label = "Shred",          minFightSeconds = 15 },                      -- baseline confirmed spell list; primary CP builder
            { id = 285381, label = "Primal Wrath",   minFightSeconds = 20, talentGated = true },  -- non-PASSIVE ACTIVE nodeID 82120; AoE finisher
            { id = 106785, label = "Swipe",          minFightSeconds = 20, talentGated = true },  -- Cat Form Swipe; confirmed combat cast ID 106785 (class talent; Bear Form is 213764)
            { id = 1244258, label = "Chomp",         minFightSeconds = 20, talentGated = true, hasCombatValue = true, isUtility = true },  -- Druid of the Claw hero talent; situational; bonus credit, never penalised
        },
        priorityNotes = {
            "Ferocious Bite on Apex Predator's Craving procs — highest priority",
            "Maintain Rip at 4+ combo points with Tiger's Fury active when possible",
            "Ferocious Bite at 5 CP with Berserk active, 4 CP without",
            "Sync Berserk (or Incarnation: Avatar of Ashamane) and Convoke the Spirits with Tiger's Fury for burst",
            "Tiger's Fury on cooldown — Energy refill and damage buff",
            "Maintain Rake — refresh in pandemic, prioritise Tiger's Fury snapshots",
            "Shred to generate combo points — primary filler",
            "Primal Wrath as AoE finisher when talented — replaces Ferocious Bite on multi-target",
        },
        scoreWeights = { cooldownUsage = 25, procUsage = 15, activity = 35, resourceMgmt = 25 },
        sourceNote = "Midnight 12.0 verified against full Feral talent tree snapshot v1.4.3 114 nodes (April 2026); May 2026 Archon sweep",
    },

    -- Guardian (PASSIVE audit — April 2026; May 2026 Archon sweep)
    -- Maul/Raze (6807) added to rotational — non-PASSIVE ACTIVE nodeID 82127; Rage spender
    --   Note: 6807 shows as "Raze" in Guardian spell list (spec-variant)
    -- Lunar Beam (204066) added to majorCooldowns — non-PASSIVE ACTIVE nodeID 92587
    -- Red Moon: confirmed in Balance spell list only — NOT present in Guardian files, not tracked
    -- Catform spells excluded — Bear form only for Guardian
    -- Ravage (441583) added as altId on Maul — May 2026; Druid of the Claw hero talent PASSIVE proc
    --   Auto-attack proc makes next Maul fire as Ravage (441583); counted alongside Maul; same spell ID as Feral Ravage
    --   Archon reported ID 441605 — WRONG; in-game tooltip confirms Spell ID 441583
    [3] = {
        name = "Guardian", role = "TANK",
        resourceType = 8, resourceLabel = "RAGE", overcapAt = 100,
        majorCooldowns = {
            { id = 102558, label = "Incarnation: Guardian", expectedUses = "on CD", suppressIfTalent = 391528                  },  -- non-PASSIVE ACTIVE nodeID 82136; choice node with Convoke; suppress when Convoke taken
            { id = 50334,  label = "Berserk",               expectedUses = "on CD",          talentGated = true, suppressIfTalent = 102558 },  -- nodeID 82149; replaced by Incarnation — suppress when Incarnation taken
            { id = 61336,  label = "Survival Instincts",    expectedUses = "defensive",      healerConditional = true          },  -- confirmed id=61336; reactive tank defensive — no penalty on successful fight
            { id = 22812,  label = "Barkskin",              expectedUses = "magic damage"                                       },  -- baseline confirmed spell list
            { id = 22842,  label = "Frenzied Regeneration", expectedUses = "low health"                                         },  -- non-PASSIVE ACTIVE nodeID 82220
            { id = 204066, label = "Lunar Beam",            expectedUses = "on CD (talent)", talentGated = true                },  -- non-PASSIVE ACTIVE nodeID 92587
            { id = 391528, label = "Convoke the Spirits",  expectedUses = "burst windows",  talentGated = true, suppressIfTalent = 102558 },  -- nodeID 82136; choice node with Incarnation: Guardian; suppress when Incarnation taken
            { id = 155835, label = "Bristling Fur",        expectedUses = "defensive",      talentGated = true, healerConditional = true },  -- converts Rage generated into Armor for 8s; reactive defensive
        },
        uptimeBuffs = {
            { id = 192081, label = "Ironfur", targetUptime = 70, castSpellId = 192081, buffDuration = 7 },  -- each cast applies a 7s stack
        },
        rotationalSpells = {
            { id = 8921,    label = "Moonfire",  minFightSeconds = 15 },                      -- baseline; rotation priority #1
            { id = 33917,   label = "Mangle",    minFightSeconds = 15 },                      -- baseline; rotation priority #4
            { id = 77758,   label = "Thrash",    minFightSeconds = 15 },                      -- baseline; rotation priority #5
            { id = 6807,    label = "Maul",      minFightSeconds = 20, altIds = {441583, 400254} },  -- non-PASSIVE ACTIVE nodeID 82127; Rage spender; Ravage (441583) PASSIVE proc; 400254=Raze stellar variant per Archon (May 2026)
            { id = 213764,  label = "Swipe",        minFightSeconds = 20 },                      -- non-PASSIVE ACTIVE nodeID 82223; filler only
            { id = 1253799, label = "Sundering Roar", minFightSeconds = 15, talentGated = true },  -- AoE interrupt + damage; added May 2026
            -- Red Moon (1252871) removed — confirmed in Balance spell list only, not Guardian
        },
        tankMetrics = { targetMitigationUptime = 70 },
        priorityNotes = {
            "Maintain Moonfire on your primary target at all times",
            "Keep Ironfur active — spend Rage for 70%+ uptime (tracked via uptimeBuffs)",
            "Mangle on cooldown — primary Rage generator",
            "Thrash on cooldown — maintain 3-5 stacks",
            "Spend Rage on Ironfur defensively or Maul offensively",
            "Lunar Beam on cooldown when talented — healing and damage",
            "Frenzied Regeneration when health dips low — reactive self-heal",
            "Barkskin and Incarnation on cooldown — use as frequently as possible",
            "Swipe as a filler only — never delay Mangle or Thrash for it",
        },
        scoreWeights = { cooldownUsage = 25, mitigationUptime = 40, activity = 20, resourceMgmt = 15 },
        sourceNote = "Midnight 12.0 verified against full Guardian talent tree snapshot v1.4.3 116 nodes (April 2026); May 2026 Archon sweep",
    },

    -- Restoration (PASSIVE audit — April 2026; May 2026 Archon sweep)
    -- Incarnation: Tree of Life (33891) ADDED 09/06/2026 — confirmed active talent via in-game
    --   tooltip (Rank 0/1, situational, 3 min CD); prior "not in tree" finding was wrong or predated
    --   the finalized tree. Shares nodeID 82064 with Convoke the Spirits below — same choice-node
    --   pattern already coded for Guardian's Incarnation/Convoke pair — mutual suppressIfTalent
    --   applied here too, inferred from the node-ID match; verify in-game if this turns out wrong.
    -- Flourish (197721): confirmed PASSIVE 09/06/2026 via in-game tooltip (extends HoT duration
    --   via Tranquility) — not tracked; ID unchanged from what was already recorded.
    -- Wild Growth moved from majorCooldowns to rotational — it's a maintenance spell, not a burst CD
    -- Convoke the Spirits (391528) added as talentGated CD — non-PASSIVE ACTIVE nodeID 82064
    -- Ironbark (102342) added to majorCooldowns — non-PASSIVE ACTIVE nodeID 82082; external defensive
    -- Nature's Swiftness (132158) added to majorCooldowns — non-PASSIVE ACTIVE nodeID 82050; instant cast CD
    -- Lifebloom (33763) added to rotational — non-PASSIVE ACTIVE nodeID 82049; core HoT
    -- Innervate (29166) added to majorCooldowns — non-PASSIVE ACTIVE nodeID 82244; mana CD
    -- Regrowth (8936) added to rotational — May 2026; id=8936 confirmed in-game; 24.3% healing per Archon; baseline cast
    -- Efflorescence (145205) NOT tracked — replaced by Lifetreading (1217941) which is PASSIVE (nodeID 103874);
    --   Lifetreading passively plants Efflorescence beneath the Lifebloom target; neither Efflor nor Lifetreading is cast by player
    -- Grove Guardians — confirmed PASSIVE; not tracked
    [4] = {
        name = "Restoration", role = "HEALER",
        resourceType = 0,
        majorCooldowns = {
            { id = 740,    label = "Tranquility",         expectedUses = "heavy damage windows", healerConditional = true              },  -- non-PASSIVE ACTIVE nodeID 82054
            { id = 102342, label = "Ironbark",            expectedUses = "tank busters",         healerConditional = true              },  -- non-PASSIVE ACTIVE nodeID 82082
            { id = 132158, label = "Nature's Swiftness",  expectedUses = "emergency instant",    healerConditional = true              },  -- non-PASSIVE ACTIVE nodeID 82050
            { id = 29166,  label = "Innervate",           expectedUses = "mana recovery",        healerConditional = true, talentGated = true },  -- non-PASSIVE ACTIVE nodeID 82244
            { id = 391528, label = "Convoke the Spirits", expectedUses = "burst throughput",     healerConditional = true, talentGated = true, suppressIfTalent = 33891 },  -- non-PASSIVE ACTIVE nodeID 82064; choice node with Incarnation: Tree of Life
            { id = 33891,  label = "Incarnation: Tree of Life", expectedUses = "situational", healerConditional = true, talentGated = true, suppressIfTalent = 391528 },  -- nodeID 82064; choice node with Convoke; ADDED 09/06/2026
        },
        rotationalSpells = {
            { id = 774,   label = "Rejuvenation",  minFightSeconds = 20 },  -- non-PASSIVE ACTIVE nodeID 82217
            { id = 8936,  label = "Regrowth",      minFightSeconds = 20 },  -- baseline; id=8936 confirmed in-game (May 2026); 24.3% healing
            { id = 18562, label = "Swiftmend",     minFightSeconds = 20 },  -- non-PASSIVE ACTIVE nodeID 82047
            { id = 33763, label = "Lifebloom",     minFightSeconds = 20 },  -- non-PASSIVE ACTIVE nodeID 82049; core single-target HoT
            { id = 48438, label = "Wild Growth",   minFightSeconds = 30 },  -- non-PASSIVE ACTIVE nodeID 82205; AoE HoT
        },
        healerMetrics = { targetOverheal = 35, targetActivity = 75, targetManaEnd = 15 },
        priorityNotes = {
            "Keep Rejuvenation rolling on injured targets — core HoT foundation",
            "Maintain Lifebloom on the tank — primary single-target HoT",
            "Regrowth for direct single-target healing — primary instant cast",
            "Wild Growth for efficient AoE healing on grouped targets",
            "Swiftmend for emergency instant healing",
            "Nature's Swiftness for an instant cast of any spell in an emergency",
            "Ironbark on the tank for heavy physical damage",
            "Innervate during heavy casting phases to recover mana when talented",
            "Tranquility for heavy sustained raid damage — hold for peak damage",
            "Convoke the Spirits (or Incarnation: Tree of Life) for burst throughput when talented",
        },
        scoreWeights = { cooldownUsage = 25, efficiency = 30, activity = 25, responsiveness = 20 },
        sourceNote = "Midnight 12.0 verified against full Restoration Druid talent tree snapshot v1.4.3 119 nodes (April 2026); May 2026 Archon sweep",
    },
})
