# 预案：游戏本体更新与 DLC

草案 2026-11-14。目的：游戏一更新，先知道坏没坏、坏在哪一层，尽快让玩家知情，再按清单修，一轮测试验完。

当前基线（mod 0.1.5 测试时的游戏）：Steam app 4115450，buildid **26367565**，`PBZ.exe` CL-302256，UE 5.7。
本机 Steam 设为自动更新（`AutoUpdateBehavior 0`），更新会在不知情时到来。

## 1. mod 依赖游戏的五层，以及更新后各层怎么坏

| 层 | 依赖什么 | 更新后的典型坏法 | 谁来修 |
|---|---|---|---|
| A 二进制 | UE4SS 的 AOB 签名（`GUObjectArray`、`GNatives`）、`MemberVariableLayout.ini` | UE4SS 起不来或启动即崩，所有 Lua mod 都不加载 | 玩家用的是 KintaroModding 的 UE4SS（Nexus 前置）：等它更新；本机用 `src/ue4ss` 的签名，自己重找 |
| B 反射 | 类、函数、属性名：`W_BellMenu_C`.`TeleportBtn`、`wb_settlement_C`、`W_PBZSettingPanel_C`、`PBZSaveLoadSubsystem:TeleportTo`、`PBZGameSystem.CycleCount`、`AttributeSetBase.*`、两个 CommonUI 钩子 | 入口不出现、点了没反应、结算页空白；最坏是对已变的对象调用导致原生崩溃 | 我们 |
| C 内容 | `roster.lua` 的 Boss 类路径、名字、`helpers` / `summons` / `phases`；`arenas.lua` 的地图、铃铛 id、坐标；`CV_AttributeCurve_Monster_*` 曲线；难度配置 | Boss 生成失败或换了个怪；场地被改成墙里/悬空；铃铛 id 变了传不过去；数值偏了 | 我们 |
| D 行为 | 游戏 TypeScript 层（puerts）对铃铛菜单的处理：重写手柄导航、每次激活新建按钮组、返回键；加载画面 `WB_AdditionalLoading_C`；幻境死亡流程 | 光标跳不到我们的条目、确认键变成「穿行」、Boss 在加载画面里就开打 | 我们（AGENTS「gotchas」里每条都可能需要重新验证） |
| E 存档与周目 | `PBZGameSystem.CycleCount`、等级上限、曲线周期 25 级 | 新周目机制或等级上限改动后数值失真 | 我们 |

mod 自己的数据（`records.tsv`、`settings.tsv`）按 Boss id 存。id 改名会让旧战绩变成孤儿，但不出错。

## 2. 现在就做的准备（平时）

1. **启动体检**（`health.lua`，2026-11-15 做好，2026-11-16 实测通过：核心全部查到，注册表校准通过，117 项资源 0 缺失；F7 撤下 Boss、F8 停用并提示都正常）：玩家进入游戏后、铃铛入口出现之前，按名字把 mod 依赖的游戏部件查一遍，只读不改：
   - 原生类的函数、属性（`StaticFindObject` + 类自己的成员表，连父类一起）；四个 UI 蓝图（铃铛菜单、对话按钮、结算页、提示条）加载后查成员；
   - Boss 类、补点类、场地地图在**资源注册表**里查（`AssetRegistryImpl:K2_GetAssetByObjectPath`），不加载（加载 70 个 Boss 类要好几 GB 内存）。注册表先校准：已知存在的资源要查得到、编造的要查不到，当前地图也要查得到，才信它，否则这部分记为「未知」不查；
   - 结果分三种：有、缺、未知。只有确定「缺」才起作用：核心缺失 → mod 停用（`U.stop`，走出错停用同一条路），提示条「游戏已更新，残影试炼暂停，待 mod 更新后恢复」；Boss 类或补点缺失 → 这个 Boss 不提供；地图缺失 → 这个场地不用；系统菜单那一行、加载画面、出场特效缺失 → 只记日志。未知一律当作存在，不凭猜测藏内容；
   - 体检通过前不插铃铛入口。结果摘要每次都写进 `UE4SS.log`（发布版也写，以 `[BossRush] health:` 开头），玩家发来日志即可知道坏在哪；
   - 清单在 `health.lua` 的 `NATIVE` / `WIDGETS` / `OPTIONAL_ASSETS`：**新加一处对游戏类的调用，就把它加进清单**。清单里的类名、模块名、成员名用 `CXXHeaderDump` 核对过（2026-11-15，全部存在）；
   - 开发版 F7 假装第一个开放 Boss 不在游戏里（它从列表消失），F8 假装缺一个核心部件（mod 停用并提示），不等真的更新就能看停用路径。
