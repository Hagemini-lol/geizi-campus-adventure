extends RefCounted

# Data-only extension API v1. A pack is accepted atomically; a broken neighbour
# cannot corrupt the base campaign. Never load scripts or replace core entries.
const API:=1
const MAX_BYTES:=2097152
const OWNERS: Array[String]=["lao_li","lao_chou","fei_yan","lao_ao","lao_shuo","yang_zi","lao_dong","la_jiao","wr"]
var merged: Dictionary={}
var loaded: Array[String]=[]
var issues: Array[String]=[]
var directory:=""

func read_json(path: String) -> Variant:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_BYTES:return null
	return JSON.parse_string(file.get_as_text())

func configure(root: String) -> void:
	merged={};loaded.clear();issues.clear()
	for pair: Array in [["combat","战斗与刷新配置.json"],["tasks","任务配置.json"],["economy","物资与交易配置.json"],["story","剧情配置.json"]]:
		var base: Variant=read_json(root.path_join(pair[1]))
		if base is Dictionary:merged[pair[0]]=base
	directory="user://mods" if OS.has_feature("android") or ProjectSettings.get_setting("application/config/mobile_bundle",false) else root.path_join("mods")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mods-dir="):directory=arg.trim_prefix("--mods-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	var folders:=DirAccess.get_directories_at(directory);folders.sort()
	var candidates: Array=[]
	for folder: String in folders:
		if candidates.size()>=32:issues.append("最多加载 32 个 Mod，后续目录已忽略");break
		var manifest: Variant=read_json(directory.path_join(folder).path_join("manifest.json"))
		if not manifest is Dictionary:issues.append(folder+"：manifest.json 无效或超过 2MB");continue
		if manifest.get("enabled",false)!=true:continue
		if not integer(manifest.get("order",0),-10000,10000):issues.append(folder+"：order 必须为整数");continue
		manifest["folder"]=folder;candidates.append(manifest)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary):return int(a.get("order",0))<int(b.get("order",0)) if int(a.get("order",0))!=int(b.get("order",0)) else str(a["folder"])<str(b["folder"]))
	for manifest: Dictionary in candidates:
		var id: String=str(manifest.get("id",""));var folder: String=manifest["folder"]
		if not integer(manifest.get("api",0),API,API) or not token(id) or id in loaded:
			issues.append(folder+"：API 版本、ID 无效或 ID 重复");continue
		var dependencies: Variant=manifest.get("requires",[])
		if not dependencies is Array or dependencies.any(func(x: Variant):return not x is String or not x in loaded):issues.append(folder+"：依赖未加载，请检查 requires 和 order");continue
		var filename: String=str(manifest.get("content","content.json"))
		if filename.get_file()!=filename or not filename.ends_with(".json"):issues.append(folder+"：content 只能引用包内 JSON 文件名");continue
		var content: Variant=read_json(directory.path_join(folder).path_join(filename))
		if not content is Dictionary:issues.append(folder+"：内容无效或超过 2MB");continue
		var error:=validate(id,content)
		if not error.is_empty():issues.append(folder+"："+error);continue
		for item: Dictionary in content.get("items",[]):merged["economy"]["items"].append(item.duplicate(true))
		for monster: Dictionary in content.get("monsters",[]):
			var spec: Dictionary=merged["combat"]["monsters"][monster["base"]].duplicate(true)
			spec["name"]=monster["name"]
			for field: String in ["hp","attack"]:spec["multipliers"][field]=float(spec["multipliers"].get(field,1))*float(monster.get(field+"_scale",1))
			merged["combat"]["monsters"][monster["id"]]=spec
		for task: Dictionary in content.get("quests",[]):merged["tasks"]["tasks"].append(task.duplicate(true))
		for event: String in content.get("event_dialogue",{}):
			for node: Dictionary in merged["story"]["campaign"]["nodes"]:
				if node["id"]==event:node["dialogue"].append_array(content["event_dialogue"][event].duplicate(true))
		loaded.append(id)

