Trial of Echoes (残影试炼, BOSS RUSH) for Phantom Blade Zero
=============================================================

Fight the game's bosses again, any time, from any Bell. The mode is built into the Bell menu and uses the
game's own buttons, fonts, transitions and boss health bar, so it plays like part of the game.

MODES
  Duel       Pick any boss and fight it once more; a boss with several phases is fought in one go.
  Gauntlet   Fight a themed group of bosses back to back (11 groups: Shadow Wardens,
             Puppet Theatre, Three Masks, Order's Finest, Perils of the Wulin, Strange Tales,
             Veterans of War, A Thousand Echoes...). Each builds up to its strongest boss.
             A little health returns between fights; fall once and the run ends.

HOW IT PLAYS
  - Ring any Bell and choose "Trial of Echoes" below "Traverse". Works with a gamepad.
  - The arena is chosen for you: if you stand at one of the arenas, the fight starts right there;
    otherwise you are taken to a random arena (scenic spots you have reached, or the boss's own battlefield).
  - Bosses are scaled to your progress with the game's own monster level curves, so early bosses stay
    a real fight late in the game, and they grow with each playthrough (New Game+). Difficulty follows
    your game setting.
  - In New Game+, an arena where the game's own boss still stands is swapped for another.
  - Leave a run at any time from the game menu: "Trial of Echoes · Leave" (System → Exit Game).
  - When it ends, a result screen shows your time, best time and difficulty; press confirm to return.
    You wake beside the Bell you started from, with your health and remedies as they were.
  - No side effects: challenge kills give no loot or Remnant Dust, and do not touch your codex,
    quests or story. The mod never writes into your save; best times live in this folder (records.tsv).

REQUIREMENTS
  - Phantom Blade Zero (Steam).
  - UE4SS for Phantom Blade Zero by KintaroModding:
    https://www.nexusmods.com/phantombladezero/mods/13
    Install it first and make sure it works.

INSTALL
  Extract the archive into
      <game folder>\platform\steam\ue4ss\Mods\
  so that you get
      ...\ue4ss\Mods\BossRush\Scripts\main.lua
  The included enabled.txt switches the mod on; no mods.txt edit is needed.

UNINSTALL
  Delete the BossRush folder. Your save is untouched.

SETTINGS (BossRush\Scripts\config.lua, restart the game after editing)
  scale_enabled    false = fight bosses at their base stats.
  curve_weight     boss strength: 1.0 = the game's own level curve, lower = easier.
  heal_between     share of max health restored between Gauntlet fights (default 0.3).
  settle_seconds   the result screen closes by itself after this many seconds.

COMPATIBILITY
  - Runs in its own Lua state and only adds things; it replaces no game file and edits no save, so it
    sits alongside other UE4SS Lua mods and .pak mods.
  - Likely to clash only with mods that change the same screens: the Bell menu, the in-game menu,
    or the game's dialogue-choice button / tip strip widgets.
  - Mods that change monster stats, level curves or difficulty also change how strong challenge bosses are.
  - Mods that bind keyboard keys are unaffected: this mod binds none.

KNOWN LIMITATIONS
  - 66 bosses are available. The Lion Dance Grandmaster's second phase is fought only at its own
    battlefield (The Sealed Lion), and the Gold-Masked One and Mo Yuan only at The Lóng Pillar, in Duel
    only. Eight bosses whose skills rely on their own level are not offered yet: the four Acolytes, Dusk,
    Leng Tu, and Zuo Shang (first form and True Lóng).
  - The roguelike mode (Myriad) is not included yet.
  - Text is Simplified Chinese or English (Traditional Chinese shows Simplified for now).
  - Made and tested on the Steam version, game build CL-302256.

CREDITS
  - UE4SS: the RE-UE4SS team (MIT License), https://github.com/UE4SS-RE/RE-UE4SS
  - Phantom Blade Zero support for UE4SS (memory layout and signatures): KintaroModding (MIT License),
    https://github.com/KintaroModding/ue4ss
  - mastersoul2: New Game+ testing and fix suggestions (Sha-Chi gauge, boss levels, Mo Yuan, deaths in the
    Realm of Mirage), https://next.nexusmods.com/profile/mastersoul2
  - Phantom Blade Zero is a game by S-GAME. All game assets belong to their owners; this mod ships
    no game files.
