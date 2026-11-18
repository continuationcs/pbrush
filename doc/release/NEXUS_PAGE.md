# Nexus Mods 发布页内容（复制粘贴用）

**已发布（2026-11-11）**：https://www.nexusmods.com/phantombladezero/mods/1099 ，名称 BOSS RUSH，文件 BOSS RUSH。

上传文件：`out/BossRush-0.1.8.zip`；主图：`doc/release/main_image.png`（1920×1080，上传到 Images，设为 primary）

## 0.1.8 更新说明（Changelog / 文件说明）

自 0.1.7（35e1f61）以来的改动。

```
- New boss: Leng Tu, Herald of the Veil. All five phases in one go, calling up the bosses of each phase, in any
  arena. All 75 bosses are open now. On a save whose story fight with Leng Tu reached its fourth phase, the game
  starts it there in the challenge too; the mod leaves your save alone, so it stays that way.
- Every boss now falls with the game's boss-defeat banner (斩), once per fight; before, only some bosses showed it.
- Fix: in the Realm of Mirage you were moved to a fixed spot to fight. Entered from some Bells (Xigu, for one)
  that spot was far from where you arrive and not yet loaded, so you fell into the void, and it counted as a game
  death. The fight now starts right where you arrive. Thanks to sara1ovo for the report.
- Fix: a death before the first boss appears now ends the run as Undying Grudge instead of leaving it waiting.
```

中文：

```
- 新开放首领：梦差：冷荼。五个阶段连着打，各阶段照常召来手下的首领，任意场地都能打。至此 75 位首领全部开放。
  剧情里和冷荼打到过第四阶段的存档，挑战里它也从第四阶段打起；mod 不改存档，所以这一点保持原样。
- 每位首领倒下时都会出现游戏的「斩」字，一场只出现一次；以前只有部分首领有。
- 修复：镜花水月里原先会把你挪到一个固定的点开打。从某些铃铛（比如溪谷）进去时，那个点离入口很远、地面还没加载，
  人会掉进虚空，算作一次游戏死亡。现在就在进入的地方开打。感谢 sara1ovo 的反馈。
- 修复：首领出现之前战死，挑战现在会以「饮恨」结束，不再一直等着。
```

## 0.1.7 更新说明（Changelog / 文件说明）

自 0.1.6（95c5fc0）以来的改动。

```
- New: choose how the arena is picked. Trial of Echoes → Settings has a second row, "Battle · Arena", that
  steps through Auto / Nearby / Random on confirm. Auto is the pick so far. Nearby takes the nearest arena on
  your map and moves you there without a loading screen (if that part of the map is not loaded yet, you travel
  as usual). Random takes a scenic spot you have reached, ignoring the arena chosen for a boss or Gauntlet.
  The Lion Dance Grandmaster is still fought only at The Sealed Lion. A random pick (in Auto too) never repeats
  the arenas of your last two runs.
- Best times and settings now live in <game folder>\ProjectPBZ\Saved (BossRushScorepad.tsv,
  BossRushSettings.tsv), so a reinstall or a mod manager keeps them. Your old records.tsv is moved there on
  first start.
- Fix: Peng Meng (and other bosses that wait to be executed) could stop at an empty health bar and not die.
  Now the next hit finishes them.
- Fix: Corpse-Eating Xue no longer heals herself again and again, and she now calls her thugs (one wave of
  four, as strong as she is scaled). Summons still standing are cleared when their boss falls or the run ends.
- The Gold-Masked One and Gu Wanyue shrug off most hits by the game's own design; the mod leaves them as they are.
- Thanks to 69NexusNeko69 for the report behind these fixes.
- The game menu row is now "Trial of Echoes: Leave Battle".
- If the menus show the wrong language, UE4SS.log now records what the mod read: please send that line
  ("[BossRush] i18n: ...").
```

中文：

