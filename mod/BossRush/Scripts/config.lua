-- Settings. Edit and restart the game to apply.
return {
    -- Development build: verbose log. Release builds set this to false.
    debug = true,

    -- Only list bosses the player has already defeated (read from the game's codex).
    -- Off by the user's decision: every open boss is offered.
    beaten_only = false,

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
