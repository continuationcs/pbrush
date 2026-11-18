import json
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / 'mod' / 'BossRush' / 'Scripts'
b = json.load(open(r'F:\C\pbzero\src\pbzero\data\bosses.json', encoding='utf-8'))['bosses']
# Bosses that cannot be fought outside their own level and stay closed (state "anchored", exact ids): none since
# 2026-11-18, when 冷荼 opened. Level-dependent bosses are fought with helper points (HELPERS) and the run's
# identity points; a new one found by asset_scan.py deps (DESIGN 5.2, UPDATE.md) goes here until it has them.
anchored = []
story = ['Tutorial', 'HorseCart', 'Prologue']

# Codex entry 013 has three parts: 红衣女剑客 (BossName_013_0), 七星剑阵：大师兄 (_1), 大师兄的绝望剑意 (_2). bosses.json
# gives part 1's name to BP_Monster_EMei_Sword_JianZhen, but in game that class is a 红衣女剑客 (its health bar says
# so, user test 2026-11-14). 大师兄 is taken to be BP_Monster_HuaShan_Blue: 绝望剑意 is a 华山 class too, the
# cutscene of that fight (Seq076) uses HuaShan_Blue, and it has no level lookups; confirmed in game 2026-11-14.
# CLASS_FIX: bosses.json record -> the class that really carries its name.
CLASS_FIX = {
    'BP_Monster_EMei_Sword_JianZhen': ('BP_Monster_HuaShan_Blue', '/PBZCombatAsset/ActorData/Mobs/035_HuaShan/'
                                       'BP_Monster_HuaShan_Blue.BP_Monster_HuaShan_Blue_C'),
    # bosses.json gives 荡秽 the class BP_Monster_Danghui_StuntDouble (a stand-in), which flew to 0,0,0 even with
    # its centre point placed (autotest 2026-11-13). The level's spawner cell names BP_Monster_Danghui
    # (asset_scan.py maps); the stand-in appears only in the PSO warm-up map. Tried from 2026-11-15.
    'BP_Monster_Danghui': ('BP_Monster_Danghui', '/PBZCombatAsset/ActorData/Mobs/DangHui/'
                           'BP_Monster_Danghui.BP_Monster_Danghui_C'),
}
for x in b:
    if x['id'] in CLASS_FIX:
        x['id'], x['class_path'] = CLASS_FIX[x['id']]

# Bosses the codex names but bosses.json leaves out, inserted after the record named in `after`. 红衣女剑客:
# BP_Monster_EMei_Sword_Top (the codex's female sword-sect elite, no level lookups); confirmed in game 2026-11-14
# (health bar 红衣女剑客). Her English codex name is in the en-US locres, not read here.
EXTRA = [
    {'after': 'BP_Monster_HuaShan_JianOu', 'id': 'BP_Monster_EMei_Sword_Top', 'name': '红衣女剑客',
     'name_en': 'The Red-Robed Swordswoman',
     'class_path': '/PBZCombatAsset/ActorData/Mobs/034_EMei/BP_Monster_EMei_Sword_Top.BP_Monster_EMei_Sword_Top_C'},
    # 风雪刀客 (user, 2026-11-15): not in the codex data at all, found offline in ActorData/Mobs/FengXueDaoKe (the
    # _NPC class is its story variant). Its fight lights the bell 白影陨落之处 (DESIGN 5.1). Placed after 毕峰 (the
    # codex order is unknown); English name provisional until the user gives the in-game one.
    {'after': 'BP_Monster_GreatBladeMan', 'id': 'BP_Monster_FengXueDaoKe', 'name': '风雪刀客',
     'name_en': 'The Snowstorm Blade',
     'class_path': '/PBZCombatAsset/ActorData/Mobs/FengXueDaoKe/BP_Monster_FengXueDaoKe.BP_Monster_FengXueDaoKe_C'},
]
for x in EXTRA:
    i = next(i for i, y in enumerate(b) if y['id'] == x['after'])
    b.insert(i + 1, {k: v for k, v in x.items() if k != 'after'})

