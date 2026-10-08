extends RefCounted

signal changed
const TYPES: Array[String]=["main","side","guide"]
var definitions: Dictionary={}
var entries: Dictionary={}

func configure(path: String, content: Dictionary={}) -> bool:
	var parsed: Variant=content.duplicate(true) if not content.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("tasks") is Array:return false
	definitions={}
	for value: Variant in parsed["tasks"]:
		if not value is Dictionary:return false
		var id: String=str(value.get("id",""))
		if id.is_empty() or definitions.has(id) or not value.get("type","main") in TYPES:return false
		if not value.get("steps") is Array or value["steps"].is_empty():return false
		for step: Variant in value["steps"]:
			if not step is Dictionary or not step.get("hint") is String:return false
			if step.has("puzzle") and not preload("res://puzzle_board.gd").valid_spec(step["puzzle"]):return false
			if step.has("event") and (not step["event"] is String or int(step.get("count",1))<1):return false
		if not value.get("prerequisites",[]) is Array:return false
		if value.has("side_story"):
			var story: Variant=value["side_story"]
			if not story is Dictionary or not story.get("owner") is String or not story.get("reward") is Dictionary:return false
			if int(story["reward"].get("g",0))<0:return false
			for item: Variant in story["reward"].get("items",{}):
				if not item is String or int(story["reward"]["items"][item])<1:return false
		definitions[id]=value.duplicate(true)
	reset()
	return true

func reset() -> void:
	entries={};start_automatic();changed.emit()

func prerequisites_met(id: String) -> bool:
	for requirement: String in definitions[id].get("prerequisites",[]):
		if entries.get(requirement,{}).get("status")!="completed":return false
	return true

func start_automatic() -> void:
	# Iterate so newly satisfied prerequisites can start in any config order.
	for pass_index: int in range(definitions.size()):
		var started:=false
		for id: String in definitions:
			if entries.has(id) or not definitions[id].get("auto_start",false) or not prerequisites_met(id):continue
			entries[id]={"status":"active","step":0,"progress":0};started=true
		if not started:break

func start(id: String) -> bool:
	if not definitions.has(id) or entries.has(id) or not prerequisites_met(id):return false
	entries[id]={"status":"active","step":0,"progress":0};changed.emit();return true

func advance(id: String) -> bool:
	if not definitions.has(id) or entries.get(id,{}).get("status")!="active":return false
	var entry: Dictionary=entries[id]
	entry["step"]=int(entry["step"])+1;entry["progress"]=0
	if int(entry["step"])>=definitions[id]["steps"].size():entry["status"]="completed"
	start_automatic();changed.emit();return true

func complete(id: String) -> bool:
	if not definitions.has(id) or entries.get(id,{}).get("status")!="active":return false
	entries[id]={"status":"completed","step":definitions[id]["steps"].size(),"progress":0}
	start_automatic();changed.emit();return true

func record_event(event: String, amount: int=1) -> void:
	if amount<=0:return
	# A single event advances at most one step in each active task.
	var affected:=false
	for id: String in entries.keys():
		if not definitions.has(id) or entries[id]["status"]!="active":continue
		var entry: Dictionary=entries[id]
		var step: Dictionary=definitions[id]["steps"][int(entry["step"])]
		if step.get("event","")!=event:continue
		var target:=maxi(1,int(step.get("count",1)))
		entry["progress"]=mini(target,int(entry["progress"])+amount);affected=true
		if int(entry["progress"])>=target:
			entry["step"]=int(entry["step"])+1;entry["progress"]=0
			if int(entry["step"])>=definitions[id]["steps"].size():entry["status"]="completed"
	if affected:start_automatic();changed.emit()

func active_tasks() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for category: String in TYPES:
		for id: String in definitions:
			var spec: Dictionary=definitions[id]
			if spec.get("type","main")!=category or entries.get(id,{}).get("status")!="active":continue
			var entry: Dictionary=entries[id];var step: Dictionary=spec["steps"][int(entry["step"])]
			result.append({"id":id,"type":category,"title":str(spec.get("title",id)),"hint":step["hint"],"progress":entry["progress"],"target":int(step.get("count",0)) if step.has("event") else 0})
	return result

func display_text() -> String:
	var tasks:=active_tasks()
	var story_active:=tasks.any(func(task: Dictionary):return task["type"] in ["main","side"])
	var lines: Array[String]=[]
	for task: Dictionary in tasks:
		if story_active and task["type"]=="guide":continue
		var category: String={"main":"主线","side":"支线","guide":"探索"}[task["type"]]
		var text: String="【"+category+"】"+task["title"]+"\n下一步："+str(task["hint"])
		if int(task["target"])>1:text+="（%d/%d）" % [task["progress"],task["target"]]
		lines.append(text)
	return "\n\n".join(lines) if not lines.is_empty() else "当前暂无任务，gei子可以自由探索校园。"

func snapshot() -> Dictionary:
	return {"version":1,"entries":entries.duplicate(true)}

func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("entries") is Dictionary:return false
	if value["entries"].size()>1000:return false
	for id: Variant in value["entries"]:
		if not id is String or id.is_empty():return false
		var entry: Variant=value["entries"][id]
		if not entry is Dictionary or not entry.get("status") in ["active","completed"]:return false
		if entry.has("reward_claimed") and (not entry["reward_claimed"] is bool or entry["status"]!="completed"):return false
		if entry.has("reward_day"):
			var day: Variant=entry["reward_day"]
			if not (day is int or day is float) or not is_finite(float(day)) or floor(float(day))!=float(day) or float(day)<0:return false
		if entry.has("decisions"):
			if not entry["decisions"] is Dictionary or entry["decisions"].size()>32:return false
			for key: Variant in entry["decisions"]:
				if not key is String or not key.is_valid_int() or not entry["decisions"][key] is String or entry["decisions"][key].length()>80:return false
		if entry.has("puzzles"):
			if not entry["puzzles"] is Dictionary or entry["puzzles"].size()>32:return false
			for key: Variant in entry["puzzles"]:
				if not key is String or not key.is_valid_int() or not preload("res://puzzle_board.gd").valid_saved(entry["puzzles"][key]):return false
		for field: String in ["step","progress"]:
			var number: Variant=entry.get(field)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floor(float(number)) or float(number)<0 or float(number)>1e12:return false
		if definitions.has(id):
			var count: int=definitions[id]["steps"].size()
			if entry["status"]=="active" and int(entry["step"])>=count:return false
			if entry["status"]=="completed" and int(entry["step"])!=count:return false
	return true

func restore(value: Dictionary) -> void:
	# Old saves omit task data; removed definitions retain dormant progress so
	# reintroducing that task later does not silently erase the player's progress.
	if value.is_empty():reset();return
	entries=value["entries"].duplicate(true)
	for id: String in entries:
		entries[id]["step"]=int(entries[id]["step"]);entries[id]["progress"]=int(entries[id]["progress"])
		if entries[id].has("reward_day"):entries[id]["reward_day"]=int(entries[id]["reward_day"])
		for key: String in entries[id].get("puzzles",{}):
			var board: Dictionary=entries[id]["puzzles"][key]
			board["attempts"]=int(board["attempts"])
			for i: int in range(board["values"].size()):board["values"][i]=int(board["values"][i])
	start_automatic();changed.emit()
