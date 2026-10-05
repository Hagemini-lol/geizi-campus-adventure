from pathlib import Path
import json

game = Path(__file__).resolve().parents[1]
path = game / '说明.md'
text = path.read_text(encoding='utf-8-sig')
replacements = {
    '桌椅、讲台与储物柜的碰撞缩小为贴图脚底中心的 1×1 逻辑像素，体积小于贴图': '桌子和椅子使用独立的落脚碰撞范围，讲台与储物柜按底部轮廓避让，碰撞均小于贴图',
    '四栋楼的全部教室共用小型家具碰撞：每组桌椅、讲台及柜体只保留脚底中心的 1×1 逻辑像素核心。逻辑像素随镜头倍率显示，贴图与人物比例保持原样。人物脚底仍有半径，因此核心周边保留必要的避让距离。': '四栋楼的全部教室共用家具落脚碰撞：每张桌子和每把椅子单独设置底部碰撞，讲台和柜体按底部轮廓避让，碰撞范围小于贴图。寻路与实际物理使用相同边界，保留桌椅之间的通道。家具原图裁片按落脚位置与人物共同排序，人物从后方经过时被家具遮挡，从前方经过时显示在家具前方。',
    '普通教室及十班均通过实际人物移动验证：穿过旧桌椅碰撞范围、经过各排相邻桌椅之间的空隙、到达前后门，共验证 123 个移动目标。报告见「室内家具通行验证.json」。原图片未修改，运行时读取游戏内的素材副本。': '最新家具检查覆盖十班、普通教室、实验楼教室和办公室：桌椅避让、前后门与全部座位可达、上午上课座位、NPC 交互以及具名学生随机移动。2,417 项检查通过，报告见「runtime/furniture_route_checks.json」。旧的「室内家具通行验证.json」仅记录此前的一像素方案。原图片未修改，运行时读取游戏内的素材副本。',
    '家具保留 1×1 逻辑像素碰撞核心': '家具使用小于贴图的底部碰撞范围',
    '家具碰撞维持 1 个逻辑像素': '家具按落脚轮廓避让，保留到座位旁的可行走路线',
}
for before, after in replacements.items():
    text = text.replace(before, after)
path.write_text(text, encoding='utf-8')
path = game / '安卓版使用说明.md'
text = path.read_text(encoding='utf-8-sig').replace('版本：1.0.0', '版本：1.0.1')
if '## 桌椅修复' not in text:
    text += '\n## 桌椅修复（1.0.1）\n\n主角及移动 NPC 的寻路会避开桌子和椅子的落脚范围，家具碰撞仍小于贴图，保留走道和座位交互。家具与人物按前后位置遮挡；普通教室学生使用坐姿，十班上课时的座位安排保持不变。时段切换会同步更新家具遮挡图，避免遮住已经入座的学生。\n\n2,417 项家具、座位及 NPC 路径检查通过，预览与报告保存在 `runtime`。发布包沿用旧版签名，可直接覆盖安装以保留存档。本次修复尚未进行新的安卓真机验证。\n'
path.write_text(text, encoding='utf-8')
path = game / 'AGENTS.md'
text = path.read_text(encoding='utf-8-sig')
rule = '- 用户实际游玩反馈桌椅穿模，2026-10-05 要求角色绕开家具或入座，随后重新封装 APK。新规则取代旧的一像素家具碰撞：桌椅分别设置小于贴图的落脚范围，导航与物理边界一致，家具与动态人物按落脚位置排序，普通教室学生采用坐姿。上课/时段切换需刷新遮挡裁片，保留座位、门口及 NPC 的近距离交互。安卓版本 1.0.1 / versionCode 2，沿用原发布签名，既有 ZIP 不改动。\n'
if rule not in text:path.write_text(text+rule, encoding='utf-8')
checks = json.loads((game / 'runtime/furniture_route_checks.json').read_text(encoding='utf-8'))['checks']
for document in ('说明.md', '安卓版使用说明.md'):
    file = game / document
    file.write_text(file.read_text(encoding='utf-8').replace('2,417 项', f'{checks:,} 项'), encoding='utf-8')
print('Furniture and Android documentation updated')