# Helper points the mod places in the arena before the boss spawns (and removes after), so a level-dependent boss
# can be fought anywhere (DESIGN 5.2, "补点"). Each is (class path, forward cm, right cm) from the arena centre
# along the arena facing, put on the navigation mesh. Which classes each boss needs comes from its abilities
# (GetActorOfClass / targeting subsystem lookups, offline scan 2026-11-13); all are root-only marker actors.
M = '/PBZCombatAsset/ActorData/Mobs/'
GUICHAI = M + '069_GuiChai_Red/Setup/BP_Monster_GuiChai_Red_'
# CA_02 snaps to its snap point; CA_03 (the leap) to its snap point and lands on its landing point; GEd_01 reads the
# domain centre. GEx_01 (the roof chop, BP_ZuoShang_House) belongs to the prologue boss only. The original layout
# is not known: all at the centre.
ZUOSHANG = [(M + '054_ZuoShang/' + n + '.' + n + '_C', 0, 0) for n in (
    'BP_ZuoShang_CA_02_SnapPoint', 'BP_ZuoShang_CA_03_SnapPoint', 'BP_ZuoShang_CA_03_LandingPoint',
    'BP_ZuoShang_CA_03_DomainCenter')]
HELPERS = {
    'BP_Monster_YuBi': [(M + 'YuBi/BP_YuBi_SnapPoint.BP_YuBi_SnapPoint_C', 0, 0)],
    'BP_Monster_MengHua': [(M + '078_MengHua/BP_MengHua_XuKong_SnapPoint.BP_MengHua_XuKong_SnapPoint_C', 0, 0)],
    'BP_Monster_FemaleVessel_YuZan': [(M + '068_YuZan/BP_YuZan_CA_Snap_Center.BP_YuZan_CA_Snap_Center_C', 0, 0)],
    'BP_Monster_DuYanBoss': [(M + '059_DuYan/BP_DuYan_CA_Snap_Center.BP_DuYan_CA_Snap_Center_C', 0, 0)],
    'BP_Monster_YanQianSui': [(M + '073_YanQianSui/BP_YanQianSui_SnapPoint.BP_YanQianSui_SnapPoint_C', 0, 0)],
    'BP_Monster_CanQu_BiHai': [(M + 'CanQu_BiHai/Ability/Passive/BP_Monster_CanQu_BiHai_ToCenter.'
                                'BP_Monster_CanQu_BiHai_ToCenter_C', 0, 0)],
    # Its passive summons twin-blade ghosts at the summon points and snaps them to the snap points. The original
    # layout is not known: snap points 4 m left and right of where the boss stands (8 m ahead), summon points 8 m.
    'BP_Monster_GuiChai_Red': [(GUICHAI + 'SnapPoint_01.BP_Monster_GuiChai_Red_SnapPoint_01_C', 800, -400),
                               (GUICHAI + 'SnapPoint_02.BP_Monster_GuiChai_Red_SnapPoint_02_C', 800, 400),
                               (GUICHAI + 'SummonPoint_01.BP_Monster_GuiChai_Red_SummonPoint_01_C', 800, -800),
                               (GUICHAI + 'SummonPoint_02.BP_Monster_GuiChai_Red_SummonPoint_02_C', 800, 800)],
    # CA_03 snaps to the centre and looks up the snake spawners through the targeting subsystem; each spawner
    # spawns its own destructible snake. The original count and layout are not known: four, 10 m around.
    'BP_Monster_ChiLian_P2': [(M + '065_ChiLian_P2/BP_ChiLian_P2_Center.BP_ChiLian_P2_Center_C', 0, 0)] + [
        (M + '065_ChiLian_P2/BP_ChiLian_CA_SnakeSpawner.BP_ChiLian_CA_SnakeSpawner_C', f, r)
        for f, r in ((1000, 0), (-1000, 0), (0, 1000), (0, -1000))],
    'BP_Monster_ZuoShang_Ending': ZUOSHANG,
    # 组织冥主：左殇 (black-haired, fought in 竹林故屋) uses the same skills as the silver-haired one. GEx_01 (the roof
    # chop) also reads its spawner and BP_ZuoShang_House: not placed, the log will tell whether it is used.
    'BP_Monster_ZuoShang': ZUOSHANG,
    # 寒岁: ShowUp snaps to BP_Monster_GuiChai_Red_SnapPoint_01, the summon passive to its own snap and summon
    # points (scavengers). Original layout not known: where the boss stands (8 m ahead), the summon point 5 m aside.
    'BP_Monster_QiShu_Bing': [(GUICHAI + 'SnapPoint_01.BP_Monster_GuiChai_Red_SnapPoint_01_C', 800, 0),
                              (M + 'QiShu/ShowUp/BP_Monster_QiShu_SnapPoint_01.BP_Monster_QiShu_SnapPoint_01_C', 800, 0),
                              (M + 'QiShu/ShowUp/BP_Monster_QiShu_SummonPoint_01.BP_Monster_QiShu_SummonPoint_01_C',
                               800, 500)],
    # 荡秽: its summon attack (GA_DangHui_SummonAttack) looks up the centre point.
    'BP_Monster_Danghui': [(M + 'DangHui/Ability/Passive/BP_Monster_DangHui_ToCenter.BP_Monster_DangHui_ToCenter_C',
                            0, 0)],
    # 冷荼: GA_LengTu_ToBattle_Teleport and GA_LengTu_SwitchPhase_Teleport snap it to their points (entrance, each
    # phase change); its summon passives put their bosses on the summon slots (P1 slot 01, P2-P4 slots 02 and 03).
    # All sit in 断魂崖's persistent level (PBZ_Duanhun_WP, asset_scan.py maps 2026-11-17). The original layout is
    # not known: both snap points where the boss stands (12 m ahead), slot 01 4 m behind it, 02 / 03 8 m aside.
    'BP_Monster_LengTu': [(M + '077_LengTu/' + n + '.' + n + '_C', f, r) for n, f, r in (
        ('BP_LengTu_ToBattle_SnapPoint', 1200, 0), ('BP_LengTu_SwitchPhase_SnapPoint', 1200, 0),
        ('BP_LengTu_SummonSlot_01', 1600, 0), ('BP_LengTu_SummonSlot_02', 1200, -800),
        ('BP_LengTu_SummonSlot_03', 1200, 800))],
}

