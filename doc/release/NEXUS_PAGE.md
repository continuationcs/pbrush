# Nexus Mods 发布页内容（复制粘贴用）

**已发布（2026-11-12）**：https://www.nexusmods.com/phantombladezero/mods/1099 ，名称 BOSS RUSH，文件 BOSS RUSH 0.1.0。页面顶部的 mod 版本号仍显示 1，需在 General 页改为 0.1.0。旧草稿 1098 已改名「BOSS RUSH old」，未发布；新版上传页没有删除入口，需要时联系 Nexus 客服删除。

上传文件：`out/BossRush-0.1.5.zip`（0.1.4 之前：0.1.3 未发布，直接跳到 0.1.4）；主图：`doc/release/main_image.png`（1920×1080，上传到 Images，设为 primary）

## 0.1.5 更新说明（Changelog / 文件说明）

自 0.1.4（362d429）以来的改动。

```
0.1.5
- Renamed: the Bell menu entry is now Trial of Echoes (was Boss Challenge).
- Bosses with several phases are one entry: pick the boss and fight all its phases straight on, no healing in
  between, with a "Second Phase" notice. Yucong's second phase brings its three forms at once; the Gold-Masked
  One is followed by Mo Yuan; the Seven-Stars Formation's Chief Disciple is followed by his Sword of Despair
  together with the Red-Robed Swordswoman. Duel lists 50 entries for 66 bosses. Best times of these bosses
  start fresh.
- The Gold-Masked One and Mo Yuan are fought at their own battlefield, The Lóng Pillar, in Duel only.
- Fixed: the Chief Disciple of the Seven-Stars Formation was the wrong character; the Red-Robed Swordswoman is new.
- Fixed: the Hunt's second phase vanished; the mod stopped in the middle of some fights.
- Gauntlet regrouped: 11 groups of 4-5 fights, each building up to its strongest boss, with four new groups
  (Madmen of the Wulin, Strange Tales, Veterans of War, Shadows of the Sects). Best times are kept.
- Result screen: the title shows the result (it showed a placeholder before); the screen now shows the mode and
  boss, time, best time, bosses defeated and the game difficulty.
- Bell menu: the entry keeps working after coming back from a sub-screen (Ability Cultivation ...).
- New Game+: bosses now grow with the playthrough like the game's own enemies (they stayed at first-playthrough
  strength before).
- Fixed: bosses started with only a sliver of their Sha-Chi gauge; it is now full.
- Fixed: Mo Yuan could not be killed in New Game+ (his health stopped just above zero).
- Thanks to mastersoul2 for the detailed New Game+ report and fix suggestions behind these changes.
- New Game+: an arena where the game's own boss is still alive is swapped for another, so that boss no longer
  joins the fight; a boss fought only on its own battlefield asks you to beat it in this playthrough first.
```

中文（小黑盒 / Nexus 中文段落用）：

```
0.1.5
- 改名：铃铛菜单的入口改为「残影试炼」（原「强敌挑战」）。
- 多阶段首领合并为一位：选中后各阶段连着打完，阶段之间不回血，提示「第二阶段」。玉琮二阶段钢刃、寒冰、混沌同时出现；
  金面具黑衣人之后是魔渊；七星剑阵：大师兄之后是大师兄的绝望剑意和红衣女剑客一起登场。单挑共 50 行、66 位首领。
  这些首领的最佳用时重新计算。
- 金面具黑衣人和魔渊固定在原作战场「龙柱」打，只进单挑。
- 修复：七星剑阵：大师兄原先是错的角色；新增红衣女剑客。
- 修复：追命二阶段消失；部分战斗中途 mod 停止工作。
- 连战重新分组：共 11 组，每组 4～5 场，越打越强，新增痴狂众生、妖异志怪、沙场宿将、名门残影；原有最佳用时保留。
- 结算画面：标题正确显示胜负（之前显示占位文字）；显示模式和首领、用时、最佳、击败数和游戏难度。
- 铃铛菜单：从能力修行等子页面返回后，入口仍能正常选中和使用。
- 多周目：首领数值随周目提升，和游戏原生敌人一致（之前一直停在一周目的强度）。
- 修复：首领开场杀气只有一小截，现在是满的。
- 修复：多周目时魔渊打不死（血量停在接近 0 的地方）。
- 感谢 mastersoul2 详细的多周目反馈和修改建议，上面几项都来自这位玩家的排查。
- 多周目：场地上还站着游戏原本的首领时，自动换一处场地，不再出现两个同样的首领；只能在专属战场打的首领，会提示先在本周目击败它。
```

