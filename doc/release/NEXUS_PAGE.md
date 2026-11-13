# Nexus Mods 发布页内容（复制粘贴用）

**已发布（2026-11-12）**：https://www.nexusmods.com/phantombladezero/mods/1099 ，名称 BOSS RUSH，文件 BOSS RUSH 0.1.0。页面顶部的 mod 版本号仍显示 1，需在 General 页改为 0.1.0。旧草稿 1098 已改名「BOSS RUSH old」，未发布；新版上传页没有删除入口，需要时联系 Nexus 客服删除。

上传文件：`out/BossRush-0.1.1.zip`（0.1.0 的铃铛菜单在用确认键时总会变成“穿行”，已在 0.1.1 修复）；主图：`doc/release/main_image.png`（1920×1080，上传到 Images，设为 primary）

## 基本信息

| 字段 | 填写 |
|---|---|
| Mod name | BOSS RUSH（名称里不能用中文） |
| Version | 0.1.0 |
| Category | Gameplay |
| Language | English（页面描述里同时放了中文） |
| Requirements → Nexus requirements | UE4SS for Phantom Blade Zero（phantombladezero/mods/13），说明填：Required. Install and test it first. |
| File name | Boss Challenge 0.1.0 |
| File category | Main files |
| File description | Extract into <game>\platform\steam\ue4ss\Mods\ |
| Permissions / credits | 致谢 RE-UE4SS 团队与 KintaroModding（见描述末尾）。资产权限按你的意愿选择。 |

## Brief overview（简介，最多 255 字符）

Fight the bosses again from any Bell. Duel any boss or run themed boss gauntlets, scaled to your progress, with a result screen and best times. Built into the Bell menu with the game's own UI. No loot, no save changes.

## Description（BBCode）