# Summons scaled like their boss (the game sizes some of their values from the boss's, see run.lua check_summons);
# the run also forces their Kill when they wait at 0 HP for an execution, and logs their state. LionDancer_P2's
# last lion head (tag HouHouHou.LastOne) could not be hurt or executed while only the boss was scaled, so the boss
# could not die (Nexus, 0.1.1; cause found 2026-11-13).
# 小雪's thugs (summoned through SUMMON_PASSIVE): scaled like her, as the level's own fight would size them.
SUMMONS = {
    'BP_Monster_LionDancer_P2': ['BP_Monster_DaTouWaWa_HouHouHou_C'],
    'BP_Monster_XiaoXue': ['BP_Monster_FemaleThug_%s_ForXiaoXue_C' % k
                           for k in ('Fuhuai', 'BigKnife', 'Dart', 'Hoe', 'Molotov', 'RongZhuang', 'TwinHoe')],
    # 冷荼 summons a boss or two in each of its five phases (its GA_LengTu_SummonPassive_P1..P5, offline 2026-11-17);
    # none is placed in any map, so its passives spawn them. Scaled like it, as its level's fight would size them.
    'BP_Monster_LengTu': ['BP_Monster_%s_C' % k for k in (
        'Scavenger_LengTu', 'PengMeng_Axe_NPC', 'GuiChai_Cyan_ShuangYue_LengTu', 'GuiChai_Yellow_MoDao_LengTu',
        'HuaShan_Blue_NPC', 'EMei_Sword_NPC', 'FengXueDaoKe_NPC', 'FemaleVessel_YuDing_LengTu', 'YuBi_LengTu',
        'FemaleDoll_Golden_LengTu', 'FemaleDoll_TieChiSan_LengTu', 'LionDancer_P2_NPC', 'LeiDang_NPC')],
}