```
- 新增：场地怎么选可以自己定。残影试炼 →「设置」多了一行「战斗 · 场地」，按确认键在自动 / 就近 / 随机之间切换。
  自动和以前一样；就近去当前地图上最近的场地，不用加载（那一带地图还没加载时照常传送）；随机去一处去过的名胜，
  不管首领或连战组选定的场地。舞狮尊主仍只在尊主封印地打。随机挑场地时（自动里的随机一步也是）不重复前两局的场地。
- 最佳纪录和设置改存在 <游戏目录>\ProjectPBZ\Saved（BossRushScorepad.tsv、BossRushSettings.tsv），重装 mod、
  用 mod 管理器都不丢。旧的 records.tsv 首次启动时自动搬过去。
- 修复：斧老大彭猛（以及其他等待处决的首领）血条打空后可能停住不死；现在再补一刀就倒。
- 修复：吞噬尸体的小雪不再反复回血，并且会召唤女暴徒（一波四只，按小雪的倍数加强）。首领倒下或挑战结束时，
  还站着的召唤物一并清掉。
- 金面具黑衣人和女妖骨婉约大部分攻击打不进去，是原作机制，mod 不改。
- 感谢 69NexusNeko69 的反馈，这几项修复都来自这份报告。
- 游戏菜单里的退出项改为「残影试炼：退出战斗」。
- 菜单语言不对时，UE4SS.log 里会记下 mod 读到的语言，请把那一行（「[BossRush] i18n: …」）发给我。
```

## 0.1.6 更新说明（Changelog / 文件说明）

自 0.1.5（541a06f）以来的改动。

```
- New: Foe Strength, for a harder fight. Trial of Echoes has a new Settings page; its row
  "Foe · Strength · Tier I" steps through five tiers on confirm. Tier I is as before; Tiers II-V raise boss
  health and Sha-Chi (x1.5 / x2.25 / x3.4 / x5) and attack and Sha-Chi damage (x1.4 / x2 / x2.7 / x3.8) on top
  of the progress and New Game+ scaling, and shorten the boss's breaks. The tier applies to Duel and Gauntlet
  alike and is kept across restarts; best times are kept per tier (times so far count as Tier I), and the result
  screen shows the tier after the difficulty. Thanks to a1435033075 for asking for it.
- Bosses make an entrance instead of popping up and attacking at once: a mark rises where the boss will stand,
  the boss appears in it 1.5 s later and holds still for 1.5 s before it moves. Bosses now appear 12 m away
  (was 8 m), closer only where the arena is narrow.
- 8 more bosses: the four Acolytes (Yanru, Lei Ting, Guhe, Hansui), Dusk, Zuo Shang (the Order's Shadow
  Sovereign), Zuo Shang, the True Lóng, and The Snowstorm Blade. 74 bosses in all; only Leng Tu is still closed.
- Jade Dancer and Iron Fiend are one entry and fight you together.
- Gauntlet: A Thousand Echoes is now nine stages, grouped by the map where you meet the bosses, each a run with its own best time
  (it was every boss in one run); it heads the Gauntlet list and opens a page of its stages. Groups renamed and
  reordered: Gentle Jade, Hidden Edge (was The Young Mistress), Under the Shadow Sovereign (was Order's Finest),
  Iron Steeds, Setting Sun (was Veterans of War), Grudges of the Sword Tomb (was Shadows of the Sects); The
  Acolytes is back. Best times of renamed groups are kept. The Gauntlet page opens on Next, like Duel.
- Each Gauntlet group and stage has its own arena, used once its Bell is rung. The Gold-Masked One and the
  Lion Dance Grandmaster now join Gauntlets: their group goes to their own battlefield.
- A Duel goes to the boss's arena when there is one (Mu Xiaokui: First Meeting Lakeside, The Snowstorm Blade:
  Whiteshadow's Fall).
- Fights no longer start right next to a Bell: arena spots marked again away from their Bells, two arenas added
  (Whiteshadow's Fall, Ancestral Shrine Square), two removed (The Lady Grounds, Tower Rear Exit), two renamed
  (First Meeting Lakeside, Meigu Lakeside). Starting at a Bell, you are moved onto the spot behind a fade.
- Fixed: Grief-Stricken Jin could not be killed.
- Fixed: dying in a fight next to a Bell revived you in the arena and the fight went on; a death now ends the
  run as Undying Grudge. Deaths in the Realm of Mirage, which counted as Sheathe Your Blade, are fixed too.
- Fixed (New Game+): The Lóng Pillar and The Sealed Lion are used only once their Bell is rung in this
  playthrough. Dying at The Lóng Pillar before its Bell was rung could crash the game and leave the save at that
  Bell. Until the Bell is rung, the Gold-Masked One is fought at another arena, and the Lion Dance Grandmaster
  asks you to ring the Bell at The Sealed Lion first.
- Thanks to mastersoul2 for the reports and tests behind both fixes.
- A death in a challenge is no longer a game death: it ends the run as Undying Grudge, costs no days in 66 Days
  and adds no death to the count. On 66 Days, entering Trial of Echoes still shows a
  notice suggesting another difficulty, in case an unexpected death slips through.
- After a game update, the mod checks at start-up that the game parts it uses are still there. If a core part
  is missing, Trial of Echoes pauses with a notice until the mod is updated; a missing boss or arena is left out.
```