## 0.1.4 更新说明（Changelog / 文件说明）

```
0.1.4
- 11 more bosses: Yuzan, Bi Hai, the One-Eyed Archer, Yan Qiansui, Meng Hua, Blaze (both phases), Bai Chilian's second phase, Mo Yuan, the Gold-Masked One, Zuo Shang (Silver-Haired). Their skills used points placed in their own level; the mod now places those points in the arena. 65 bosses in all.
- The Lion Dance Grandmaster's second phase is back: fought at its own battlefield (The Sealed Lion), Duel only. Its last lion head can now be executed (the boss's summons are scaled with it).
- Arenas reviewed for open, level ground around the player and the boss: two arenas turned, one moved (now Lu Village Lakeside), one added (Lakeside).
- After a map change the boss appears only once the loading screen is gone, a few seconds later.
- Bell menu: the back key (Esc / gamepad B) goes one page up; Duel pages show 8 bosses, paging first, bosses in the order you meet them.
- Leave Challenge (System > Exit Game) now leaves with one press.
- Errors in the mod no longer take the game down: the mod switches itself off and shows a notice.
```

## 基本信息

| 字段 | 填写 |
|---|---|
| Mod name | BOSS RUSH（名称里不能用中文） |
| Version | 0.1.5 |
| Category | Gameplay |
| Language | English（页面描述里同时放了中文） |
| Requirements → Nexus requirements | UE4SS for Phantom Blade Zero（phantombladezero/mods/13），说明填：Required. Install and test it first. |
| File name | BOSS RUSH 0.1.5 |
| File category | Main files |
| File description | Extract into <game>\platform\steam\ue4ss\Mods\ |
| Permissions / credits | 致谢 RE-UE4SS 团队、KintaroModding 与 mastersoul2（见描述末尾）。资产权限按你的意愿选择。 |

## Brief overview（简介，最多 255 字符）

Fight the bosses again from any Bell. Duel any boss or run themed boss gauntlets, scaled to your progress, with a result screen and best times. Built into the Bell menu with the game's own UI. No loot, no save changes.

## Description（BBCode）