# A summon passive the boss's level grants it, and the gameplay event that makes it summon. A spawned 小雪 had 22
# abilities and no GA_SummonPassive_XiaoXue, so her thugs never came (Nexus report 2026-11-16: she ate corpses no
# one could see). Granted and activated it waited for its SummonEventTag; with GameplayEvent.SelfSummon sent to her,
# four of the seven thugs appeared around her (SummonInfos: one each, at most 4, within 9 m), gave no loot or
# Remnant Dust and were gone after the run (development probe, user test 2026-11-16).
SUMMON_PASSIVE = {
    'BP_Monster_XiaoXue': ('/PBZCombatAsset/ActorData/Mobs/027_XiaoXue/Ability/GA_SummonPassive_XiaoXue.'
                           'GA_SummonPassive_XiaoXue_C', 'GameplayEvent.SelfSummon'),
}

# Gameplay tags the development log follows on a boss: their counts at spawn and each change during the fight. 冷荼 starts in phase 4 with a save whose story fight got that far and in phase 1
# with an early 二周目 save (Phase.P4 / P1 before scaling: not the scaling, 2026-11-18). Its spawn passive
# (GA_LengTu_GeneralSpawn_Passive) knows the Save.P2-P4 tags, and BP_Monster_LengTu names the record id
# LengTu_Combat, which only the phase-4 save holds (UPBZLevelActorManager.ActorSaveData). Not on 冷荼 or the player,
# not in its flow component's record, not its StateId (None). Tags read offline from its assets' name maps.
WATCH_TAGS = {
    'BP_Monster_LengTu': ['CharacterState.AbilityState.LengTu.' + t for t in (
        'Save.P2', 'Save.P3', 'Save.P4', 'Phase.P1', 'Phase.P2', 'Phase.P3', 'Phase.P4', 'Phase.P5', 'Phase.Final',
        'FirstTimeSummon', 'IsInvulnerable', 'OffCombat', 'EnableMetaAI', 'HasBindingWire')],
}

# Abilities the run takes from the boss (class names). 小雪's GA_XiaoXue_RecoverHealth, picked by her AI from her
# health, healed her by up to a fifth of her health, twice to full (user decision 2026-11-16: removed).
REMOVE_ABILITIES = {
    'BP_Monster_XiaoXue': ['GA_XiaoXue_RecoverHealth_C'],
}

# Bosses whose health floor (Health_Min) the run sets to 0: it stays above 0 outside their level, so they cannot
# die. 魔渊 in a 二周目 started at Health_Min 24 and could not be killed (Nexus report on 0.1.4, mastersoul2).
# 组织冥主：左殇 (black-haired): its story fight sets Health_Min to 80, 60 and 40% of its base 8000 in turn (6400,
# 4800, 3200); it could not be killed until each was cleared (user tests 2026-11-15).
# 悲痛欲绝的阿瑾 (HuaShan_RedTroop_BigBro): its passive GA_HuaShan_RedTroop_BigBro_Passive applies GE_LockHealth
# (Health_Min, CharacterState.CanNotBeExecuted) and watches the tag CharacterState.AbilityState.HuaShan.RedTroop.
# SoldierDead: in its story fight the lock goes with the red troop's soldiers, who are not there in a run. Health_Min
# read 0 at spawn (the passive applies it later); the player could not kill it, god mode one-hit kills included
# (user test 2026-11-15; read offline from the passive's and the effect's name maps). With the floor cleared it fell
# to 0, waited there (the effect also forbids execution), the forced Kill ended it and the run won (2026-11-15).
CLEAR_HEALTH_MIN = ['BP_Monster_MoTian', 'BP_Monster_ZuoShang', 'BP_Monster_HuaShan_RedTroop_BigBro']