中文：

```
- 新增「敌方 · 强度」：残影试炼新增「设置」页，其中「敌方 · 强度」一行按确认键在一重～五重之间切换。一重与之前相同；
  二重～五重在进度和周目提升之上，首领生命和杀气 ×1.5 / ×2.25 / ×3.4 / ×5，攻击和破气 ×1.4 / ×2 / ×2.7 / ×3.8，破势硬直更短。
  单挑、连战都用这一档，重启游戏后保留；最佳用时按档分开记（以前的纪录算一重），结算画面在难度后面显示档位。
  感谢 a1435033075 的建议。
- 首领出场：不再凭空出现、立刻出手。先在它要出现的位置浮现征兆，1.5 秒后首领在其中现身，原地停 1.5 秒再行动；
  出现距离从 8 米改为 12 米，场地窄时自动近一些。
- 新开放 8 位首领：灭法之法四人（炎茹、雷婷、蛊鹤、寒岁）、操偶师荡秽、组织冥主：左殇、龙体左殇、风雪刀客。
  共 74 位首领，只剩梦差冷荼暂未开放。
- 玉妖和铁鬼合为一行「少主护卫：玉妖铁鬼」，两人同时登场。
- 连战：千影归来拆成九段，按首领所在的地图分段，每段单独一局、单独计最佳用时（原来是全部首领一局打完）；它排在连战第一位，
  点进去是九段的列表。改名和调整顺序：温玉藏锋（原少主仪仗）、冥主麾下（原组织高手）、铁马残阳（原沙场宿将）、
  剑冢遗恨（原名门残影）；加回灭法之法。改名的组保留原有最佳用时。连战页进入时光标在「下一页」，和单挑一样。
- 每个连战组、每段千影都有自己的场地，敲响其铃铛后就去那里打。金面具黑衣人和舞狮尊主也能进连战了：整组去它们的专属战场打。
- 单挑有推荐场地的首领会去那里打（沐小葵：初见湖畔；风雪刀客：白影陨落之处）。
- 不再紧挨着铃铛开打：各场地离开铃铛重新标点，新增「白影陨落之处」「祠堂广场」，去掉「圣母雕像场」「高塔后方出口」，
  「湖畔」改名「初见湖畔」、「陆家村湖畔」改名「梅谷湖畔」。从铃铛出发时，画面淡出后把你移到场地上。
- 修复：悲痛欲绝的阿瑾打不死。
- 修复：在铃铛旁的场地战死后会原地复活、挑战继续；现在战死即以「饮恨」结束；镜花水月中战死被记成「收刃离去」的问题也一并修好。
- 修复（多周目）：专属战场「龙柱」「尊主封印地」只在本周目已敲响其铃铛时使用。之前在铃铛未敲的龙柱战死，可能导致游戏崩溃，
  存档也停在那个铃铛。铃铛未敲时，金面具黑衣人改在其他场地打；舞狮尊主会提示先敲响尊主封印地的铃铛。
- 感谢 mastersoul2 的反馈和测试，这两项修复都来自这位玩家的排查。
- 挑战中战死不再算游戏里的死亡：直接以「饮恨」结束，六十六天难度不折损天数，也不计入死亡次数。
  六十六天难度下进入残影试炼仍会提示尽量换用其他难度，以防意外身陨。
- 游戏更新后，mod 启动时会检查用到的游戏内容是否还在：缺少核心部件时残影试炼暂停并提示，待 mod 更新后恢复；
  缺少某位首领或某个场地时只去掉那一项。
```

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
- New Game+: an arena where the game's own boss is still alive is swapped for another, so that boss no longer
  joins the fight; a boss fought only on its own battlefield asks you to beat it in this playthrough first.
- New Game+: bosses now grow with the playthrough like the game's own enemies (they stayed at first-playthrough
  strength before).
