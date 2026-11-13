# 游戏内文案（草案）

目标：玩家打开后觉得这是游戏自带的模式。项目名对外叫 **Boss Rush**，但游戏里不出现这个词。

## 1. 从原作学到的写法

依据是游戏本体的 zh-Hans / en-US 文本（Game.locres，共 11142 条）。

| 原作做法 | 例子 |
|---|---|
| 世界观分**表武林**（Waking Realm）和**里武林**（Discordance）；铃铛可以从里武林穿行，铃铛菜单里能进**镜花水月**（Realm of Mirage） | 「返回表武林」「可以从里武林中，快速穿行至已经敲响过的铃铛之处」 |
| 铃铛菜单的条目是 2~4 个字的动宾短语 | 穿行 / 保存记忆 / 能力修行 / 装备升级 / 离开 |
| 名字用四字成语，英文用全大写 | 破釜沉舟 ALL OR NOTHING、至死不休 UNYIELDING WILL |
| 难度标语是对仗的两句四字，英文是一整句 | 凡躯入阵，初试锋芒 / 挥剑破局，不堕凶道 / 逆天而行，九死一生 |
| 关键词用富文本标签高亮 | `<Character_Yellow_Decorator2>【血脉重生】</>` |
| 物品说明先写效果，再写一段古风短文 | 「红线侵白骨，枯血养杀机……」 |
| 英文固定术语 | Wulin、Sha-Chi、Phantom Edges、Remnant Dust、Bell、Traverse、Cycle |
| 失败的说法 | 「饮恨」 Undying Grudge、「毙命：饮恨江湖」 |

**设定包装**：铃铛连着里武林，里武林里留存着死者的意识（原作里有“残存记忆”“意识尘埃”）。于是 Boss Rush 写成：**在铃铛处沉入里武林，唤出昔日败于你手的强敌留下的「残影」，再战一场。** 首领称作「残影」，和原作的意识设定一致。不打过就没有残影，这也自然解释了“只开放打过的首领”。

## 2. 入口（铃铛菜单新增一项）

| 位置 | 中文 | English |
|---|---|---|
| 菜单条目 | **强敌挑战** | **Boss Challenge** |
| 条目说明 | 沉入里武林，与昔日强敌的残影再较高下。<br>挑战你已击败过的首领。 | Sink into the Discordance and face the echoes of fallen foes.<br>Fight bosses you have already defeated. |
| 未解锁 | 尚无可唤出的残影。<br>击败任意首领后开放。 | No echoes linger yet.<br>Unlocks after you defeat a boss. |

## 3. 三种玩法

| 玩法 | 中文 | 标语 | English | Tagline |
|---|---|---|---|---|
| 单挑 | **单挑** | 择一强敌，重演旧日一战。<br>选一位已击败的首领，单独再打一次，可选难度。 | **DUEL** | Relive a duel of your choosing.<br>Pick one defeated boss and fight it again, at the difficulty you choose. |
| 连战 | **连战** | 强敌轮番登场，一气呵成，方为胜者。<br>按主题连续挑战一组首领，两战之间少量回血，倒下即失败。 | **GAUNTLET** | Foes come one after another; only an unbroken run counts.<br>Fight a themed group of bosses in a row. A little health returns between fights; fall once and the run ends. |
| Rogue | **试炼** | 前路无定，所悟亦无定。<br>每战之后从三条路中选一条，沿途获得随机心法，倒下即从头再来。 | **TRIAL** | No path holds still, no insight lasts.<br>After each fight, choose one of three paths and gain random Insights. Fall once and you start over. |

**说明文字一律两段式**（用户定稿）：第一行是文艺的一句，第二行是直白说明，讲清楚这一项做什么、有什么规则。界面上第二行用次一级的字色。

命名原则（用户定稿）：用直白的字，同一类文案字数一致。入口 4 字「强敌挑战」，三个玩法各 2 字「单挑 / 连战 / 试炼」，子菜单最后一项「返回」也是 2 字。「试炼」不用「轮回」，因为原作里「轮回」已经是周目（Cycle）的意思。