func token(value: String) -> bool:
	if value.is_empty() or value.length()>48:return false
	for c: String in value:
		if not c in "abcdefghijklmnopqrstuvwxyz0123456789_":return false
	return true

func valid_lines(value: Variant) -> bool:
	if not value is Array or value.size()>200:return false
	for line: Variant in value:
		if not line is Dictionary or not line.get("actor") is String or not line.get("text") is String:return false
		if not line["actor"] in OWNERS+["hero","zhao_mugei","system","gou_ga","wen_cong"] or line["text"].length()>800:return false
	return true

func valid_location(value: Variant) -> bool:
	if not value is String:return false
	if value in ["B04","S02"]:return true
	var p: PackedStringArray=value.split(":")
	if p.size()!=3:return false
	var floors: Dictionary={"B01":3,"B02":3,"B12":3,"B06":4,"STORY_HOUSE":1}
	if not floors.has(p[0]) or not p[1].is_valid_int():return false
	if int(p[1])<1 or int(p[1])>int(floors[p[0]]):return false
	return p[2]=="corridor" or (p[2].is_valid_int() and int(p[2])>=0 and int(p[2])<10)

func integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=low and float(value)<=high

func validate(id: String,content: Dictionary) -> String:
	if merged.size()!=4:return "基础配置不完整"
	for key: String in content:
		if not key in ["items","quests","event_dialogue","monsters"]:return "不支持的内容类型："+key
	if not content.get("items",[]) is Array or not content.get("quests",[]) is Array or not content.get("monsters",[]) is Array or not content.get("event_dialogue",{}) is Dictionary:return "内容类型错误"
	if content.get("items",[]).size()>64 or content.get("quests",[]).size()>64 or content.get("monsters",[]).size()>32:return "单包最多 64 物品、64 任务、32 怪物"
	var item_ids: Array=[];var quest_ids: Array=[]
	for item: Dictionary in merged["economy"]["items"]:item_ids.append(item["id"])
	for task: Dictionary in merged["tasks"]["tasks"]:quest_ids.append(task["id"])
	if item_ids.size()+content.get("items",[]).size()>800 or quest_ids.size()+content.get("quests",[]).size()>800:return "总内容超过存档容量（800 项）"
	var new_items: Array=[];var new_quests: Array=[]
	var monster_ids: Array=merged["combat"]["monsters"].keys()
	for monster: Variant in content.get("monsters",[]):
		if not monster is Dictionary or not str(monster.get("id","")).begins_with(id+":") or not token(str(monster.get("id","")).trim_prefix(id+":")):return "怪物 ID 必须为 包ID:名称"
		if monster["id"] in monster_ids or not monster.get("base","") in ["ink_slime","book_eater","empty_uniform","dry_branch"] or not monster.get("name") is String or monster["name"].length()>80:return "怪物名称、基础类型错误或 ID 冲突"
		for field: String in ["hp_scale","attack_scale"]:
			var scale: Variant=monster.get(field,1)
			if not (scale is int or scale is float) or not is_finite(float(scale)) or float(scale)<.5 or float(scale)>3:return "怪物倍率须为 0.5–3"
		monster_ids.append(monster["id"])
	for item: Variant in content.get("items",[]):
		if not item is Dictionary or not str(item.get("id","")).begins_with(id+":") or not token(str(item.get("id","")).trim_prefix(id+":")):return "物品 ID 必须为 包ID:名称"
		if item["id"] in item_ids or item["id"] in new_items:return "物品 ID 冲突"
		if not item.get("name") is String or item["name"].length()>80 or not item.get("restore") is Dictionary or not item.get("restore_ratio",{}) is Dictionary:return "物品名称或回复数据错误"
		if not integer(item.get("buy_price",-1),-1,100000) or not integer(item.get("sell_price",0),0,100000):return "物品价格错误"
		if int(item.get("buy_price",-1))>=0 and int(item.get("sell_price",0))>int(item["buy_price"]):return "卖价不能高于买价"
		for stat: Variant in item["restore"]:
			if not stat in ["hp","mp","energy","san"] or not integer(item["restore"][stat],1,100000):return "固定回复数值错误"
		for stat: Variant in item.get("restore_ratio",{}):
			var ratio: Variant=item["restore_ratio"][stat]
			if not stat in ["hp","mp","energy","san"] or not (ratio is int or ratio is float) or not is_finite(float(ratio)) or float(ratio)<=0 or float(ratio)>1:return "比例回复数值错误"
		new_items.append(item["id"])
	for task: Variant in content.get("quests",[]):
		if not task is Dictionary or not str(task.get("id","")).begins_with(id+":") or not token(str(task.get("id","")).trim_prefix(id+":")):return "任务 ID 必须为 包ID:名称"
		if task["id"] in quest_ids or task["id"] in new_quests:return "任务 ID 冲突"
		new_quests.append(task["id"])
	for task: Dictionary in content.get("quests",[]):
		if task.get("type")!="side" or task.get("auto_start",false)!=false or not task.get("title") is String:return "Mod 任务必须为手动接取的 side 类型"
		if not task.get("prerequisites",[]) is Array:return "前置任务错误"
		for dependency: Variant in task.get("prerequisites",[]):
			if not dependency is String or not dependency in quest_ids+new_quests or dependency==task["id"]:return "前置任务不存在或自引用"
		var story: Variant=task.get("side_story")
		if not story is Dictionary or not story.get("owner","") in OWNERS or not integer(story.get("min_index",3),0,33):return "委托人或章节门槛错误"
		if not story.get("description") is String or not story.get("intro") is Array or not story.get("outro") is Array or not story.get("daily",false) is bool:return "任务描述、开场、后话或每日标记错误"
		for key: String in ["intro","outro","epilogue"]:
			if not valid_lines(story.get(key,[])):return "任务对白错误"
		var reward: Variant=story.get("reward")
		if not reward is Dictionary or not integer(reward.get("g",0),0,10000) or not reward.get("items",{}) is Dictionary:return "奖励错误"
		for material: Variant in reward.get("items",{}):
			if not material in item_ids+new_items or not integer(reward["items"][material],1,99):return "奖励物品不存在或数量错误"
		if not task.get("steps") is Array or task["steps"].is_empty() or task["steps"].size()>32:return "步骤数量须为 1–32"
		for step: Variant in task["steps"]:
			if not step is Dictionary or not step.get("hint") is String:return "步骤格式错误"
			if step.has("actor") and not step["actor"] in OWNERS:return "步骤角色错误"
			if step.has("location") and not valid_location(step["location"]):return "步骤地点错误"
			if not integer(step.get("count",1),1,10):return "步骤次数错误"
			var event: String=str(step.get("event",""))
			if event.begins_with("monster_defeated/"):
				if not event.trim_prefix("monster_defeated/") in monster_ids or not integer(step.get("count",1),1,10):return "击败目标不存在或数量错误"
				continue
			if not event.begins_with("side/"+id+":"):return "步骤事件须以 side/包ID: 开头"
			if not (step.get("actor","") in OWNERS or valid_location(step.get("location"))):return "步骤地点或角色错误"
			for key: String in ["dialogue","retry","resolution"]:
				if not valid_lines(step.get(key,[])):return "步骤对白错误"
			if step.has("puzzle"):
				if not preload("res://puzzle_board.gd").valid_spec(step["puzzle"]):return "机关谜题格式错误"
				if not step["puzzle"].get("helper","system") in OWNERS+["system","hero","zhao_mugei"]:return "机关提示角色错误"
				for key: String in ["success","failure"]:
					if not valid_lines(step["puzzle"].get(key,[])):return "机关谜题对白错误"
			if not step.get("consume",{}) is Dictionary:return "消耗物品错误"
			for material: Variant in step.get("consume",{}):
				if not material in item_ids+new_items or not integer(step["consume"][material],1,99):return "消耗物品不存在或数量错误"
			if step.has("choices"):
				if not step.get("question") is String or not step["choices"] is Array or step["choices"].size()<2 or step["choices"].size()>4:return "选项错误"
				var keys: Array=[]
				for option: Variant in step["choices"]:
					if not option is Array or option.size()!=2 or not option[0] is String or not option[1] is String or option[0] in keys:return "选项格式错误"
					keys.append(option[0])
				if step.has("branches"):
					if not step["branches"] is Dictionary:return "分支格式错误"
					for key: Variant in keys:
						if key=="cancel":continue
						if not valid_lines(step["branches"].get(key)):return "分支对白缺失"
				elif not step.get("correct","") in keys:return "正确选项不存在"
	var events: Array=[]
	for node: Dictionary in merged["story"]["campaign"]["nodes"]:events.append(node["id"])
	for event: Variant in content.get("event_dialogue",{}):
		if not event in events or not valid_lines(content["event_dialogue"][event]):return "剧情事件不存在或对白错误"
	# Reject cycles, including mutually dependent newly added quests.
	var dependencies: Dictionary={}
	for task: Dictionary in merged["tasks"]["tasks"]+content.get("quests",[]):dependencies[task["id"]]=task.get("prerequisites",[])
	var resolved: Array=[]
	for pass_index: int in range(dependencies.size()+1):
		var changed:=false
		for quest: String in dependencies:
			if quest in resolved:continue
			if dependencies[quest].all(func(x: Variant):return x in resolved):resolved.append(quest);changed=true
		if not changed:break
	for quest: String in new_quests:
		if not quest in resolved:return "任务前置存在循环"
	return ""