- Fixed: bosses started with only a sliver of their Sha-Chi gauge; it is now full.
- Fixed: Mo Yuan could not be killed in New Game+ (his health stopped just above zero).
- Thanks to mastersoul2 for the detailed New Game+ report and fix suggestions behind these changes.
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
- 多周目：场地上还站着游戏原本的首领时，自动换一处场地，不再出现两个同样的首领；只能在专属战场打的首领，会提示先在本周目击败它。
- 多周目：首领数值随周目提升，和游戏原生敌人一致（之前一直停在一周目的强度）。
- 修复：首领开场杀气只有一小截，现在是满的。
- 修复：多周目时魔渊打不死（血量停在接近 0 的地方）。
- 感谢 mastersoul2 详细的多周目反馈和修改建议，上面几项都来自这位玩家的排查。
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
| Version | 0.1.8 |
| Category | Gameplay |
| Language | English（页面描述里同时放了中文） |
| Requirements → Nexus requirements | UE4SS for Phantom Blade Zero（phantombladezero/mods/13），说明填：Required. Install and test it first. |
| File name | BOSS RUSH 0.1.8 |
| File category | Main files |
| File description | Extract into <game>\platform\steam\ue4ss\Mods\ |
| Permissions / credits | 致谢 RE-UE4SS 团队、KintaroModding 与 mastersoul2（见描述末尾）。资产权限按你的意愿选择。 |

## Brief overview（简介，最多 255 字符）

Fight the bosses again from any Bell. Duel any boss or run themed boss gauntlets, scaled to your progress, with a result screen and best times. Built into the Bell menu with the game's own UI. No loot, no save changes.

## Description（BBCode）

