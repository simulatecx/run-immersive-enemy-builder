-- The title table: Nemesis-style earned names, tier 1-10. A creature's title
-- is DETERMINISTIC - hashed from its npcID within its tier pool - so the same
-- enemy carries the same name for everyone, every session. (math.random is
-- banned by the compliance gate anyway: it reseeds the client's shared RNG.)
-- Menace scales with tier: a tier-1 killer is an omen; a tier-10 is a legend.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

RUN.Titles = {
    [1] = { "the Blooded", "the Biter", "the Prowler", "the Snatcher",
            "the Creeper", "the First Cut" },
    [2] = { "the Scarred", "the Hungry", "the Stalker", "the Ambusher",
            "the Rabid", "the Vicious" },
    [3] = { "the Cruel", "the Savage", "the Mauler", "the Relentless",
            "the Grim", "the Gouger" },
    [4] = { "the Widowmaker", "Bonebreaker", "the Merciless", "Gravemaker",
            "the Butcher", "Fleshrender" },
    [5] = { "the Manslayer", "Skullkeeper", "Bloodreaper", "Corpsemaker",
            "the Dread", "the Hollowing" },
    [6] = { "Doomfang", "the Harrower", "Plaguebearer", "Soulrender",
            "the Nightstalker", "the Undying Hunger" },
    [7] = { "Herald of Ruin", "the Unkillable", "Dreadmaw", "Bane of the Living",
            "the Reaper's Hand", "the Long Dark" },
    [8] = { "Scourge of the Land", "the Deathless", "Harbinger of Sorrow",
            "the Devourer", "the Final Mistake", "Graveherald" },
    [9] = { "Death Incarnate", "the Worldbane", "the Inevitable",
            "Nightmare Made Flesh", "the Apocalypse Crawling", "Slaughter's Legend" },
    [10] = { "Death Itself", "the End of All Runs", "the Last Thing You See",
             "Azeroth's Reckoning", "the Unforgiven", "the Legend" },
}

return RUN.Titles