### 单挑的难度
直接复用原作的难度名和标语：入阵者 / 破局者 / 逆天者（WAYFARER / PATHBREAKER / HELLWALKER），运行时读游戏的本地化文本。

### 连战的关卡名（按首领分组，名字都取自原作设定）
| 关卡 | 中文 | English | 首领 |
|---|---|---|---|
| 1 | 灭法之法 | The Acolytes | 寒岁、炎茹、雷婷、蛊鹤 |
| 2 | 鬼差夜巡 | Shadow Wardens | 火流星、斩骑、勾魂、断肠 |
| 3 | 百戏偶人 | Puppet Theatre | 玉瓒、玉璧、玉鼎、玉琮 |
| 4 | 少主仪仗 | The Young Mistress | 玉妖、铁鬼、沐小葵 |
| 5 | 三面 | Three Masks | 金面、铁面、玉面郎君 |
| 6 | 组织高手 | Order's Finest | 长鸿、雷当、追命、左殇 |
| 7 | 生死两相 | Two Faces of Death | 各首领的一阶段直接接二阶段 |
| 8 | 江湖险恶 | Perils of the Wulin | 彭猛、荆野、万钧、武轩、荒行子 |
| 9 | 千影 | A Thousand Echoes | 所有已击败的首领，按剧情顺序 |

关卡标语沿用原作的对仗格式，例如「拂尘四扫，灭法之法」/ "Four whisks, four elements, one end."（定稿时逐关补齐）。

### 誓约（禁制）
原作没有对应的说法，取名「誓约」：自愿立下誓言来加难。英文用 VOWS。

| 誓约 | English | 效果 | 分值 |
|---|---|---|---|
| 铜皮铁骨 | IRON HIDE | 残影<Y>【生命值】</>提升 50% | 3 |
| 刀刀见血 | EVERY CUT BLEEDS | 残影<Y>【攻击力】</>提升 50% | 3 |
| 断药绝粮 | NO REMEDY | 无法使用<Y>药瓶</> | 3 |
| 孤军深入 | NO RESPITE | 两战之间不再回复 | 2 |
| 气竭 | SPENT CHI | <Y>杀气</>回复速度减半 | 2 |
| 刻不容缓 | AGAINST THE CLOCK | 每战须在<Y>{0}秒</>内取胜 | 2 |
| 一念生死 | ONE BREATH | 受到任何伤害即<Y>毙命</> | 5 |

立誓界面顶部显示：「誓约之重：{0}」 / "Weight of Vows: {0}"。

实现说明：断药绝粮、气竭两条还没找到游戏里对应的机制，第一版先不提供。立誓页每行写成「铜皮铁骨　✓　3」（名字、开关、分值）。

## 4. 试炼（Rogue）

**岔路**（每战之后三选一）

| 节点 | 中文 | 说明 | English | Note |
|---|---|---|---|---|
| 首领战 | 强敌 | 击败后可参悟一门心法 | FOE | Defeat it to gain an Insight. |
| 精英战 | 凶煞 | 残影凶性大发。击败后可参悟稀有心法 | DREAD FOE | A frenzied echo. Defeat it for a rare Insight. |
| 休息 | 调息 | 回复全部生命值，或精进一门心法 | RESPITE | Restore all HP, or deepen an Insight. |
| 事件 | 奇遇 | 祸福未知 | ENCOUNTER | Fortune or folly. |

**心法**（祝福，English: INSIGHTS）分三个境界：**初窥 → 小成 → 大成**（Novice / Adept / Master），这是武侠里常用的修为层级。同一流派集齐三门，触发「融会贯通」（MASTERY）。

