extends RefCounted
var game: Node2D
const ZONES: Array[Dictionary]=[
	{"building":"B01","floor":2,"room":5,"after":"tide_school","name":"秋实楼闲置教室","reason":"夜袭后封存的墨痕仍会凝结；上课的十班不受影响。","normal":["ink_slime"],"elite":["empty_uniform"]},
	{"building":"B12","floor":2,"room":5,"after":"patrol_done","name":"明理楼旧资料室","reason":"旧讲义残留的墨渣周期凝聚，老师将清理任务交给觉醒者。","normal":["book_eater"],"elite":["empty_uniform"]},
	{"building":"B05","floor":2,"room":5,"after":"yang_hearing","name":"知行楼停用自习室","reason":"伪造材料封存后留下的怨念会重新成形。","normal":["ink_slime","book_eater"],"elite":["empty_uniform"]},
	{"building":"B06","floor":1,"room":1,"after":"book_queen","name":"科技中心半地下书库","reason":"噬书母体已清除，散落残页仍在滋生小型噬书怪。","normal":["book_eater"],"elite":["empty_uniform"]},
	{"building":"B15","floor":4,"room":5,"after":"ancient","name":"办公楼封存仪式间","reason":"仪式被破坏后枝根没有完全失活；避开日常打印和办公区。","normal":["ink_slime"],"elite":["dry_branch"]},
	{"building":"STORY_SEAL","floor":1,"room":0,"after":"seal_defend","name":"石室外封印维护区","reason":"守印人定期清理泄出的残渣，保持表门稳定。","normal":["ink_slime","book_eater"],"elite":["dry_branch"]}
]

func install() -> void:
	for zone: Dictionary in ZONES:
		var building: Dictionary=game.interior_info[zone["building"]] if game.interior_info.has(zone["building"]) else game.interior_info["buildings"][zone["building"]]
		building["floors"][int(zone["floor"])-1]["rooms"][int(zone["room"])]["name"]=zone["name"]

func rule(context: Dictionary) -> Dictionary:
	if game.story_system==null or game.campaign==null or game.story_system.stage<6:return {}
	for zone: Dictionary in ZONES:
		if context.get("kind","")!="classroom" or context.get("building","")!=zone["building"] or int(context.get("floor",0))!=zone["floor"] or int(context.get("room",-1))!=zone["room"]:continue
		if not zone["after"] in game.campaign.done:return {}
		return {"enabled":true,"farming":true,"capacity":2,"initial_count":1,"level_mode":"hero_relative","normal_pool":zone["normal"],"elite_pool":zone["elite"],"name":zone["name"],"reason":zone["reason"]}
	return {}

func journal() -> String:
	var text:="持续清理区\n击败一只后清理耗时一时段，并按房间上限补充怪物；切换房间不会重抽怪物。普通怪低于主角5级，精英同级；Boss不会随机复活。\n"
	for zone: Dictionary in ZONES:
		text+="\n"+zone["name"]+" · %dF 房间%d · " % [zone["floor"],zone["room"]+1]+("已开放" if zone["after"] in game.campaign.done else "相关章节结束后开放")+"\n"+zone["reason"]+"\n"
	return text