# Bosses that push the boss-defeat banner (W_BossDead, the 斩 effect) themselves: their AI config carries
# AIScript_ShowUIAfterCombat, which pushes it on death, and comes with the spawned actor. The others get it in the
# game from their level's story flow graph (BPF_*Death), which a spawned boss never triggers, or not at all; the run
# pushes it for them (run.lua banner_due). Found offline 2026-11-17: BP_Monster_X (or its parent blueprint:
# GreatBladeMan -> XDaoDuiZhang_Base, YanYan_Club -> YanYan_Base) names ActorC_*, which names AIConfig_*, which
# names the script (asset_scan.py names). Check again after a game update.
NATIVE_BANNER = ['BP_Monster_' + n for n in (
    'PengMeng_Axe', 'AHua_GuiTouDao', 'HuaQianXIao', 'JingYe', 'ChiLian_P2', 'GuiChai_Red_P2', 'GuiChai_Yellow_MoDao',
    'GuiChai_Yellow_ShuangGou', 'GuiChai_Cyan_ShuangYue', 'HuoDaoDuiZhang', 'GreatBladeMan', 'WuXuan',
    'Maddoctor_Elite', 'QiShu_Lei', 'EMei_Sword_Top', 'MobMan_Elite', 'YanYan_Club', 'HuaShan_RedTroop_BigBro')]

# Bosses fought in several phases (user decision 2026-11-14): one entry, the phases fought straight on. First
# phase -> its later phases, each a list of bosses that appear together (玉琮's second phase is its three forms at
# once). Later phases are marked part_of and listed nowhere on their own.
P = 'BP_Monster_'
PHASES = {P + first: [[P + i for i in step] for step in steps] for first, steps in {
    'HookMan': [['HookMan_P2']],
    'ChiLian': [['ChiLian_P2']],
    'MuXiaoKui': [['MuXiaoKui_P2']],
    'GuiChai_Red': [['GuiChai_Red_P2']],
    'ChangHong_Spear': [['ChangHong_P2']],
    'LionDancer': [['LionDancer_P2']],
    'LeiDang': [['LeiDang_P2']],
    'PowerMan': [['PowerMan_P2']],
    'MBoss': [['MBossVariants']],
    'YouLong_SecondBrother': [['YouLong_Harpoon']],
    'HuaShan_Blue': [['HuaShan_JianOu', 'EMei_Sword_Top']],   # 绝望剑意 with 红衣女剑客 (user, 2026-11-14)
    'YuCong_P1': [['YuCong_WuLi', 'YuCong_Bing', 'YuCong_HunDun']],
    'MoTian_LongZhu_01': [['MoTian']],      # 金面具黑衣人, then 魔渊 (user decision 2026-11-14)
}.items()}
# Bosses fought together from the start, as one entry (user decision 2026-11-15: 玉妖 and 铁鬼 as one two-boss
# fight). The entry's boss -> all the bosses of the fight in spawn order (the first stands straight ahead, the
# second 40 degrees off: run.lua SIDE_BY_SIDE), and the entry's name (zh, en). The others are marked part_of.
# 铁鬼 ahead and 玉妖 beside it: the user asked for the two swapped (2026-11-15).
TOGETHER = {
    P + 'Yuu': ([P + 'TieGui', P + 'Yuu'], '少主护卫：玉妖铁鬼', "Jade Dancer & Iron Fiend, Young Mistress's Guardians"),
}
PART_OF = {later: first for first, steps in PHASES.items() for step in steps for later in step}
PART_OF.update({other: first for first, (order, _, _) in TOGETHER.items() for other in order if other != first})
# Bosses still being tried: offered in development builds only (config.debug), open once the user confirms them in
# game. Each round's findings (helper points, health floors, 冷荼's phase taken from the save) are in DESIGN 5.2.
testing = []