func status_text() -> String:
	return "Mod API 1 · 已加载 %d 个\n目录：%s\n%s%s\n更改后重启游戏。移除包后，任务和物品进度保留，重新装回可继续。" % [loaded.size(),directory,", ".join(loaded),"\n未加载：\n"+"\n".join(issues) if not issues.is_empty() else ""]

func install_bundle(value: String) -> String:
	if value.to_utf8_buffer().size()>MAX_BYTES:return "导入失败：JSON 超过 2MB"
	var bundle: Variant=JSON.parse_string(value)
	if not bundle is Dictionary or not bundle.get("manifest") is Dictionary or not bundle.get("content") is Dictionary:return "导入失败：需要 manifest 与 content 两个对象"
	var manifest: Dictionary=bundle["manifest"].duplicate(true);var id: String=str(manifest.get("id",""))
	if not token(id) or not integer(manifest.get("api",0),API,API) or not integer(manifest.get("order",0),-10000,10000):return "导入失败：ID、API 或 order 无效"
	if not manifest.get("requires",[]) is Array or manifest.get("requires",[]).any(func(x: Variant):return not x is String or not x in loaded):return "导入失败：所需依赖尚未加载"
	var error:=validate(id,bundle["content"])
	if not error.is_empty():return "导入失败："+error
	if id in loaded:return "已经加载同 ID 的 Mod；关闭游戏后替换目录中的文件"
	var target:=directory.path_join(id)
	if DirAccess.dir_exists_absolute(target):
		# The bundled example is shipped disabled; installing the exact example
		# is the only implicit activation. Never overwrite a user's modified pack.
		var old: Variant=read_json(target.path_join("content.json"))
		if id!="campus_example" or old!=bundle["content"]:return "同名目录已存在；请关闭游戏后手动管理，未覆盖"
	else:
		if DirAccess.make_dir_recursive_absolute(target)!=OK:return "导入失败：无法创建 Mod 目录"
	manifest["enabled"]=true;manifest["content"]="content.json"
	for pair: Array in [["content.json",bundle["content"]],["manifest.json",manifest]]:
		var file:=FileAccess.open(target.path_join(pair[0]),FileAccess.WRITE)
		if file==null:return "导入失败：无法写入文件，已保留原存档"
		file.store_string(JSON.stringify(pair[1],"  "));file.close()
	return "Mod 已安装，完全关闭并重新打开游戏后生效。玩家存档未改动。"