```
[size=5][b]Trial of Echoes (残影试炼)[/b][/size]

Fight the game's bosses again, any time, from any Bell. Gamepad friendly.

The mode lives in the Bell menu and uses the game's own buttons, fonts, transitions and boss health bar, so it feels like part of the game. 

[size=4][b]Modes[/b][/size]
[list]
[*][b]Duel[/b] - pick any boss and fight it once more.
[*][b]Gauntlet[/b] - fight a group of bosses back to back: A Thousand Echoes (every boss, in nine stages by map), Gentle Jade, Hidden Edge, Under the Shadow Sovereign, Shadow Wardens, Puppet Theatre, The Acolytes, Three Masks, Perils of the Wulin, Madmen of the Wulin, Strange Tales, Iron Steeds, Setting Sun, Grudges of the Sword Tomb. Each builds up to its strongest boss, at an arena chosen for it. A little health returns between fights; fall once and the run ends.
[/list]

[size=4][b]How it plays[/b][/size]
[list]
[*]Ring any Bell and choose [b]Trial of Echoes[/b] below Traverse.
[*]Pick how the arena is chosen in Settings → Battle · Arena. Auto (default): stand at one of the arenas and the fight starts right there; otherwise you go to the arena chosen for that boss or Gauntlet once you have rung its Bell, or to a random scenic spot you have reached. Nearby: the nearest arena on your map, reached without a loading screen. Random: a scenic spot you have reached, never one of your last two.
[*]Bosses are scaled to your progress with the game's own monster level curves, so early bosses are still a fight late in the game. Difficulty follows your game setting; for a harder fight, pick Foe Strength Tier II-V in Settings (more boss health and attack).
[*]Leave at any time from the game menu: [b]Trial of Echoes: Leave Battle[/b] (System → Exit Game).
[*]A result screen shows your time and best time. Press confirm and you wake beside the Bell you started from, with health and remedies as they were.
[*]No side effects: challenge kills give no loot or Remnant Dust and do not touch your codex, quests or story. The mod never writes into your save; best times and settings are kept in [code]<game folder>\ProjectPBZ\Saved[/code] (BossRushScorepad.tsv, BossRushSettings.tsv), so they survive a reinstall.
[/list]

[size=4][b]Requirements[/b][/size]
[list]
[*]Phantom Blade Zero (Steam)
[*][url=https://www.nexusmods.com/phantombladezero/mods/13]UE4SS for Phantom Blade Zero[/url] by KintaroModding - install it first and make sure it works.
[/list]

[size=4][b]Installation[/b][/size]
Extract the archive into [code]<game folder>\platform\steam\ue4ss\Mods\[/code] so that you get [code]...\ue4ss\Mods\BossRush\Scripts\main.lua[/code]. The included enabled.txt turns the mod on.
To uninstall, delete the BossRush folder; to also clear best times and settings, delete the two BossRush*.tsv files in [code]ProjectPBZ\Saved[/code].

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
[*]All 75 bosses are available. Leng Tu starts from its fourth phase on a save whose story fight with it got that far: the game keeps that in your save, and the mod does not touch it. The Lion Dance Grandmaster is fought only at its own battlefield, The Sealed Lion, once its Bell is rung in this playthrough. The Gold-Masked One and Mo Yuan are fought at The Lóng Pillar once its Bell is rung, at another arena before that.
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

随时随地，在任意铃铛处，再战昔日强敌。完美支持手柄。

入口在铃铛菜单里，用游戏自己的按钮、字体、转场和首领血条，玩起来就像游戏自带的模式。

[b]模式[/b]
[list]
[*][b]单挑[/b]：任选一位首领，再战一场。
[*][b]连战[/b]：连续挑战一组首领：千影归来（全部首领，按地图分九段）和十一个主题组。每组越打越强，在为它选定的场地开打。两战之间少量回血，倒下即失败。
[/list]

[b]玩法[/b]
[list]
[*]敲响任意铃铛，在“穿行”下方选择「残影试炼」。
[*]场地怎么选，在「设置」的「战斗 · 场地」里定。自动（默认）：站在场地上就原地开打，否则去为该首领或该组选定的场地（敲响其铃铛后），或随机一处去过的名胜；就近：当前地图上最近的场地，不用加载；随机：随机一处去过的名胜，不重复前两局。
[*]首领数值按你的进度、用游戏自己的等级曲线提升；难度跟随游戏设置；嫌不够难，可在「设置」里选「敌方 · 强度 · 二重～五重」，首领生命和攻击更高。
[*]随时可在游戏菜单选「残影试炼：退出战斗」退出（系统 → 退出游戏）。
[*]结束后显示结算画面和最佳纪录，按确认键回到出发的铃铛，血量和药瓶恢复如初。
[*]无副作用：不掉落、不给意识尘埃、不影响图鉴、任务和剧情；不写入存档。最佳纪录和设置存在 [code]<游戏目录>\ProjectPBZ\Saved[/code]（BossRushScorepad.tsv、BossRushSettings.tsv），重装 mod 也不丢。
[/list]

[b]前置[/b]：[url=https://www.nexusmods.com/phantombladezero/mods/13]KintaroModding 的影之刃零版 UE4SS[/url]，请先安装并确认可用。

[b]安装[/b]：解压到 [code]<游戏目录>\platform\steam\ue4ss\Mods\[/code]，得到 [code]...\ue4ss\Mods\BossRush\Scripts\main.lua[/code]。卸载时删除 BossRush 文件夹即可；要连最佳纪录和设置一起清掉，再删除 [code]ProjectPBZ\Saved[/code] 里的两个 BossRush*.tsv。

[b]兼容性[/b]：只增加内容，不替换游戏文件、不改存档，可与其他 UE4SS Lua mod、.pak mod 共存；只可能与改动铃铛菜单、游戏菜单、对话选项按钮或提示条的 mod 冲突；改怪物数值或难度的 mod 会连带影响挑战首领的强度。

[b]已知限制[/b]：75 位首领全部开放；剧情里和梦差冷荼打到过第四阶段的存档，挑战里它也从第四阶段打起（进度记在存档里，mod 不改存档）；舞狮尊主只在它的战场「尊主封印地」打（本周目敲响其铃铛后），金面具黑衣人和魔渊在「龙柱」铃铛敲响后在龙柱打，之前在其他场地；肉鸽玩法「万象」暂未加入；文字为简体中文或英文。

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
- [ ] 用手柄完整走一遍：进菜单、选首领、结算画面按 A 关闭、游戏菜单里的「残影试炼：退出战斗」。
- [x] 主图：`doc/release/main_image.png`
- [x] 实机图（中英各一套，1920×1200）：`doc/release/screenshots/`，1 铃铛菜单 · 2 首领列表 · 3 结算画面 · 4 退出挑战。结算画面底部显示开发版的 "dev" 版本号；还缺战斗中的图。
- [ ] 确认击杀首领后确实没有掉落和意识尘埃（目前只看到日志里“掉落组件已拆除”，还没在画面上核对）。
