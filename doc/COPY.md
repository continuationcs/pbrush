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
| 菜单条目 | **残影试炼** | **Trial of Echoes** |
| 条目说明 | 沉入里武林，与昔日强敌的残影再较高下。<br>挑战你已击败过的首领。 | Sink into the Discordance and face the echoes of fallen foes.<br>Fight bosses you have already defeated. |
| 未解锁 | 尚无可唤出的残影。<br>击败任意首领后开放。 | No echoes linger yet.<br>Unlocks after you defeat a boss. |

## 3. 三种玩法

| 玩法 | 中文 | 标语 | English | Tagline |
|---|---|---|---|---|
| 单挑 | **单挑** | 择一强敌，重演旧日一战。<br>选一位已击败的首领，单独再打一次，可选难度。 | **DUEL** | Relive a duel of your choosing.<br>Pick one defeated boss and fight it again, at the difficulty you choose. |
| 连战 | **连战** | 强敌轮番登场，一气呵成，方为胜者。<br>按主题连续挑战一组首领，两战之间少量回血，倒下即失败。 | **GAUNTLET** | Foes come one after another; only an unbroken run counts.<br>Fight a themed group of bosses in a row. A little health returns between fights; fall once and the run ends. |
| Rogue | **万象** | 前路无定，所悟亦无定。<br>每战之后从三条路中选一条，沿途获得随机心法，倒下即从头再来。 | **MYRIAD** | No path holds still, no insight lasts.<br>After each fight, choose one of three paths and gain random Insights. Fall once and you start over. |

**说明文字一律两段式**（用户定稿）：第一行是文艺的一句，第二行是直白说明，讲清楚这一项做什么、有什么规则。界面上第二行用次一级的字色。

命名原则（用户定稿）：用直白的字，同一类文案字数一致。入口 4 字「残影试炼」（2026-11-14 用户改名，原为「强敌挑战 / Boss Challenge」），三个玩法各 2 字「单挑 / 连战 / 万象」，子菜单最后一项「返回」也是 2 字。「万象」原名「试炼」：入口改名「残影试炼」后两者重名，2026-11-14 用户改名为「万象 / MYRIAD」（每局路线、首领、心法都不同）。不用「轮回」，因为原作里「轮回」已经是周目（Cycle）的意思。

### 单挑的难度
直接复用原作的难度名和标语：入阵者 / 破局者 / 逆天者（WAYFARER / PATHBREAKER / HELLWALKER），运行时读游戏的本地化文本。

### 连战的关卡名（按首领分组，名字都取自原作设定）
| 关卡 | 中文 | English | 首领 |
|---|---|---|---|
| 1 | 灭法之法 | The Acolytes | 寒岁、炎茹、雷婷、蛊鹤 |
| 2 | 鬼差夜巡 | Shadow Wardens | 斩骑 → 勾魂 → 断肠 → 火流星（含二阶段磷火意识） |
| 3 | 百戏偶人 | Puppet Theatre | 玉瓒 → 玉璧 → 玉鼎 → 玉琮（二阶段钢刃、寒冰、混沌同时出现） |
| 4 | 少主仪仗 | The Young Mistress | 玉妖 → 铁鬼 → 沐小葵（含二阶段铁玉女王） |
| 5 | 金铁玉面 | Three Masks | 金面 → 铁面 → 玉面郎君 |
| 6 | 组织高手 | Order's Finest | 追命 → 雷当 → 长鸿 → 左殇（银发） |
| 7 | 江湖险恶 | Perils of the Wulin | 彭猛 → 荆野 → 万钧 → 武轩 → 荒行子 |
| 8 | 痴狂众生 | Madmen of the Wulin | 残钢 → 铁杀 → 奎艳艳 → 铁狂 → 花千笑 |
| 9 | 妖异志怪 | Strange Tales | 新娘阿花 → 骨婉约 → 小雪 → 烟千岁 → 梦华圣母 |
| 10 | 沙场宿将 | Veterans of War | 祝原 → 独眼弓客 → 囚锋 → 毕峰 → 武轩 |
| 11 | 名门残影 | Shadows of the Sects | 拙壁 → 碧海残躯 → 毕远残躯 → 七星剑阵大师兄（二阶段大师兄的绝望剑意和红衣女剑客同时出现） |
| 12 | 千影归来 | A Thousand Echoes | 全部开放的首领，按出场顺序 |