```
[size=5][b]Boss Challenge (强敌挑战)[/b][/size]

Fight the game's bosses again, any time, from any Bell. The mode lives in the Bell menu and uses the game's own buttons, fonts, transitions and boss health bar, so it feels like part of the game. Gamepad friendly.

[size=4][b]Modes[/b][/size]
[list]
[*][b]Duel[/b] - pick any boss and fight it once more.
[*][b]Gauntlet[/b] - fight a themed group of bosses back to back: Shadow Wardens, Puppet Theatre, The Young Mistress, Three Masks, Order's Finest, Two Faces of Death, Perils of the Wulin, A Thousand Echoes. A little health returns between fights; fall once and the run ends.
[/list]

[size=4][b]How it plays[/b][/size]
[list]
[*]Ring any Bell and choose [b]Boss Challenge[/b] below Traverse.
[*]The arena is chosen for you: stand at one of the arenas and the fight starts right there, otherwise you are taken to a random arena (scenic spots you have reached, or the boss's own battlefield).
[*]Bosses are scaled to your progress with the game's own monster level curves, so early bosses are still a fight late in the game. Difficulty follows your game setting.
[*]Leave at any time from the game menu: [b]Boss Challenge · Leave[/b] (System → Exit Game).
[*]A result screen shows your time and best time. Press confirm and you wake beside the Bell you started from, with health and remedies as they were.
[*]No side effects: challenge kills give no loot or Remnant Dust and do not touch your codex, quests or story. The mod never writes into your save; best times are kept in the mod folder.
[/list]

[size=4][b]Requirements[/b][/size]
[list]
[*]Phantom Blade Zero (Steam)
[*][url=https://www.nexusmods.com/phantombladezero/mods/13]UE4SS for Phantom Blade Zero[/url] by KintaroModding - install it first and make sure it works.
[/list]

[size=4][b]Installation[/b][/size]
Extract the archive into [code]<game folder>\platform\steam\ue4ss\Mods\[/code] so that you get [code]...\ue4ss\Mods\BossRush\Scripts\main.lua[/code]. The included enabled.txt turns the mod on.
To uninstall, delete the BossRush folder.

[size=4][b]Settings[/b][/size]
Edit [code]BossRush\Scripts\config.lua[/code] and restart the game: boss scaling on/off and strength, heal between Gauntlet fights, how long the result screen stays.

[size=4][b]Compatibility[/b][/size]
[list]
[*]Only adds things: replaces no game file and edits no save, so it works alongside other UE4SS Lua mods and .pak mods.
[*]May clash only with mods that change the same screens: the Bell menu, the in-game menu, or the game's dialogue-choice button / tip strip widgets.
[*]Mods that change monster stats, level curves or difficulty also change how strong challenge bosses are.
[*]Binds no keyboard keys.
[/list]

[size=4][b]Known limitations[/b][/size]
[list]
[*]54 bosses are available. Bosses whose skills rely on points placed in their own level (e.g. Zuo Shang, Yuzan, the Lion Dance Grandmaster's second phase) are not offered yet.
[*]The roguelike Trial mode is not included yet.
[*]Text: Simplified Chinese or English.
[*]Made and tested on the Steam version, game build CL-302256.
[/list]

[size=4][b]Credits[/b][/size]
[list]
[*][url=https://github.com/UE4SS-RE/RE-UE4SS]RE-UE4SS[/url] team (MIT)
[*][url=https://github.com/KintaroModding/ue4ss]KintaroModding[/url] - Phantom Blade Zero support for UE4SS (MIT)
[*]Phantom Blade Zero by S-GAME. This mod ships no game files.
[/list]

[line]

[size=5][b]强敌挑战[/b][/size]

随时随地，在任意铃铛处再战昔日强敌。入口在铃铛菜单里，用游戏自己的按钮、字体、转场和首领血条，玩起来就像游戏自带的模式。支持手柄。

[b]模式[/b]
[list]
[*][b]单挑[/b]：任选一位首领，再战一场。
[*][b]连战[/b]：按主题连续挑战一组首领。两战之间少量回血，倒下即失败。
[/list]

[b]玩法[/b]
[list]
[*]敲响任意铃铛，在“穿行”下方选择「强敌挑战」。
[*]场地自动决定：站在场地上就原地开打，否则随机传送到一个场地。
[*]首领数值按你的进度、用游戏自己的等级曲线提升；难度跟随游戏设置。
[*]随时可在游戏菜单选「强敌挑战 · 退出挑战」退出（系统 → 退出游戏）。
[*]结束后显示结算画面和最佳纪录，按确认键回到出发的铃铛，血量和药瓶恢复如初。
[*]没有副作用：不掉落、不给意识尘埃、不影响图鉴、任务和剧情；不写入存档。
[/list]

[b]前置[/b]：[url=https://www.nexusmods.com/phantombladezero/mods/13]KintaroModding 的影之刃零版 UE4SS[/url]，请先安装并确认可用。

[b]安装[/b]：解压到 [code]<游戏目录>\platform\steam\ue4ss\Mods\[/code]，得到 [code]...\ue4ss\Mods\BossRush\Scripts\main.lua[/code]。卸载时删除 BossRush 文件夹即可。

[b]兼容性[/b]：只增加内容，不替换游戏文件、不改存档，可与其他 UE4SS Lua mod、.pak mod 共存；只可能与改动铃铛菜单、游戏菜单、对话选项按钮或提示条的 mod 冲突；改怪物数值或难度的 mod 会连带影响挑战首领的强度。

[b]已知限制[/b]：目前开放 54 位首领，依赖原关卡场景点位的首领（如左殇、玉簪、舞狮尊主二阶段）暂未开放；肉鸽玩法「试炼」暂未加入；文字为简体中文或英文。
```

## 上传前自检

- [ ] 用发布包（而不是开发版）在游戏里完整跑一遍：先停用探测 mod，删掉开发版 BossRush，解压 `BossRush-0.1.0.zip` 安装，打一局单挑、一局连战。
- [ ] 用手柄完整走一遍：进菜单、选首领、结算画面按 A 关闭、游戏菜单里的「强敌挑战 · 退出挑战」。
- [x] 主图：`doc/release/main_image.png`
- [ ] 再截 2~4 张实机图：铃铛菜单里的「强敌挑战」、首领列表、战斗中、结算画面。
- [ ] 确认击杀首领后确实没有掉落和意识尘埃（目前只看到日志里“掉落组件已拆除”，还没在画面上核对）。
