-- Settings. Edit and restart the game to apply.
return {
    -- Development build: verbose log. Release builds set this to false.
    debug = true,

    -- Raise boss stats to the player's progress (DESIGN 5.3). false = 「原貌」: fight at base stats.
    scale_enabled = true,
    -- How strongly the game's own monster level curve is applied: mult = 1 + curve(level) * curve_weight.
    -- 1.0 = exactly the game's own formula (confirmed against native enemies): a boss is as strong as a
    -- native enemy of the same level.
    curve_weight = 1.0,
    -- Difficulty follows the game's own setting. Extra boss levels per game difficulty
    -- (index = EDifficultMode: 0 Handicapped, 1 Easy, 2 Normal, 3 Hard, 4 NightMare).
    -- All 0 (user decision): the game applies its own difficulty elsewhere (native enemies carry no
    -- difficulty bonus in their attributes), so adding levels here would count it twice.
    difficulty_offset = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 },
    -- 敌方 · 强度 · 一重 … 五重 (Foe Strength Tier I-V; user decisions 2026-11-14, DESIGN 5.3a): the player's choice on the
    -- 设置 page (残影试炼 → 设置), multiplied on top of the progress scaling. Geometric steps, as Diablo III's difficulties:
    -- health x1.5 per tier, so each tier feels as much harder as the last. Attack x1.4 per tier (user decision
    -- 2026-11-15, after 五重 at x2 was still too easy; first x1.2): a mistake costs more, the fight is no longer.
    --   health: Health and Sha-Chi (otherwise a tougher boss would still break after a few hits)
    --   attack: Attack and ShachiAttack (破气)
    --   break_time: how long a break lasts (a Sha-Chi regeneration factor had no effect and was removed)
    tiers = {
        { health = 1,    attack = 1,    break_time = 1 },
        { health = 1.5,  attack = 1.4,  break_time = 0.9 },
        { health = 2.25, attack = 2,    break_time = 0.8 },
        { health = 3.4,  attack = 2.7,  break_time = 0.7 },
        { health = 5,    attack = 3.8,  break_time = 0.6 },
    },

    -- Share of max HP restored between two fights of a 连战.
    heal_between = 0.3,
    -- The result screen closes on a confirm key (gamepad A / B, Enter, Space, click), or by itself after this
    -- many seconds; then the trip back to the starting bell starts.
    settle_seconds = 20,
    -- A boss further than this from the arena centre (cm) is pulled back. Only meant to catch a boss thrown
    -- away by a skill or fallen out of the world, not a boss walking around.
    leash = 10000,
    -- Standing within this distance (cm) of an arena's marked spot starts the fight right here, no travel.
    in_place_radius = 3000,
    -- The player further than this from the arena centre (cm) during a fight has left: the run ends.
    player_leave = 15000,
}