def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


lines = ['-- Generated by src/tools/gen_roster.py from pbzero bosses.json.',
         '-- state: "open" | "testing" (development builds only) | "anchored" (needs its level: closed) | "story" (prologue/tutorial variant)',
         '-- helpers: helper points placed before the boss spawns: class, offset from the arena centre along the arena facing (cm).',
         '-- summons: classes of the boss\'s summons, scaled like the boss; their Kill is forced when they wait at 0 HP for an execution.',
         '-- summon: a summon passive its level would grant (ability class) and the gameplay event that starts it (event tag).',
         '-- remove_abilities: class names of abilities the run takes from the boss.',
         '-- watch_tags: gameplay tags the development log follows on the boss (at spawn and each change).',
         '-- phases: later phases of a boss fought in several (each a list of bosses that appear together); part_of: the first phase of the boss this record is a later phase of (or appears with).',
         '-- together: all the bosses that appear at the start, this one included, in spawn order; one entry named fight_zh / fight_en.',
         '-- clear_health_min: the run sets the boss\'s health floor (Health_Min) to 0, or it could never die.',
         '-- native_banner: the boss\'s own AI pushes the defeat banner (斩) on death; the run pushes it for the others.',
         'return {']
counts = {}
for x in b:
    st = 'open'
    if any(k.lower() in x['id'].lower() for k in story) or 'Prologue' in x.get('name_en', ''):
        st = 'story'
    elif x['id'] in testing:
        st = 'testing'
    elif x['id'] in anchored:
        st = 'anchored'
    counts[st] = counts.get(st, 0) + 1
    helpers = ''
    if x['id'] in HELPERS:
        helpers = ', helpers = { %s }' % ', '.join(
            '{ class = %s, fwd = %d, right = %d }' % (q(c), f, r) for c, f, r in HELPERS[x['id']])
    if x['id'] in SUMMONS:
        helpers += ', summons = { %s }' % ', '.join(q(c) for c in SUMMONS[x['id']])
    if x['id'] in SUMMON_PASSIVE:
        ability, event = SUMMON_PASSIVE[x['id']]
        helpers += ', summon = { ability = %s, event = %s }' % (q(ability), q(event))
    if x['id'] in WATCH_TAGS:
        helpers += ', watch_tags = { %s }' % ', '.join(q(t) for t in WATCH_TAGS[x['id']])
    if x['id'] in REMOVE_ABILITIES:
        helpers += ', remove_abilities = { %s }' % ', '.join(q(c) for c in REMOVE_ABILITIES[x['id']])
    if x['id'] in PHASES:
        helpers += ', phases = { %s }' % ', '.join('{ %s }' % ', '.join(q(i) for i in step) for step in PHASES[x['id']])
    if x['id'] in TOGETHER:
        order, zh, en = TOGETHER[x['id']]
        helpers += ', together = { %s }, fight_zh = %s, fight_en = %s' % (', '.join(q(i) for i in order), q(zh), q(en))
    if x['id'] in PART_OF:
        helpers += ', part_of = %s' % q(PART_OF[x['id']])
    if x['id'] in CLEAR_HEALTH_MIN:
        helpers += ', clear_health_min = true'
    if x['id'] in NATIVE_BANNER:
        helpers += ', native_banner = true'
    lines.append('    { id = %s, zh = %s, en = %s, class = %s, state = %s%s },'
                 % (q(x['id']), q(x['name']), q(x['name_en']), q(x['class_path']), q(st), helpers))
lines.append('}')
open(SCRIPTS / 'roster.lua', 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
print(counts)
