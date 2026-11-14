import json
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / 'mod' / 'BossRush' / 'Scripts'
b = json.load(open(r'F:\C\pbzero\src\pbzero\data\bosses.json', encoding='utf-8'))['bosses']
# Bosses whose skills need level-placed points (DESIGN 5.2) or confirmed vanishing: closed for now.
# LionDancer_P2: its summons are placed around the level's lion-dance poles; without them the last lion head
# (tagged HouHouHou.LastOne) cannot be killed (player report on Nexus, 0.1.1).
# YuBi, MengHua: level-placed snap points (BP_YuBi_SnapPoint, BP_MengHua_XuKong_SnapPoint) register with the
# targeting world subsystem instead of being found with GetActorOfClass, which the first scan missed. YuBi's
# CA_02 snaps to the nearest one, i.e. her own level, and took the player there (bug report on Nexus, 0.1.2).
anchored = ['ZuoShang', 'LengTu', 'YuZan', 'GuiChai_Red', 'QiShu', 'DuYan', 'ChiLian_P2', 'MoYuan', 'MoTian',
            'YanQianSui', 'CanQu', 'DangHui', 'LionDancer_P2', 'MengHua']
story = ['Tutorial', 'HorseCart', 'Prologue']

# Codex entry 013 has three parts: 红衣女剑客 (BossName_013_0), 七星剑阵：大师兄 (_1), 大师兄的绝望剑意 (_2). bosses.json
# gives part 1's name to BP_Monster_EMei_Sword_JianZhen, but in game that class is a 红衣女剑客 (its health bar says
# so, user test 2026-11-14). 大师兄 is taken to be BP_Monster_HuaShan_Blue: 绝望剑意 is a 华山 class too, the
# cutscene of that fight (Seq076) uses HuaShan_Blue, and it has no level lookups; confirmed in game 2026-11-14.
# CLASS_FIX: bosses.json record -> the class that really carries its name.
CLASS_FIX = {
    'BP_Monster_EMei_Sword_JianZhen': ('BP_Monster_HuaShan_Blue', '/PBZCombatAsset/ActorData/Mobs/035_HuaShan/'
                                       'BP_Monster_HuaShan_Blue.BP_Monster_HuaShan_Blue_C'),
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
    # CA_02 snaps to its snap point; CA_03 (the leap) to its snap point and lands on its landing point; GEd_01
    # reads the domain centre. GEx_01 (the roof chop, BP_ZuoShang_House) belongs to the prologue boss only.
    # The original layout is not known: all at the centre.
    'BP_Monster_ZuoShang_Ending': [(M + '054_ZuoShang/' + n + '.' + n + '_C', 0, 0) for n in (
        'BP_ZuoShang_CA_02_SnapPoint', 'BP_ZuoShang_CA_03_SnapPoint', 'BP_ZuoShang_CA_03_LandingPoint',
        'BP_ZuoShang_CA_03_DomainCenter')],
}

# Summons scaled like their boss (the game sizes some of their values from the boss's, see run.lua check_summons);
# the run also forces their Kill when they wait at 0 HP for an execution, and logs their state. LionDancer_P2's
# last lion head (tag HouHouHou.LastOne) could not be hurt or executed while only the boss was scaled, so the boss
# could not die (Nexus, 0.1.1; cause found 2026-11-13).
SUMMONS = {
    'BP_Monster_LionDancer_P2': ['BP_Monster_DaTouWaWa_HouHouHou_C'],
}

# Bosses whose health floor (Health_Min) the run sets to 0: it stays above 0 outside their level, so they cannot
# die. 魔渊 in a 二周目 started at Health_Min 24 and could not be killed (Nexus report on 0.1.4, mastersoul2).
CLEAR_HEALTH_MIN = ['BP_Monster_MoTian']

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
PART_OF = {later: first for first, steps in PHASES.items() for step in steps for later in step}
# Level-dependent bosses confirmed in game (2026-11-13), open although their names match `anchored`: with helper
# points (HELPERS), or with no level lookup at all.
# BP_Monster_GuiChai_Red_P2 needs no helper (its CA_02 spawns its own safe zone).
# BP_Monster_MoTian, BP_Monster_MoTian_LongZhu_01: no level lookup (Skill_08 spawns its own pillars); they were
# closed only because their spawner sits in a level-only space.
opened = ['BP_Monster_MengHua', 'BP_Monster_FemaleVessel_YuZan', 'BP_Monster_DuYanBoss', 'BP_Monster_YanQianSui',
          'BP_Monster_CanQu_BiHai', 'BP_Monster_GuiChai_Red', 'BP_Monster_GuiChai_Red_P2', 'BP_Monster_ChiLian_P2',
          'BP_Monster_MoTian', 'BP_Monster_MoTian_LongZhu_01', 'BP_Monster_ZuoShang_Ending', 'BP_Monster_LionDancer_P2']
# Bosses still being tried: offered in development builds only (config.debug); moved to `opened` once tested.
# BP_Monster_ZuoShang_Ending (opened 2026-11-13) was fought at its original arena until the player was put inside
#   a building there (its CA_03 snap point lies in an interior space); with its points in the arena it passed.
# BP_Monster_LionDancer_P2 (opened 2026-11-14) is fought only at its own battlefield (arenas.lua kind "own").
testing = []

def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


lines = ['-- Generated by src/tools/gen_roster.py from pbzero bosses.json.',
         '-- state: "open" | "testing" (development builds only) | "anchored" (needs its level: closed) | "story" (prologue/tutorial variant)',
         '-- helpers: helper points placed before the boss spawns: class, offset from the arena centre along the arena facing (cm).',
         '-- summons: classes of the boss\'s summons, scaled like the boss; their Kill is forced when they wait at 0 HP for an execution.',
         '-- phases: later phases of a boss fought in several (each a list of bosses that appear together); part_of: the first phase of the boss this record is a later phase of.',
         '-- clear_health_min: the run sets the boss\'s health floor (Health_Min) to 0, or it could never die.',
         'return {']
counts = {}
for x in b:
    st = 'open'
    if any(k.lower() in x['id'].lower() for k in story) or 'Prologue' in x.get('name_en', ''):
        st = 'story'
    elif x['id'] in testing:
        st = 'testing'
    elif x['id'] in opened:
        st = 'open'
    elif any(k.lower() in x['id'].lower() for k in anchored):
        st = 'anchored'
    counts[st] = counts.get(st, 0) + 1
    helpers = ''
    if x['id'] in HELPERS:
        helpers = ', helpers = { %s }' % ', '.join(
            '{ class = %s, fwd = %d, right = %d }' % (q(c), f, r) for c, f, r in HELPERS[x['id']])
    if x['id'] in SUMMONS:
        helpers += ', summons = { %s }' % ', '.join(q(c) for c in SUMMONS[x['id']])
    if x['id'] in PHASES:
        helpers += ', phases = { %s }' % ', '.join('{ %s }' % ', '.join(q(i) for i in step) for step in PHASES[x['id']])
    if x['id'] in PART_OF:
        helpers += ', part_of = %s' % q(PART_OF[x['id']])
    if x['id'] in CLEAR_HEALTH_MIN:
        helpers += ', clear_health_min = true'
    lines.append('    { id = %s, zh = %s, en = %s, class = %s, state = %s%s },'
                 % (q(x['id']), q(x['name']), q(x['name_en']), q(x['class_path']), q(st), helpers))
lines.append('}')
open(SCRIPTS / 'roster.lua', 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
print(counts)