| 流派 | 心法示例 | English |
|---|---|---|
| 杀气 | 气吞山河（杀气总量+）、生生不息（杀气回复+）、杀意凌然（破甲力+） | SWALLOW THE MOUNTAINS / ENDLESS BREATH / KILLING INTENT |
| 破势 | 势如破竹（破防+）、乘虚而入（处决阈值+） | SPLIT BAMBOO / STRIKE THE OPENING |
| 五行 | 烈火燎原、寒冰彻骨、雷霆万钧、万蛊噬心、血债血偿 | WILDFIRE / BONE-DEEP FROST / THUNDERCLAP / GU SWARM / BLOOD DEBT |
| 护体 | 金钟罩（生命总量+）、不动如山（减伤）、固若金汤（护盾） | GOLDEN BELL / UNMOVED MOUNTAIN / IMPREGNABLE |
| 绝技 | 厚积薄发（绝技充能+） | SLOW TO GATHER |
| 身法 | 踏雪无痕（移动速度+） | TRACELESS STEP |

心法说明按原作格式：先写一行效果（数值高亮），再写一句古风短文。例如：

> **金钟罩·小成**
> 生命总量提升 <Y>25%</>。
> 罡气护体，刀枪难入。

**残影的凶性**（精英词缀）：狂暴 FRENZIED、铁躯 IRONCLAD、不屈 UNYIELDING、再生 REGENERATING、附火 BLAZING。

**奇遇示例**：

> 「一尊无面石像，掌心托着一枚尚有余温的心脏。」
> ▸ 取走心脏 —— 失去一半生命值，参悟一门稀有心法
> ▸ 叩首离去 —— 无事发生

## 5. 战斗中与结算

| 场合 | 中文 | English |
|---|---|---|
| HUD | 连战·灭法之法　3 / 4　04:12 | GAUNTLET · The Acolytes　3 / 4　04:12 |
| 到达场地、首领出现前 | 强敌将至，准备迎战 | A foe approaches. Steel yourself. |
| 两战之间 | 残影将至。 | Another echo stirs. |
| 开战 | 残影现形 | THE ECHO TAKES FORM |
| 胜利 | 残影尽散 | THE ECHOES FADE |
| 失败 | 饮恨 | UNDYING GRUDGE（原作用词） |
| 退出（游戏菜单） | 强敌挑战 · 退出挑战 | Boss Challenge · Leave |
| 放弃结算标题 | 收刃离去 | Sheathe Your Blade |
| 用时 | 此战用时　最佳用时　新纪录！ | Time　Best Time　NEW RECORD! |
| 出错停用（提示条） | 强敌挑战出错，已停用，重启游戏后恢复 | Boss Challenge hit an error and is off until the game restarts |
| 返回 | 自里武林醒转，回到铃铛之侧。 | You stir from the Discordance and wake beside the Bell. |
| 试炼结算 | 前路已尽。<br>闯过 {0} 关，获得心法 {1} 门。 | The path runs out.<br>Cleared {0} stages and gained {1} Insights. |

## 6. 多语言规则

- 游戏语言是简体中文（zh-Hans 等）时显示上表中文；繁体（zh-Hant）时显示自动转换的繁体。转换表从游戏自己的简体、繁体对照文本中提取，所以用字和原作繁体版一致，比如「儲存記憶」。
- 其他语言一律显示 English。
- 首领名、难度名在运行时读游戏的本地化文本，所以游戏支持的 16 种语言都能显示正确的首领名。
- `<Y>` 是简写，实际使用原作的 `<Character_Yellow_Decorator2>` 标签。⚠ 能否渲染要看具体复用哪个控件，需要实测。

## 择地 / CHOOSE GROUND

| key | zh-Hans | en |
|---|---|---|
| arena.title | 择地 | Choose Ground |
| arena.origin | 原址 | Where It Began |
| arena.origin.desc | 回到当初交手之地。<br>在这位首领原本的战场开打（仅单挑）。 | Return to where you first crossed blades.<br>Fight on this boss's original battlefield (Duel only). |
| arena.scenic.desc | 择一处山水，了却旧怨。<br>在你到过的地点中选一处开打。 | Choose your ground and settle old scores.<br>Fight at a place you have already visited. |
| arena.jhsy | 镜花水月 | Realm of Mirage |
| arena.jhsy.desc | 镜中无昼夜，影亦无归处。<br>在镜花水月中开打，无需加载。 | No day or night within the mirror.<br>Fight inside the Realm of Mirage; no loading needed. |
| arena.locked | 尚未踏足此地 | You have yet to set foot here |