```
[size=5][b]Trial of Echoes (残影试炼)[/b][/size]

Fight the game's bosses again, any time, from any Bell. The mode lives in the Bell menu and uses the game's own buttons, fonts, transitions and boss health bar, so it feels like part of the game. Gamepad friendly.

[size=4][b]Modes[/b][/size]
[list]
[*][b]Duel[/b] - pick any boss and fight it once more.
[*][b]Gauntlet[/b] - fight a themed group of bosses back to back: Shadow Wardens, Puppet Theatre, The Young Mistress, Three Masks, Order's Finest, Perils of the Wulin, Madmen of the Wulin, Strange Tales, Veterans of War, Shadows of the Sects, A Thousand Echoes. Each builds up to its strongest boss. A little health returns between fights; fall once and the run ends.
[/list]

[size=4][b]How it plays[/b][/size]
[list]
[*]Ring any Bell and choose [b]Trial of Echoes[/b] below Traverse.
[*]The arena is chosen for you: stand at one of the arenas and the fight starts right there, otherwise you are taken to a random arena (scenic spots you have reached, or the boss's own battlefield).
[*]Bosses are scaled to your progress with the game's own monster level curves, so early bosses are still a fight late in the game. Difficulty follows your game setting.
[*]Leave at any time from the game menu: [b]Trial of Echoes · Leave[/b] (System → Exit Game).
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
[*]66 bosses are available. The Lion Dance Grandmaster's second phase is fought only at its own battlefield (The Sealed Lion), in Duel only; so are the Gold-Masked One and Mo Yuan, at The Lóng Pillar. Eight bosses whose skills rely on their own level are not offered yet: the four Acolytes, Dusk, Leng Tu, and Zuo Shang (first form and True Lóng).
[*]The roguelike mode (Myriad) is not included yet.
[*]Text: Simplified Chinese or English.
[*]Made and tested on the Steam version, game build CL-302256.
[/list]

[size=4][b]Credits[/b][/size]
[list]
[*][url=https://github.com/UE4SS-RE/RE-UE4SS]RE-UE4SS[/url] team (MIT)
[*][url=https://github.com/KintaroModding/ue4ss]KintaroModding[/url] - Phantom Blade Zero support for UE4SS (MIT)
[*][url=https://next.nexusmods.com/profile/mastersoul2]mastersoul2[/url] - New Game+ testing and fix suggestions (Sha-Chi gauge, boss levels, Mo Yuan, deaths in the Realm of Mirage)
[*]Phantom Blade Zero by S-GAME. This mod ships no game files.
[/list]

[line]

[size=5][b]残影试炼[/b][/size]

随时随地，在任意铃铛处再战昔日强敌。入口在铃铛菜单里，用游戏自己的按钮、字体、转场和首领血条，玩起来就像游戏自带的模式。支持手柄。

[b]模式[/b]
[list]
[*][b]单挑[/b]：任选一位首领，再战一场。
[*][b]连战[/b]：按主题连续挑战一组首领。两战之间少量回血，倒下即失败。
[/list]

[b]玩法[/b]
[list]
[*]敲响任意铃铛，在“穿行”下方选择「残影试炼」。
[*]场地自动决定：站在场地上就原地开打，否则随机传送到一个场地。
[*]首领数值按你的进度、用游戏自己的等级曲线提升；难度跟随游戏设置。
[*]随时可在游戏菜单选「残影试炼 · 退出挑战」退出（系统 → 退出游戏）。
[*]结束后显示结算画面和最佳纪录，按确认键回到出发的铃铛，血量和药瓶恢复如初。
[*]没有副作用：不掉落、不给意识尘埃、不影响图鉴、任务和剧情；不写入存档。
[/list]

[b]前置[/b]：[url=https://www.nexusmods.com/phantombladezero/mods/13]KintaroModding 的影之刃零版 UE4SS[/url]，请先安装并确认可用。

[b]安装[/b]：解压到 [code]<游戏目录>\platform\steam\ue4ss\Mods\[/code]，得到 [code]...\ue4ss\Mods\BossRush\Scripts\main.lua[/code]。卸载时删除 BossRush 文件夹即可。

[b]兼容性[/b]：只增加内容，不替换游戏文件、不改存档，可与其他 UE4SS Lua mod、.pak mod 共存；只可能与改动铃铛菜单、游戏菜单、对话选项按钮或提示条的 mod 冲突；改怪物数值或难度的 mod 会连带影响挑战首领的强度。

[b]已知限制[/b]：目前开放 66 位首领（舞狮尊主二阶段只在「尊主封印地」打，金面具黑衣人和魔渊只在「龙柱」打，都只进单挑），技能依赖原关卡的 8 位首领（灭法之法四人、荡秽、冷荼、左殇初见与龙体）暂未开放；肉鸽玩法「万象」暂未加入；文字为简体中文或英文。

[b]致谢[/b]
[list]
[*][url=https://github.com/UE4SS-RE/RE-UE4SS]RE-UE4SS[/url] 团队（MIT）
[*][url=https://github.com/KintaroModding/ue4ss]KintaroModding[/url]：UE4SS 的影之刃零适配（MIT）
[*][url=https://next.nexusmods.com/profile/mastersoul2]mastersoul2[/url]：多周目实测与修改建议（杀气槽、首领等级、魔渊、镜花水月中战死）
[*]《影之刃零》由灵游坊（S-GAME）开发；本 mod 不包含任何游戏文件。
[/list]
```

## 上传前自检

- [ ] 用发布包（而不是开发版）在游戏里完整跑一遍：先停用探测 mod，删掉开发版 BossRush，解压 `BossRush-0.1.0.zip` 安装，打一局单挑、一局连战。
- [ ] 用手柄完整走一遍：进菜单、选首领、结算画面按 A 关闭、游戏菜单里的「残影试炼 · 退出挑战」。
- [x] 主图：`doc/release/main_image.png`
- [x] 实机图（中英各一套，1920×1200）：`doc/release/screenshots/`，1 铃铛菜单 · 2 首领列表 · 3 结算画面 · 4 退出挑战。结算画面底部显示开发版的 "dev" 版本号；还缺战斗中的图。
- [ ] 确认击杀首领后确实没有掉落和意识尘埃（目前只看到日志里“掉落组件已拆除”，还没在画面上核对）。