2. **记下测试过的版本**：`health.lua` 的 `TESTED_BUILD`（当前 26367565）。启动时读 Steam 的 `appmanifest_4115450.acf`（mod 文件夹往上七层的 `steamapps\`；读不到就跳过，不猜），日志写一行「game build X (tested with Y)」，不一致只多一句提醒，不打扰玩家（体检才决定能不能用）。每次发版更新这个值。
3. **离线差异工具**（待做，`src/tools/game_diff.py`）：用 pbzero 读新旧两份 `utoc`，对比
   - roster 和 arenas 里每个类路径、地图路径是否还在；
   - 每个 Boss 的能力里查找关卡物件的方式（`asset_scan.py deps`）有没有变化，新增的查找要重新判 `helpers` / `anchored`；
   - 成长曲线和难度配置的数值；
   - `Mobs/` 下新出现的目录、`DT_CodexEnemyDataTable` 新增的行（= 新 Boss 候选）；
   - 我们用到的控件蓝图（`W_BellMenu`、`wb_settlement`、`WB_TipsText`、设置面板）的依赖表是否变了。
   旧版本只需保存一份「快照」（上面各项的清单和哈希，存在 `src/data/game_snapshot/<buildid>.json`），不用留整个旧 pak。
4. **固定冒烟测试清单**（本文 §7），每次更新都跑同一份，一轮答完。
5. **CXXHeaderDump 留底**（2026-11-16 做好）：`python src\tools\header_baseline.py` 把体检清单里的每个类（连同父类，去掉偏移量）从头文件里抄进 `src/data/game_baseline/<buildid>.txt`，当前是 `26367565.txt`（50 个类；`wb_settlement` 生成头文件时没加载，不在里面）。游戏更新后：在游戏里打开铃铛、打完一场（让蓝图加载），按 Ctrl+H 重新生成头文件，再跑一次这个工具，然后 `header_baseline.py diff` 对比新旧两份，类和成员的增删改名一眼可见。头文件比游戏的最后更新时间旧时工具会拒绝，免得把旧 dump 当成新版本。
6. **发版自动核对版本号**（2026-11-16 做好）：`build_release.py` 读本机 Steam 的 buildid，和 `TESTED_BUILD` 不一致就不出包。

## 3. 更新那天的流程

1. **先别开存档**：备份存档（`save-backup/`）。更新可能改存档格式，mod 不写存档，但测试会推进进度。
2. **看 UE4SS 是否起来**（A 层）：启动游戏看 `UE4SS.log`。
   - 没起来：玩家那边要等 KintaroModding 的 UE4SS 更新。我们立刻在 Nexus 置顶说明（模板见 §5），本机按 AGENTS「Investigating」的方法重找签名，以便先修我们自己这层。
3. **对比头文件**（B 层）：打开铃铛、打完一场，Ctrl+H，`header_baseline.py` 再 `header_baseline.py diff`（见 §2.5）。
4. **看体检表**（B、C 层）：`UE4SS.log` 里 `[BossRush] health:` 开头的几行就是坏点清单（`MISSING:` 是核心，`left out` 是被撤下的 Boss 和场地）。
5. **跑离线差异**（C 层）：`game_diff.py` 列出变化，逐项判断（工具待做）。
6. **按 §4 分级处理**，修好后跑 §7 冒烟测试。
7. **发版**：版本说明写明「适配游戏 buildid xxx」；`health.lua` 的 `TESTED_BUILD` 更新（不更新 `build_release.py` 不出包）；新版本的头文件基线一起提交。教训照规矩写回 AGENTS / DESIGN。

## 4. 分级

| 级别 | 现象 | 玩家侧 | 我们的动作 |
|---|---|---|---|
| P0 | 游戏启动即崩、存档相关异常 | 置顶：先删掉 `Mods\BossRush` 或禁用 UE4SS | 当天定位；若是 UE4SS 层，跟进前置作者 |
| P1 | 体检判核心缺失，入口不出现 | 游戏正常，mod 自停并有提示 | 修反射层，发修复版 |
| P2 | 单个 Boss / 场地坏 | 该项自动不提供 | 下一轮常规版本修；roster 里可临时改 `state` |
| P3 | 数值、音乐、手感偏差 | 照常可玩 | 记入待办 |

## 5. 玩家公告模板（Nexus 置顶 / 小黑盒）

> 游戏已更新到 <版本>。残影试炼尚未适配：<现象>。在更新前请 <删除 Mods\BossRush / 暂时不进入残影试炼>。适配后会在此更新。
>
> The game was updated to <version>. Trial of Echoes is not yet updated for it: <symptom>. Until then, please <remove Mods\BossRush / avoid the trial>. This post will be updated.

## 6. DLC 额外要处理的

1. **新 Boss**：codex 新行 + `Mobs/` 新目录 → `gen_roster.py`（`bosses.json` 需要 pbzero 先更新）→ `asset_scan.py deps` 判补点 → 以 `testing` 上线，用户实测后改 `open`（既有规矩）。名字以血条为准。
2. **没买 DLC 的玩家**：DLC 资源可能在 pak 里但不应提供。roster 加 `dlc = "<名字>"` 字段，运行时要有可靠的拥有判断才提供。**待查**：游戏用什么判断拥有（Steam DLC 检查函数、存档标记，还是资源单独打包、未购则不存在）。在查清前，DLC Boss 只在开发版出现。
3. **新地图 / 新场地**：F2 标点、F3 测量、按 DESIGN §5.0a 打分（既有流程）。新地图的铃铛 id 进 `bells.tsv`。
4. **等级上限 / 新周目**：若曲线延长或周期变了，重读曲线，改 `scale.lua` 的 `LEVELS_PER_CYCLE` / `MAX_LEVEL`。
5. **新的场景依赖类型**：本 mod 已知三种查找（`GetActorOfClass`、targeting 子系统、身份点标签）。新 Boss 若在 `testing` 中出现瞬移到原点、带玩家去别的关卡，按第四种来查。
6. **新语言**：若加了 UI 语言，`i18n` 只有 zh-Hans / English，其余回落英文，不出错即可。

## 7. 冒烟测试清单（每次更新同一份，键盘 + 手柄各一遍）

1. 进游戏，`UE4SS.log` 有 `loaded (...)` 行，`health:` 摘要是 0 core parts missing、0 bosses、0 arenas left out。
2. 打开铃铛：残影试炼在穿行下方，手柄上下能经过它，确认键进入（不是穿行）。返回键回到铃铛菜单而不是关掉。
3. 离开再打开铃铛、从穿行回来：条目还在，选中状态正确。
4. 单战：开一场，加载完后有宽限再出 Boss；打赢 → 结算页标题、数值、版本号都对；回到起点、状态恢复。
5. 连战：开一场，中途在系统菜单「退出挑战」，回到起点、状态恢复。
6. 补点 Boss（如 玉瓒、碧海大师）一只、多阶段 Boss（如 追命）一只、召唤物 Boss（舞狮尊主）一只。
7. 残影档位：设置页能切，开战后血量与档位相符。
8. 幻境场地一场（含死亡），`own` 场地一场（龙柱）。
9. 二周目存档（若有）：Boss 等级与原生怪接近。
