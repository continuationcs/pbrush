# BOSS RUSH for Phantom Blade Zero

A UE4SS Lua mod that adds **强敌挑战 / Boss Challenge** to the Bell menu: fight the game's bosses again, one at a
time (**单挑 Duel**) or in themed groups (**连战 Gauntlet**). It uses the game's own buttons, fonts, tip strip,
result layout and boss health bar, so it plays like a built-in mode.

Published on Nexus Mods: <https://www.nexusmods.com/phantombladezero/mods/1099>

[中文说明见下方](#中文)

## Features

- Entry in the Bell menu, below Traverse; gamepad navigation works.
- **Duel**: any of 54 bosses. **Gauntlet**: 8 themed groups (Shadow Wardens, Puppet Theatre, The Young Mistress,
  Three Masks, Order's Finest, Two Faces of Death, Perils of the Wulin, A Thousand Echoes), a small heal between fights.
- Arena picked for you: fight in place when standing at an arena, otherwise travel to a random one
  (rung scenic spots or the boss's own battlefield), then return to the starting Bell.
- Boss stats follow your progress with the game's own monster level curves (`base × (1 + curve(level))`);
  difficulty follows the game setting.
- Result screen with time and best time; leave a run from the game menu («收刃离去», press twice).
- No side effects: no loot or Remnant Dust, no codex entries, no save changes; health and remedies restored.

## Install (players)

1. Install [OFFICIAL UE4SS for PBZ](https://www.nexusmods.com/phantombladezero/mods/13) and check it works.
2. Download the release zip and extract it into `<game>\platform\steam\ue4ss\Mods\`, giving
   `...\ue4ss\Mods\BossRush\Scripts\main.lua`. The bundled `enabled.txt` turns it on.

Settings live in `BossRush\Scripts\config.lua` (restart the game after editing).

## Repository layout

| Path | What |
|---|---|
| `mod/BossRush/Scripts/` | The mod. `main.lua` (menu pages), `menu.lua` (Bell menu injection), `run.lua` (a challenge from travel to return), `scale.lua`, `settle.lua` (result screen), `pause.lua` («收刃离去»), `ui.lua`, `arenas.lua`, `gauntlets.lua`, `roster.lua` (generated), `vows.lua` (kept, unused), `records.lua`, `i18n.lua`, `config.lua`, `util.lua` |
| `probe/BossRushProbe/` | Development probe: debug keys (F1 god mode, F2 Realm of Mirage, F3 result-screen preview, F4 mark arena, F5 bell dump, F6 arena teleport, F7 spawn boss, F8 report, F9 stats, F10 scale test) and logging |
| `docs/DESIGN.md` | Design, findings from the game, decisions and implementation status |
| `docs/COPY.md` | In-game text (zh / en) and writing rules |
| `data/` | Bell table (`bells.tsv`, 187 bells), arena list (`arenas_final.tsv`) |
| `tools/` | `install.ps1` (copy mods into the game), `build_release.py` (release zip), `gen_roster.py` (boss roster), `make_cover.py` (Nexus image), `pak_locres.py` |
| `release/` | Readmes shipped in the zip, Nexus page text, description BBCode, main image |
| `ue4ss-config/`, `ue4ss-signatures/`, `vendor/kintaro-pbz-config/` | UE4SS memory layout and signatures for this game build |

## Development

```powershell
# copy the mod (and the probe) into the game's UE4SS Mods folder
powershell -File tools\install.ps1 -Mods BossRush
powershell -File tools\install.ps1 -Mods BossRushProbe

# build the release zip into dist\ (debug log switched off in the copy)
python tools\build_release.py 0.1.1
```

Logs go to `<game>\platform\steam\ue4ss\UE4SS.log` with the prefixes `[BossRush]` and `[BRProbe]`.
Made against the Steam build CL-302256 with UE4SS experimental 3.0.1. See `AGENTS.md` for working notes.

## Credits

- [RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (MIT).
- Phantom Blade Zero support for UE4SS by [KintaroModding](https://github.com/KintaroModding/ue4ss) (MIT);
  the files under `vendor/kintaro-pbz-config/` come from there.
- Phantom Blade Zero by S-GAME. This repository contains no game files.
- Code, text and images were made with an AI assistant (Claude); design, testing and tuning by the author.

---

## 中文

给《影之刃零》加一个「强敌挑战」模式的 UE4SS Lua mod：在任意铃铛处单挑任一首领，或按主题连战一组首领。
入口在铃铛菜单“穿行”下方，用的是游戏自己的按钮、字体、提示条、结算版式和首领血条，支持手柄。

- **安装**：先装 [OFFICIAL UE4SS for PBZ](https://www.nexusmods.com/phantombladezero/mods/13)，再把发布包解压到
  `<游戏目录>\platform\steam\ue4ss\Mods\`。
- **场地**：站在场地上就原地开打，否则随机传送到一个场地，打完回到出发的铃铛。
- **数值**：按进度用游戏自己的等级曲线提升，难度跟随游戏设置。
- **没有副作用**：不掉落、不给意识尘埃、不写图鉴、不改存档；血量和药瓶恢复。
- 设计和决定记录在 `docs/DESIGN.md`，文案在 `docs/COPY.md`。
