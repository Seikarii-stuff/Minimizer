local Core = MidnightSensei.Core

Core.RegisterSpec(2, {
    className = "Paladin",

    -- Holy (Midnight 12.0 PASSIVE audit — April 2026)
    -- Beacon of Light (53563) removed from uptimeBuffs — applied to target, not a self-aura
    -- Blessing of Sacrifice (6940) nodeID 81614 INACTIVE in this build — talentGated
    -- Aura Mastery (31821) added to majorCooldowns — nodeID 81567 non-PASSIVE ACTIVE
    -- Lay on Hands (633) added to majorCooldowns — nodeID 81597 non-PASSIVE ACTIVE
    -- Holy Bulwark (432459) added to majorCooldowns — nodeID 110257 non-PASSIVE ACTIVE
    -- Light of Dawn (85222) added to rotational — nodeID 81565 non-PASSIVE ACTIVE; AoE HP spender
    -- Blessing of Freedom (1044) added to majorCooldowns as isUtility — nodeID 81631; 25s CD; talentGated; 100% adoption
    -- Fist of Justice confirmed PASSIVE — not tracked
    -- Beacon of Faith (156910) added as healerConditional talentGated — nodeID 81554; choice node with Beacon of Virtue; suppressIfTalent=200025
    -- Beacon of Virtue (200025) added as healerConditional talentGated — nodeID 81554; Replaces Beacon of Light; 15s CD; suppressIfTalent=156910
    [1] = {
        name = "Holy", role = "HEALER",
        resourceType = 9, resourceLabel = "HOLY POWER", overcapAt = 5,
        majorCooldowns = {
            { id = 31884,  label = "Avenging Wrath",        expectedUses = "burst phases",        talentGated = true                            },  -- confirmed spell list; class talent
            { id = 375576, label = "Divine Toll",           expectedUses = "on CD",               talentGated = true                            },  -- confirmed spell list; class talent
            { id = 31821,  label = "Aura Mastery",          expectedUses = "heavy magic damage",  healerConditional = true                      },  -- nodeID 81567 non-PASSIVE ACTIVE
            { id = 86659,  label = "Guardian of Anc. Kings",expectedUses = "emergency throughput",healerConditional = true                      },  -- confirmed spell list
            { id = 633,    label = "Lay on Hands",          expectedUses = "emergencies",         healerConditional = true                      },  -- nodeID 81597 non-PASSIVE ACTIVE
            { id = 432459, label = "Holy Bulwark",          expectedUses = "on CD"                                                              },  -- nodeID 110257 non-PASSIVE ACTIVE
            { id = 156322, label = "Eternal Flame",         expectedUses = "on CD (talent)",      talentGated = true, healerConditional = true    },  -- HP spender that applies a HoT; choice node with Word of Glory
            { id = 216331, label = "Avenging Crusader",     expectedUses = "burst phases",        talentGated = true                              },  -- heals on damage dealt; choice node with Avenging Wrath
            { id = 6940,   label = "Blessing of Sacrifice", expectedUses = "tank busters",        healerConditional = true, talentGated = true   },  -- nodeID 81614 INACTIVE this build
            { id = 1044,   label = "Blessing of Freedom",  expectedUses = "situational",          isUtility = true,         talentGated = true   },  -- nodeID 81631; 25s CD; movement freedom for ally; tracked, never penalised
            { id = 156910, label = "Beacon of Faith",      expectedUses = "per-fight application", healerConditional = true, talentGated = true, suppressIfTalent = 200025 },  -- nodeID 81554; choice node with Beacon of Virtue; apply to second beacon target
            { id = 200025, label = "Beacon of Virtue",     expectedUses = "on CD (talent)",        healerConditional = true, talentGated = true, suppressIfTalent = 156910 },  -- nodeID 81554; Replaces Beacon of Light; 15s CD; choice node with Beacon of Faith
        },
        uptimeBuffs = {},
        rotationalSpells = {
            { id = 20473, label = "Holy Shock",    minFightSeconds = 15 },  -- nodeID 81555 non-PASSIVE ACTIVE; primary HP generator
            { id = 85673, label = "Word of Glory", minFightSeconds = 20 },  -- confirmed spell list; ST HP spender
            { id = 85222,   label = "Light of Dawn",    minFightSeconds = 20 },  -- nodeID 81565 non-PASSIVE ACTIVE; AoE HP spender
            { id = 1241413, label = "Hammer of Wrath",  minFightSeconds = 20, talentGated = true, altIds = {1241288} },  -- added 05/06/2026; same ID as Prot/Ret
        },
        healerMetrics = { targetOverheal = 25, targetActivity = 85, targetManaEnd = 10 },
        priorityNotes = {
            "Holy Shock on cooldown — primary Holy Power generator and heal",
            "Word of Glory and Light of Dawn to spend Holy Power — never overcap at 5",
            "Divine Toll on cooldown — generates 5 Holy Power and AoE heals",
            "Avenging Wrath during burst damage phases",
            "Aura Mastery for heavy magic damage — covers raid with Devotion Aura",
            "Lay on Hands as an emergency — do not hold it when someone will die",
        },
        scoreWeights = { cooldownUsage = 25, efficiency = 30, activity = 25, responsiveness = 20 },
        sourceNote = "Midnight 12.0 verified against full Holy talent tree 103 nodes (April 2026)",
    },

    -- Protection (Midnight 12.0 PASSIVE audit — April 2026)
    -- Avenging Wrath (31884) added to majorCooldowns — nodeID 81483 non-PASSIVE ACTIVE
    -- Divine Toll (375576) added to majorCooldowns — nodeID 110006 non-PASSIVE ACTIVE
    -- Rebuke (96231) added as isInterrupt — nodeID 81604 non-PASSIVE ACTIVE
    -- Shield of the Righteous uptimeBuff: 132403 (old aura ID) → VERIFY; spell list shows 53600/415091
    -- Crusader Strike label corrected: 35395 shows as "Blessed Hammer" in Prot spell list (spec-variant)
    -- Consecration (26573) added to rotational — confirmed spell list baseline
    -- Holy Shock (20473) removed from rotational — NOT SEEN in combat; not part of Prot active rotation
    -- Blessed Hammer altIds={204019} — combat cast fires 204019, spellbook ID 35395
    -- Judgment (275779) added to rotational — session log x33; confirmed Prot HP generator
    -- Hammer of Wrath (1241413) added to rotational — session log x19; talentGated, available in execute/AW window
    -- Word of Glory (85673) added to rotational — session log x2; talentGated HP spender heal
    -- Templar Hero Spec: Hammer of Light (427453) isUtility — proc window 20s after Divine Toll via Light's Guidance (nodeID 95180); player-pressed when available; x6 per fight
    -- Templar Hero Spec: Divine Hammer (198137) isUtility — passive proc summoned by Divine Toll via Divine Hammer talent (nodeID 109747); not player-pressed; x20 per fight
    -- Blessing of Sacrifice (6940) added to majorCooldowns as healerConditional — nodeID 81614; 2 min CD; 99.7% adoption; treat like external tank CD
    -- Lay on Hands (633) added to majorCooldowns as healerConditional — nodeID 81597; 7 min CD; baseline (granted for free); no penalty on successful fight
    -- Final Stand (204077) confirmed PASSIVE nodeID 81504 — not tracked
    [2] = {
        name = "Protection", role = "TANK",
        resourceType = 9, resourceLabel = "HOLY POWER", overcapAt = 5,
        majorCooldowns = {
            { id = 31850,  label = "Ardent Defender",        expectedUses = "dangerous windows"   },  -- nodeID 81481 non-PASSIVE ACTIVE
            { id = 86659,  label = "Guardian of Anc. Kings", expectedUses = "emergency"           },  -- nodeID 81490 non-PASSIVE ACTIVE
            { id = 31935,  label = "Avenger's Shield",       expectedUses = "on CD"               },  -- nodeID 81502 non-PASSIVE ACTIVE
            { id = 31884,  label = "Avenging Wrath",         expectedUses = "on CD",              talentGated = true },  -- nodeID 81483; class talent
            { id = 375576, label = "Divine Toll",            expectedUses = "on CD",              talentGated = true },  -- nodeID 110006; class talent
            { id = 96231,  label = "Rebuke",                 expectedUses = "situational",  isInterrupt = true              },  -- nodeID 81604 non-PASSIVE ACTIVE
            { id = 6940,   label = "Blessing of Sacrifice",  expectedUses = "tank busters", healerConditional = true, talentGated = true },  -- nodeID 81614; 2 min CD; 99.7% adoption; no penalty on successful fight
            { id = 633,    label = "Lay on Hands",           expectedUses = "emergencies",  healerConditional = true              },  -- nodeID 81597; 7 min CD; baseline (granted for free); no penalty on successful fight
            { id = 389539, label = "Sentinel",               expectedUses = "situational",  healerConditional = true, talentGated = true },  -- defensive CD at 100% adoption; added 05/06/2026
            { id = 156322, label = "Eternal Flame",          expectedUses = "on CD (talent)", talentGated = true, healerConditional = true },  -- HP spender HoT; self-sustain for tank
            { id = 204018, label = "Blessing of Spellwarding", expectedUses = "situational",  talentGated = true, isUtility = true, healerConditional = true },  -- magic immunity for ally; Blessing of Protection replacement
        },
        uptimeBuffs = {
            { id = 132403, label = "Shield of the Righteous", targetUptime = 50, castSpellId = 53600, buffDuration = 4.5 },  -- cast 53600 applies buff 132403 for 4.5s
        },
        rotationalSpells = {
            { id = 53600,   label = "Shield of the Righteous", minFightSeconds = 15 },  -- confirmed spell list; HP spender + mitigation
            { id = 35395,   label = "Blessed Hammer",          minFightSeconds = 15,  altIds = {204019} },  -- combat cast fires 204019; spellbook ID 35395
            { id = 26573,   label = "Consecration",            minFightSeconds = 15 },  -- confirmed spell list baseline; AoE damage and ground effect
            { id = 275779,  label = "Judgment",                minFightSeconds = 15 },  -- HP generator; x33 per fight in session log
            { id = 1241413, label = "Hammer of Wrath",         minFightSeconds = 30,  talentGated = true, altIds = {1241288} },  -- execute/AW window; 1241288 = morphed form when Judgment is empowered by Avenging Wrath
            { id = 85673,   label = "Word of Glory",           minFightSeconds = 30,  talentGated = true },  -- HP spender heal; x2 per fight in session log
            { id = 53595,   label = "Hammer of the Righteous", minFightSeconds = 15,  talentGated = true, isUtility = true },  -- AoE HP generator; tracked, never penalised
            { id = 427453,  label = "Hammer of Light",          isUtility = true,      talentGated = true },  -- Templar: 20s window after Divine Toll (Light's Guidance); player-pressed when available
            { id = 198137,  label = "Divine Hammer",            isUtility = true,      talentGated = true, altIds = {432929} },  -- Templar: passive proc summoned by Divine Toll (Divine Hammer talent); not player-pressed
        },
        tankMetrics = { targetMitigationUptime = 50 },
        priorityNotes = {
            "Shield of the Righteous to spend Holy Power — core mitigation (tracked via uptimeBuffs)",
            "Avenger's Shield on cooldown — primary damage and threat",
            "Blessed Hammer on cooldown — Holy Power generator (combat cast ID 204019)",
            "Judgment on cooldown — Holy Power generator",
            "Consecration on cooldown — AoE threat and damage",
            "Hammer of Wrath during execute phase or Avenging Wrath window",
            "Word of Glory for emergency self-healing (talent)",
            "Avenging Wrath and Divine Toll on cooldown for burst",
            "Ardent Defender and Guardian of Ancient Kings for heavy damage windows",
            "Blessing of Sacrifice on a target taking heavy damage — 30% damage reduction",
            "Lay on Hands as a last resort — 7 min CD emergency full heal",
        },
        scoreWeights = { cooldownUsage = 30, mitigationUptime = 35, activity = 20, resourceMgmt = 15 },
        sourceNote = "Midnight 12.0 verified against full Protection Paladin talent tree snapshot v1.4.3 114 nodes (April 2026); May 2026 second-pass",
    },

    -- Retribution (Midnight 12.0 PASSIVE audit + rotation guide — April 2026)
    -- Crusade (231895) removed — not in Ret talent tree or spell list;
    --   1253598 Crusade is PASSIVE nodeID 109369 (modifies Avenging Wrath, not castable separately)
    -- Avenging Wrath (31884) confirmed nodeID 81544 non-PASSIVE ACTIVE; suppressIfTalent=458359 (Radiant Glory) — WoA auto-triggers it when talented
    -- Wake of Ashes (255937) confirmed nodeID 81525 non-PASSIVE ACTIVE
    -- Execution Sentence (343527) confirmed nodeID 109373 non-PASSIVE INACTIVE — talentGated
    -- Divine Toll (375576) added to majorCooldowns — nodeID 109368 non-PASSIVE ACTIVE
    -- Rebuke (96231) added as isInterrupt — nodeID 110093 non-PASSIVE ACTIVE
    -- Templar's Verdict (85256) corrected → Final Verdict (383328) — 85256 shows as "Final Verdict"
    --   in Ret spell list (spec-variant rename in Midnight 12.0); nodeID 81532 non-PASSIVE ACTIVE
    -- Blade of Justice (184575) added to rotational — nodeID 81526 non-PASSIVE ACTIVE; rotation priority #8/10
    -- Divine Storm (53385) moved to majorCooldowns isUtility — AoE only; penalising single-target fights was wrong
    -- Judgment (20271) confirmed spell list ✅
    -- Art of War (406064) PASSIVE nodeID 81523 — procs reset Blade of Justice; tracked as procBuff (VERIFY)
    -- Hammer of Light (427453) added to majorCooldowns as isUtility — Light's Guidance nodeID 95180; 20s proc window after Wake of Ashes; Templar hero path (99.6%)
    -- Wake of Ashes (255937) confirmed firing UNIT_SPELLCAST_SUCCEEDED — remains tracked; triggers HoL window
    -- Crusading Strikes confirmed PASSIVE — not tracked
    [3] = {
        name = "Retribution", role = "DPS",
        resourceType = 9, resourceLabel = "HOLY POWER", overcapAt = 5,
        majorCooldowns = {
            { id = 31884,  label = "Avenging Wrath",     expectedUses = "on CD",              talentGated = true, suppressIfTalent = 458359 },  -- nodeID 81544; suppressed when Radiant Glory (458359) is talented — WoA auto-triggers it, not player-cast
            { id = 255937, label = "Wake of Ashes",      expectedUses = "at 0 HP / burst windows"  },  -- nodeID 81525 non-PASSIVE ACTIVE; rotation priority #6; generates 3 HP
            { id = 375576, label = "Divine Toll",         expectedUses = "on CD",              talentGated = true },  -- nodeID 109368; class talent; rotation priority #7
            { id = 343527, label = "Execution Sentence", expectedUses = "on CD (talent)",  talentGated = true },  -- nodeID 109373 non-PASSIVE INACTIVE
            { id = 156322, label = "Eternal Flame",      expectedUses = "on CD (talent)",  talentGated = true, healerConditional = true },  -- HP spender HoT; choice node with Final Verdict
            { id = 96231,  label = "Rebuke",             expectedUses = "situational",     isInterrupt = true },  -- nodeID 110093 non-PASSIVE ACTIVE
            { id = 53385,  label = "Divine Storm",       expectedUses = "AoE only",        isUtility = true              },  -- nodeID 81527; AoE HP spender — moved from rotational; never penalise in ST
            { id = 427453, label = "Hammer of Light",   expectedUses = "after Wake of Ashes", isUtility = true, talentGated = true },  -- Light's Guidance nodeID 95180; 20s window after Wake of Ashes; Templar (99.6%); tracked, never penalised
            -- Crusade (231895) removed — not in talent tree; 1253598 is a PASSIVE modifier
        },
        rotationalSpells = {
            { id = 383328, label = "Final Verdict",  minFightSeconds = 15 },  -- nodeID 81532 non-PASSIVE ACTIVE; primary 5 HP spender (was 85256 Templar's Verdict — Midnight 12.0 rename)
            { id = 20271,  label = "Judgment",       minFightSeconds = 15 },  -- confirmed spell list; rotation priority #12
            { id = 184575,  label = "Blade of Justice",  minFightSeconds = 15 },  -- nodeID 81526 non-PASSIVE ACTIVE; rotation priority #8/10
            { id = 1241413, label = "Hammer of Wrath",   minFightSeconds = 20, talentGated = true, altIds = {1241288} },  -- execute/AW window; added 05/06/2026; same ID as Prot
            -- Divine Storm moved to majorCooldowns as isUtility — AoE only, not a ST rotational spell
        },
        procBuffs = {
            { id = 406064, label = "Art of War", maxStackTime = 10 },  -- PASSIVE nodeID 81523; procs reset Blade of Justice; verified C_UnitAuras (May 2026)
        },
        priorityNotes = {
            "Avenging Wrath on cooldown — primary burst window, priority #1",
            "Execution Sentence on cooldown when talented — high priority during Avenging Wrath",
            "Build to 5 Holy Power before spending with Final Verdict — never overcap",
            "Wake of Ashes at 0 Holy Power or during burst — generates 3 Holy Power",
            "Divine Toll on cooldown — Holy Power and damage",
            "Blade of Justice on cooldown — spend Art of War procs immediately",
            "Judgment on cooldown — Holy Power generator",
            "Divine Storm as AoE finisher at 5 Holy Power",
            "Hammer of Light during the 20s window after Wake of Ashes (Templar)",
        },
        scoreWeights = { cooldownUsage = 35, activity = 30, resourceMgmt = 25, procUsage = 10 },
        sourceNote = "Midnight 12.0 verified against full Retribution talent tree snapshot v1.4.3 107 nodes (April 2026)",
    },
})
