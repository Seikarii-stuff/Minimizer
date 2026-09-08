local Core = MidnightSensei.Core

Core.RegisterSpec(12, {
    className = "Demon Hunter",

    -- Havoc (Midnight 12.0 pass — April 2026)
    -- Verified against full talent tree snapshot v1.4.3 (123 nodes, descriptions)
    -- 162794 (old Chaos Strike ID) removed — not in talent tree
    -- 188499 (old Blade Dance ID) removed — not in talent tree
    -- 344862 removed from Havoc — this is Devourer's Reap ID, not a Havoc spell
    -- Blade Dance: correct ID is 188499 confirmed via spell snapshot — WAIT, 188499
    --   not in tree either. Blade Dance must be baseline. Retained as baseline spell.
    -- Chaos Strike added to rotational — primary Fury spender; confirmed IDs: 222031 (primary),
    --   162794 and 199547 (alt IDs), 201428 Annihilation (Meta variant); all fire UNIT_SPELLCAST_SUCCEEDED
    -- Disrupt (183752) added to majorCooldowns as isInterrupt — melee interrupt; tracked, never penalised
    -- Glaive Tempest confirmed PASSIVE — not tracked
    -- Sigil of Misery (207684) added as isInterrupt — non-PASSIVE ACTIVE
    -- Chaos Nova (179057) added as talentGated CD — non-PASSIVE ACTIVE
    -- Felblade (232893) already in rotational — confirmed non-PASSIVE ACTIVE nodeID 91008
    -- Essence Break (258860) already in rotational — confirmed non-PASSIVE ACTIVE nodeID 91033
    [1] = {
        name = "Havoc", role = "DPS",
        resourceType = 17, resourceLabel = "FURY", overcapAt = 100,
        validSpells = {
            [191427]=true,  -- Metamorphosis
            [198013]=true,  -- Eye Beam
            [370965]=true,  -- The Hunt
            [1246167]=true, -- The Hunt (spec-variant confirmed spell snapshot)
            [188499]=true,  -- Blade Dance (baseline — not in talent tree but in spellbook)
            -- 344862 removed — Devourer's Reap ID, not a Havoc ability
            -- 162794 removed — old Chaos Strike ID, not in tree
            [258920]=true,  -- Immolation Aura
            [188501]=true,  -- Spectral Sight
            [198793]=true,  -- Vengeful Retreat
            [179057]=true,  -- Chaos Nova (non-PASSIVE nodeID 90993)
            [232893]=true,  -- Felblade (non-PASSIVE nodeID 91008)
            [258860]=true,  -- Essence Break (non-PASSIVE nodeID 91033)
            [344865]=true,  -- Fel Rush (confirmed spell snapshot)
            [185164]=true,  -- Mastery: Demonic Presence
            [255260]=true,  -- Chaos Brand
            [278326]=true,  -- Consume Magic
            [196718]=true,  -- Darkness
            [183752]=true,  -- Disrupt
            [196055]=true,  -- Double Jump
            [131347]=true,  -- Glide
            [217832]=true,  -- Imprison
            [207684]=true,  -- Sigil of Misery
            [185123]=true,  -- Throw Glaive
            [185245]=true,  -- Torment
            [337567]=true,  -- Furious Gaze proc
            [343311]=true,  -- Furious Gaze proc (Archon alt ID)
            [389860]=true,  -- Unbound Chaos proc
            [347461]=true,  -- Unbound Chaos proc (Archon alt ID)
        },
        majorCooldowns = {
            { id = 191427, label = "Metamorphosis", expectedUses = "burst windows"           },  -- non-PASSIVE confirmed
            { id = 198013, label = "Eye Beam",      expectedUses = "on CD"                  },  -- non-PASSIVE nodeID 91018
            { id = 370965, label = "The Hunt",      expectedUses = "on CD (talent)", talentGated = true },  -- non-PASSIVE nodeID 90921
            { id = 179057, label = "Chaos Nova",    expectedUses = "situational",    talentGated = true, isUtility = true, hasCombatValue = true },  -- non-PASSIVE nodeID 90993; AoE stun + damage — situational hold, never penalised
            { id = 207684, label = "Sigil of Misery", expectedUses = "situational",   isInterrupt = true },  -- non-PASSIVE ACTIVE; fear CC
            { id = 183752, label = "Disrupt",          expectedUses = "situational",   isInterrupt = true },  -- melee interrupt; tracked, never penalised
        },
        rotationalSpells = {
            { id = 222031, label = "Chaos Strike",    minFightSeconds = 15, altIds = {162794, 199547, 201428} },  -- primary Fury spender; 201428=Annihilation (Meta variant)
            { id = 188499, label = "Blade Dance",     minFightSeconds = 15 },                                     -- baseline confirmed spellbook
            { id = 258920, label = "Immolation Aura", minFightSeconds = 15 },                                     -- baseline confirmed spellbook
            { id = 258860, label = "Essence Break",   minFightSeconds = 20, talentGated = true },                 -- non-PASSIVE ACTIVE nodeID 91033
            { id = 232893, label = "Felblade",        minFightSeconds = 15, talentGated = true },                 -- non-PASSIVE ACTIVE nodeID 91008
        },
        procBuffs = {
            { id = 337567, label = "Furious Gaze",  maxStackTime = 8,  altIds = {343311} },   -- VERIFY C_UnitAuras
            { id = 389860, label = "Unbound Chaos", maxStackTime = 12, altIds = {347461} },   -- VERIFY C_UnitAuras
        },
        priorityNotes = {
            "Immolation Aura on cooldown — primary Fury generator",
            "Eye Beam on cooldown — core damage and Fury dump",
            "Blade Dance on cooldown — highest priority spender",
            "Essence Break before Chaos Strike when talented — amplifies damage",
            "Chaos Strike to spend Fury — primary filler; becomes Annihilation during Metamorphosis",
            "Metamorphosis for burst — align with trinkets and lust",
            "Chaos Nova on cooldown when talented",
        },
        scoreWeights = { cooldownUsage = 30, procUsage = 20, activity = 30, resourceMgmt = 20 },
        sourceNote = "Midnight 12.0 verified against full Havoc talent tree snapshot v1.4.3 123 nodes (April 2026)",
    },

    -- Vengeance (Midnight 12.0 pass — April 2026)
    -- Verified against v1.4.3 talent snapshot (108 nodes, descriptions)
    -- 191427 Metamorphosis removed from majorCooldowns — shapeshifting, fires UPDATE_SHAPESHIFT_FORM not SUCCEEDED
    -- 344862 removed — Devourer's Reap ID; wrong for Vengeance
    -- 344859 Fracture removed from rotational — confirmed not in Vengeance talent tree
    -- 203720 Demon Spikes: ID not in talent tree as non-PASSIVE — VERIFY aura ID for uptimeBuffs
    -- Sigil of Silence (202137) added as isInterrupt — non-PASSIVE ACTIVE
    -- Sigil of Misery (207684) added as isInterrupt — non-PASSIVE ACTIVE
    -- Chaos Nova (179057) added as talentGated CD — non-PASSIVE ACTIVE
    -- Felblade (232893) already in rotational — confirmed ✓
    -- Spirit Bomb (247454) already in rotational — confirmed ✓
    -- Sigil of Spite (390163) already in majorCooldowns — confirmed ✓
    -- Soul Cleave added to rotational — confirmed IDs: 228477 (primary), 228478 (altId)
    -- Perfectly Balanced Glaive confirmed PASSIVE — not tracked
    -- Quickened Sigils confirmed PASSIVE — not tracked
    [2] = {
        name = "Vengeance", role = "TANK",
        resourceType = 17, resourceLabel = "FURY", overcapAt = 100,
        validSpells = {
            -- 191427 Metamorphosis removed — shapeshifting, not trackable via SUCCEEDED
            [204021]=true,  -- Fiery Brand (confirmed spell snapshot)
            [212084]=true,  -- Fel Devastation (confirmed spell snapshot)
            [203720]=true,  -- Demon Spikes (confirmed spell snapshot)
            [258920]=true,  -- Immolation Aura
            -- 344862 removed — Devourer's Reap ID, wrong for Vengeance
            -- 344859 removed — not in Vengeance talent tree
            [247454]=true,  -- Spirit Bomb (confirmed spell snapshot)
            [225919]=true,  -- Fracture (variant 1)
            [263642]=true,  -- Fracture (variant 2)
            [225921]=true,  -- Fracture (variant 3)
            [189110]=true,  -- Infernal Strike
            [213243]=true,  -- Felblade (spec-variant ID)
            [278386]=true,  -- Demonic Wards
            [206478]=true,  -- Demonic Appetite
            [255260]=true,  -- Chaos Brand
            [278326]=true,  -- Consume Magic
            [196718]=true,  -- Darkness
            [183752]=true,  -- Disrupt
            [196055]=true,  -- Double Jump
            [131347]=true,  -- Glide
            [217832]=true,  -- Imprison
            [207684]=true,  -- Sigil of Misery
            [202137]=true,  -- Sigil of Silence
            [185123]=true,  -- Throw Glaive
            [185245]=true,  -- Torment
            [390163]=true,  -- Sigil of Spite
            [179057]=true,  -- Chaos Nova
            [232893]=true,  -- Felblade
            [202138]=true,  -- Sigil of Chains
            [207407]=true,  -- Soul Carver
            [204596]=true,  -- Sigil of Flame
        },
        majorCooldowns = {
            -- 191427 Metamorphosis removed — shapeshifting spell, UPDATE_SHAPESHIFT_FORM not SUCCEEDED
            { id = 204021, label = "Fiery Brand",      expectedUses = "tank busters"              },  -- non-PASSIVE ACTIVE nodeID 90951
            { id = 212084, label = "Fel Devastation",  expectedUses = "on CD"                     },  -- non-PASSIVE ACTIVE nodeID 90991
            { id = 203720, label = "Demon Spikes",     expectedUses = "on CD — physical mitigation" },  -- confirmed pressed spell; aura also tracked in uptimeBuffs
            { id = 390163, label = "Sigil of Spite",   expectedUses = "on CD (talent)", talentGated = true },  -- non-PASSIVE ACTIVE nodeID 90978
            { id = 179057, label = "Chaos Nova",       expectedUses = "situational",    talentGated = true, isUtility = true, hasCombatValue = true },  -- non-PASSIVE ACTIVE; AoE stun + damage — situational hold, never penalised
            { id = 202137, label = "Sigil of Silence", expectedUses = "situational",    isInterrupt = true },  -- non-PASSIVE ACTIVE
            { id = 207684, label = "Sigil of Misery",  expectedUses = "situational",    isInterrupt = true, suppressIfTalent = 202138 },  -- non-PASSIVE ACTIVE; suppressed when Sigil of Chains taken
            { id = 202138, label = "Sigil of Chains",  expectedUses = "situational",    isUtility = true, talentGated = true },  -- choice node; root CC; suppress Sigil of Misery when taken
        },
        uptimeBuffs = {
            { id = 203720, label = "Demon Spikes", targetUptime = 50, castSpellId = 203720, buffDuration = 6 },  -- each cast applies/extends for 6s
        },
        rotationalSpells = {
            { id = 258920, label = "Immolation Aura", minFightSeconds = 15 },                                          -- live-verified x5; primary Fury generator
            { id = 228477, label = "Soul Cleave",     minFightSeconds = 15, altIds = {228478} },                       -- confirmed IDs: 228477 primary, 228478 alt; core Fury spender
            { id = 225919, label = "Fracture",        minFightSeconds = 15, altIds = {263642, 225921} },               -- live-verified x15; multiple variant IDs all credit this entry
            { id = 247454, label = "Spirit Bomb",     minFightSeconds = 20 },                                          -- non-PASSIVE ACTIVE nodeID 90990
            { id = 189110, label = "Infernal Strike",  minFightSeconds = 15 },                                         -- live-verified x5; gap-closer with charges
            { id = 232893, label = "Felblade",        minFightSeconds = 15, talentGated = true, altIds = {213243} },   -- non-PASSIVE ACTIVE nodeID 108722; 213243 is spec-variant ID
            { id = 207407, label = "Soul Carver",     minFightSeconds = 20, talentGated = true },                         -- burst damage + Soul Fragment generation
            { id = 204596, label = "Sigil of Flame",  minFightSeconds = 15 },                                            -- 30s CD; Fire damage DoT + 25 Fury; use on CD
        },
        tankMetrics = { targetMitigationUptime = 50 },
        priorityNotes = {
            "Maintain Demon Spikes for physical mitigation",
            "Immolation Aura on cooldown for Fury and damage",
            "Soul Cleave to spend Fury — use when below 4 Soul Fragments for Spirit Bomb",
            "Spirit Bomb with 4-5 Soul Fragments for healing and damage",
            "Fiery Brand for magic damage or tank busters",
            "Fel Devastation on cooldown for sustained damage and healing",
            "Sigil of Spite on cooldown when talented",
            "Chaos Nova on cooldown when talented",
        },
        scoreWeights = { cooldownUsage = 30, mitigationUptime = 35, activity = 20, resourceMgmt = 15 },
        sourceNote = "Midnight 12.0 verified against full Vengeance talent tree snapshot v1.4.3 108 nodes (April 2026)",
    },

    -- Devourer (Midnight 12.0 Archon audit — May 2026; /ms verify confirmed April 2026 — all cast IDs live-verified)
    -- Feast of Souls (1237270) confirmed PASSIVE nodeID 107343 — not tracked
    -- Spell IDs confirmed via UNIT_SPELLCAST_SUCCEEDED (/ms verify report):
    --   Consume:          473662  (was 344859 — snapshot ID was damage event ID, not cast ID)
    --   Reap:             1226019 (was 344862 — same issue)
    --   Void Metamorphosis: 1217605 (was 191427 — Havoc Meta ID; Devourer uses separate ID)
    --   Devour:           1217610 — new; fired 6x, untracked previously
    --   Cull:             1245453 — new; fired 5x, untracked previously
    --   Void Ray:         473728  ✓ confirmed
    --   Collapsing Star:  1221150 ✓ confirmed (CHANNEL_START)
    --   Soul Immolation:  1241937 ✓ confirmed; suppressIfTalent removed — Spontaneous Immolation redesigned to buff rather than replace
    --   The Hunt:         1246167 ✓ confirmed (SKIP — talent not taken, expected)
    -- PASSIVE — removed: Impending Apocalypse (1227707), Demonsurge (452402), Midnight (1250094)
    -- PASSIVE — removed from rotational: Eradicate (1226033)
    [3] = {
        name = "Devourer", role = "DPS",
        resourceType = 17, resourceLabel = "FURY", overcapAt = 100,
        -- Strict whitelist — hard-blocks all Havoc/Vengeance abilities
        validSpells = {
            [1217605]=true, -- Void Metamorphosis — Devourer cast ID (live-verified)
            [471306]=true,  -- Void Metamorphosis (Archon alt ID)
            [1221150]=true, -- Collapsing Star (live-verified CHANNEL_START)
            [1221167]=true, -- Collapsing Star (Archon alt ID)
            [473662]=true,  -- Consume (live-verified cast ID)
            [1226019]=true, -- Reap (live-verified cast ID)
            [1217610]=true, -- Devour (live-verified)
            [1245453]=true, -- Cull (live-verified)
            [344865]=true,  -- Shift (confirmed spell snapshot)
            [473728]=true,  -- Void Ray (live-verified)
            [1245412]=true, -- Voidblade (non-PASSIVE ACTIVE nodeID 108723)
            [1234195]=true, -- Void Nova (non-PASSIVE ACTIVE nodeID 107347)
            [1241937]=true, -- Soul Immolation (live-verified)
            [1246167]=true, -- The Hunt Devourer spec-variant (non-PASSIVE ACTIVE)
            -- 1227707 Impending Apocalypse removed — PASSIVE
            -- 1226033 Eradicate removed — PASSIVE INACTIVE
            -- 1250094 Midnight removed — PASSIVE INACTIVE
            -- 452402  Demonsurge removed — PASSIVE
            [1260008]=true, -- Grim Focus (confirmed spell snapshot)
            [198589]=true,  -- Blur
            [1238855]=true, -- Mastery: Monster Within
            [1227619]=true, -- Shattered Souls
            [255260]=true,  -- Chaos Brand
            [278326]=true,  -- Consume Magic (non-PASSIVE ACTIVE nodeID 91006)
            [196718]=true,  -- Darkness (non-PASSIVE ACTIVE nodeID 91002)
            [183752]=true,  -- Disrupt
            [196055]=true,  -- Double Jump
            [131347]=true,  -- Glide
            [217832]=true,  -- Imprison (non-PASSIVE ACTIVE nodeID 91007)
            [207684]=true,  -- Sigil of Misery (non-PASSIVE ACTIVE nodeID 90946)
            [185123]=true,  -- Throw Glaive
            [185245]=true,  -- Torment
        },
        majorCooldowns = {
            { id = 1217605, label = "Void Metamorphosis", expectedUses = "on CD — required for Collapsing Star",
              displayOnly = true, altIds = {471306} },  -- shapeshift: fires UPDATE_SHAPESHIFT_FORM not SUCCEEDED; displayOnly for My Spell List
            { id = 1246167, label = "The Hunt",       expectedUses = "on CD (talent)", talentGated = true },  -- Devourer spec-variant; live-verified SKIP (not talented)
            { id = 183752,  label = "Disrupt",        expectedUses = "situational",    isInterrupt = true },  -- melee interrupt; primary and only interrupt
            { id = 278326,  label = "Consume Magic",  expectedUses = "situational",    isUtility = true, talentGated = true },  -- nodeID 91006; purge — situational utility, not an interrupt
            -- Removed (confirmed PASSIVE): Impending Apocalypse 1227707, Demonsurge 452402, Midnight 1250094
        },
        rotationalSpells = {
            { id = 473662,  label = "Consume",         minFightSeconds = 15 },                     -- live-verified cast ID; core builder
            { id = 1226019, label = "Reap",            minFightSeconds = 15 },                     -- live-verified cast ID; core spender
            { id = 1241937, label = "Soul Immolation", minFightSeconds = 15, talentGated = true },  -- CD resets on kill; Spontaneous Immolation redesigned to buff not replace
            { id = 1217610, label = "Devour",          minFightSeconds = 15, combatGated = true },  -- live-verified cast ID; inside Void Metamorphosis window
            { id = 1245453, label = "Cull",            minFightSeconds = 15, combatGated = true },  -- live-verified cast ID; inside Void Metamorphosis window
            { id = 1221150, label = "Collapsing Star", minFightSeconds = 45, combatGated = true, altIds = {1221167} },  -- live-verified CHANNEL_START; inside Void Metamorphosis window
            { id = 473728,  label = "Void Ray",        minFightSeconds = 15 },                     -- live-verified; non-PASSIVE ACTIVE nodeID 107336
            { id = 1245412, label = "Voidblade",       minFightSeconds = 15, talentGated = true },  -- non-PASSIVE ACTIVE nodeID 108723
            { id = 1234195, label = "Void Nova",       minFightSeconds = 20, talentGated = true },  -- non-PASSIVE ACTIVE nodeID 107347
        },
        priorityNotes = {
            "Consume to build Soul Fragments and generate Fury — primary builder",
            "Reap to spend resources and deal damage — primary spender",
            "Devour and Cull on cooldown — core rotational damage",
            "Build Soul Fragments to trigger Void Metamorphosis windows",
            "Use Collapsing Star inside Void Metamorphosis for maximum damage",
            "Void Ray to generate Souls and Fury outside Void Metamorphosis",
            "Voidblade as Fury spender when talented — use on cooldown",
            "Void Nova for burst AoE inside Void Metamorphosis when talented",
            "The Hunt on cooldown when talented — Devourer spec-variant",
            "Soul Immolation on cooldown when talented and Spontaneous Immolation is NOT taken",
            "Pool Fury before entering Void Metamorphosis for burst spending",
        },
        scoreWeights = { cooldownUsage = 25, activity = 40, resourceMgmt = 20, procUsage = 15 },
        sourceNote = "Midnight 12.0 verified against full Devourer talent tree snapshot v1.4.3 112 nodes (April 2026)",
    },
})