**2026-11-14 重排（用户决定）**：每组 4～5 场，按顺序越打越强、最强或最终形态压轴；新开放的火流星、玉瓒、左殇（银发）补进原定的组；生死两相限 5 对；新增痴狂众生、妖异志怪、沙场宿将、名门残影（成员按首领名号归类，未必对应剧情阵营）；组名统一为 4 字（三面 → 金铁玉面，千影 → 千影归来）。灭法之法四人未开放，这一组暂不提供。连战页和单挑页一样分页，每页 8 组。

**多阶段首领合并（用户决定，2026-11-14）**：多阶段的首领只占一行，以一阶段命名，选中后各阶段连着打：阶段之间不回血，只提示「第二阶段」（英文 Second Phase，`i18n.phase`）。玉琮二阶段是钢刃、寒冰、混沌三个同时出现；金面具黑衣人二阶段是魔渊；七星剑阵：大师兄二阶段是大师兄的绝望剑意和红衣女剑客同时出现（同日用户决定；红衣女剑客实测确认。首领表原把「七星剑阵：大师兄」记在一个实际是红衣女剑客的类上，改用华山的 HuaShan_Blue，实测确认）。生死两相（一阶段接二阶段）因此与其他组重复，已删除，连战共 11 组。组织高手、江湖险恶等组里的多阶段首领也都打完全部阶段。

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

## 4. 万象（Rogue，设计中，待拍板）

**岔路**（每战之后三选一）

| 节点 | 中文 | 说明 | English | Note |
|---|---|---|---|---|
| 首领战 | 强敌 | 击败后可参悟一门心法 | FOE | Defeat it to gain an Insight. |
| 精英战 | 凶煞 | 残影凶性大发。击败后可参悟稀有心法 | DREAD FOE | A frenzied echo. Defeat it for a rare Insight. |
| 休息 | 调息 | 回复全部生命值，或精进一门心法 | RESPITE | Restore all HP, or deepen an Insight. |
| 事件 | 奇遇 | 祸福未知 | ENCOUNTER | Fortune or folly. |

**心法**（祝福，English: INSIGHTS）分三个境界：**初窥 → 小成 → 大成**（Novice / Adept / Master），这是武侠里常用的修为层级。同一流派两门都到大成，触发「融会贯通」（MASTERY）。流派名 2 字，心法名 4 字。效果和实现见 DESIGN §12.3。

| 流派 | 心法 | English | 效果 |
|---|---|---|---|
| 护体 GUARD | 金钟铁布 | GOLDEN BELL | 生命上限 + |
| 护体 | 不动如山 | UNMOVED MOUNTAIN | 受到的伤害 − |
| 杀气 SHA-CHI | 气吞山河 | SWALLOW THE MOUNTAINS | 杀气上限 + |
| 杀气 | 生生不息 | ENDLESS BREATH | 杀气回复 + |
| 破势 BREAK | 势如破竹 | SPLIT BAMBOO | 破势伤害 + |
| 破势 | 乘虚而入 | STRIKE THE OPENING | 破势后硬直 + |
| 锋锐 EDGE | 削铁如泥 | CLEAVE IRON | 攻击力 + |
| 锋锐 | 锋芒毕露 | BARED EDGE | 物理伤害 + |
| 调元 BREATH | 厚积薄发 | SLOW TO GATHER | 绝技充能 + |
| 调元 | 吐故纳新 | EXHALE THE OLD | 胜后回复生命 |

（五行、身法两派先不做：读不出武器元素、没找到移动速度属性。）

心法说明按原作格式：先一句古风短文，再一行效果（数值高亮），例如：

> **金钟铁布·小成**
> 罡气护体，刀枪难入。
> 生命上限提升 <Y>30%</>。

**残影的凶性**（凶煞的词缀，2 字）：狂暴 FRENZIED、铁躯 IRONCLAD、再生 REGENERATING、杀意 RELENTLESS。

**奇遇示例**：

> 「一尊无面石像，掌心托着一枚尚有余温的心脏。」
> ▸ 取走心脏 —— 失去一半生命值，参悟一门稀有心法
> ▸ 叩首离去 —— 无事发生

## 5. 战斗中与结算

| 场合 | 中文 | English |
|---|---|---|
| HUD | 连战·灭法之法　3 / 4　04:12 | GAUNTLET · The Acolytes　3 / 4　04:12 |
| 到达场地、首领出现前（加载界面消失后显示 3 秒，然后首领出现） | 强敌将至，准备迎战 | A foe approaches. Steel yourself. |
| 场地被原生首领占着，换一处 | 此地已有强敌盘踞，另觅战场 | A foe already holds this ground. Seeking another. |
| 专属战场被首领本尊占着，不打 | 此地强敌本尊尚在，本周目击败后再来 | The foe itself still holds this ground. Defeat it in this playthrough first. |
| 两战之间（带「第几场 / 共几场」） | 残影将至　2 / 4 | Another echo stirs　2 / 4 |
| 同一首领进入下一阶段 | 第二阶段（第三阶段……） | Second Phase (Third Phase …) |
| 开战 | 残影现形 | THE ECHO TAKES FORM |
| 胜利 | 残影尽散 | THE ECHOES FADE |
| 失败 | 饮恨 | UNDYING GRUDGE（原作用词） |
| 退出（游戏菜单） | 残影试炼 · 退出挑战 | Trial of Echoes · Leave |
| 放弃结算标题 | 收刃离去 | Sheathe Your Blade |
| 用时 | 用时　最佳　新纪录！ | Time　Best　NEW RECORD! |
| 结算标题下的小字行 | 残影试炼 0.1.5（入口名 + mod 版本号，开发版显示 dev） | Trial of Echoes 0.1.5 |
| 结算第三行 | 击败　难度（入阵者 / 破局者 / 逆天者 / 六十六天） | Defeated　Difficulty (Wayfarer / Pathbreaker / Hellwalker / 66 Days) |
| 出错停用（提示条） | 残影试炼出错，已停用，重启游戏后恢复 | Trial of Echoes hit an error and is off until the game restarts |
| 返回 | 按确认键，自里武林醒转，回到铃铛之侧。 | Press confirm to stir from the Discordance and wake beside the Bell. |
| 万象结算 | 前路已尽（打完全部关）。<br>闯过 {0} / {1} 关，心法 {2} 门。 | The Path Ends.<br>Cleared {0} / {1} stages, {2} Insights. |
| 万象每关开战 | 第 {0} / {1} 关 · 凶煞 · 铁躯 | Stage {0} / {1} · Dread Foe · Ironclad |

## 6. 多语言规则

- 游戏语言是简体中文（zh-Hans 等）时显示上表中文；繁体（zh-Hant）时显示自动转换的繁体。转换表从游戏自己的简体、繁体对照文本中提取，所以用字和原作繁体版一致，比如「儲存記憶」。
- 其他语言一律显示 English。
- 首领名、难度名在运行时读游戏的本地化文本，所以游戏支持的 16 种语言都能显示正确的首领名。
- `<Y>` 是简写，实际使用原作的 `<Character_Yellow_Decorator2>` 标签。⚠ 能否渲染要看具体复用哪个控件，需要实测。

## 择地 / CHOOSE GROUND

| key | zh-Hans | en |
|---|---|---|
| arena.title | 择地 | Choose Ground |
| arena.scenic.desc | 择一处山水，了却旧怨。<br>在你到过的地点中选一处开打。 | Choose your ground and settle old scores.<br>Fight at a place you have already visited. |
| arena.jhsy | 镜花水月 | Realm of Mirage |
| arena.jhsy.desc | 镜中无昼夜，影亦无归处。<br>在镜花水月中开打，无需加载。 | No day or night within the mirror.<br>Fight inside the Realm of Mirage; no loading needed. |
| arena.locked | 尚未踏足此地 | You have yet to set foot here |
