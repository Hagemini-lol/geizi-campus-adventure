extends RefCounted

# Small event-driven boards: no timers, per-frame polling, image buffers or
# mandatory reflex inputs. The unfinished board lives in the quest save.
var game: Node2D

static func same_values(a: Array,b: Array) -> bool:
	if a.size()!=b.size():return false
	for i: int in range(a.size()):
		if int(a[i])!=int(b[i]):return false
	return true

static func valid_spec(spec: Variant) -> bool:
	if not spec is Dictionary or not spec.get("kind","") in ["dials","sequence","switches"]:return false
	for field: String in ["title","description","hint"]:
		if not spec.get(field) is String or spec[field].length()>3000:return false
	for field: String in ["initial","target"]:
		if not spec.get(field) is Array or spec[field].size()<3 or spec[field].size()>4:return false
		for n: Variant in spec[field]:
			if not (n is int or n is float) or not is_finite(float(n)) or floor(float(n))!=float(n) or float(n)<0 or float(n)>15:return false
	if spec["initial"].size()!=spec["target"].size():return false
	if not spec.get("controls") is Array or spec["controls"].size()>4:return false
	for text: Variant in spec["controls"]:
		if not text is String or text.length()>80:return false
	if not spec.get("clues") is Array or spec["clues"].is_empty() or spec["clues"].size()>4:return false
	for clue: Variant in spec["clues"]:
		if not clue is Dictionary or not clue.get("title") is String or not clue.get("text") is String or clue["text"].length()>1600:return false
	if spec["kind"]=="dials":
		if not spec.get("tokens") is Array or spec["tokens"].size()!=spec["initial"].size() or spec["controls"].size()!=spec["initial"].size():return false
		for i: int in range(spec["tokens"].size()):
			if not spec["tokens"][i] is Array or spec["tokens"][i].size()<2 or spec["tokens"][i].size()>16:return false
			for token: Variant in spec["tokens"][i]:
				if not token is String or token.length()>80:return false
			if int(spec["initial"][i])>=spec["tokens"][i].size() or int(spec["target"][i])>=spec["tokens"][i].size():return false
	elif spec["kind"]=="sequence":
		if not spec.get("pieces") is Array or spec["pieces"].size()!=spec["initial"].size() or spec["controls"].size()!=spec["initial"].size()-1:return false
		for text: Variant in spec["pieces"]:
			if not text is String or text.length()>100:return false
		for field: String in ["initial","target"]:
			var unique: Dictionary={}
			for n: Variant in spec[field]:
				if int(n)>=spec["pieces"].size() or unique.has(int(n)):return false
				unique[int(n)]=true
	else:
		if not spec.get("links") is Array or spec["links"].size()!=spec["controls"].size():return false
		for field: String in ["initial","target"]:
			for n: Variant in spec[field]:
				if int(n)>1:return false
		for link: Variant in spec["links"]:
			if not link is Array or link.is_empty() or link.size()>4:return false
			for n: Variant in link:
				if not (n is int or n is float) or floor(float(n))!=float(n) or float(n)<0 or float(n)>=spec["initial"].size():return false
		var reachable:=false
		for mask: int in range(1<<spec["links"].size()):
			var values: Array=spec["initial"].duplicate()
			for i: int in range(spec["links"].size()):
				if mask&(1<<i):
					for n: Variant in spec["links"][i]:values[int(n)]=1-int(values[int(n)])
			if same_values(values,spec["target"]):reachable=true;break
		if not reachable:return false
	return true

static func valid_saved(value: Variant) -> bool:
	if not value is Dictionary or not value.get("values") is Array or value["values"].size()<3 or value["values"].size()>4:return false
	for n: Variant in value["values"]:
		if not (n is int or n is float) or not is_finite(float(n)) or floor(float(n))!=float(n) or float(n)<0 or float(n)>15:return false
	if not value.get("seen") is Dictionary or value["seen"].size()>4 or not value.get("solved") is bool:return false
	for key: Variant in value["seen"]:
		if not key is String or not key in ["0","1","2","3"] or value["seen"][key]!=true:return false
	var attempts: Variant=value.get("attempts")
	return (attempts is int or attempts is float) and is_finite(float(attempts)) and floor(float(attempts))==float(attempts) and float(attempts)>=0 and float(attempts)<=999

func caption(spec: Dictionary,state: Dictionary) -> String:
	var view: Array[String]=[]
	for i: int in range(state["values"].size()):
		var n: int=int(state["values"][i])
		if spec["kind"]=="dials":view.append(str(spec["controls"][i])+"："+str(spec["tokens"][i][n]))
		elif spec["kind"]=="sequence":view.append("%d. %s" % [i+1,spec["pieces"][n]])
		else:view.append("%d号指示灯：%s" % [i+1,"亮" if n==1 else "暗"])
	return str(spec["title"])+"\n"+str(spec["description"])+"\n\n当前：\n"+"\n".join(view)+"\n\n已观察 %d/%d 处 · 尝试 %d 次\n可随时查线索、看提示或离开，未解状态会随存档保存。" % [state["seen"].size(),spec["clues"].size(),int(state["attempts"])]

func inspect(spec: Dictionary,state: Dictionary) -> void:
	while true:
		var choices: Array=[]
		for i: int in range(spec["clues"].size()):choices.append([str(i),("已读 · " if state["seen"].has(str(i)) else "观察 · ")+str(spec["clues"][i]["title"])])
		choices.append(["back","返回机关"])
		var answer: String=await game.campaign.choose("观察线索 · "+str(spec["title"]),choices)
		if answer=="back":return
		if not answer.is_valid_int() or int(answer)<0 or int(answer)>=spec["clues"].size():continue
		state["seen"][answer]=true
		await game.campaign.dialog([{"actor":"system","text":spec["clues"][int(answer)]["text"]}])

func run(spec: Dictionary,entry: Dictionary,key: String) -> bool:
	if not valid_spec(spec):game.show_notice("机关配置无效，此任务暂不可继续");return false
	if not entry.has("puzzles"):entry["puzzles"]={}
	var state: Dictionary=entry["puzzles"].get(key,{})
	if not valid_saved(state) or state["values"].size()!=spec["initial"].size():
		state={"values":spec["initial"].duplicate(),"seen":{},"attempts":0,"solved":false};entry["puzzles"][key]=state
	# Mods must preserve puzzle dimensions/IDs when releasing updates.
	for i: int in range(state["values"].size()):state["values"][i]=int(state["values"][i])
	for i: int in range(state["values"].size()):
		if spec["kind"]=="dials" and int(state["values"][i])>=spec["tokens"][i].size():state["values"]=spec["initial"].duplicate();state["solved"]=false;break
		if spec["kind"]=="sequence" and int(state["values"][i])>=spec["pieces"].size():state["values"]=spec["initial"].duplicate();state["solved"]=false;break
		if spec["kind"]=="switches" and int(state["values"][i])>1:state["values"]=spec["initial"].duplicate();state["solved"]=false;break
	if spec["kind"]=="sequence":
		var used: Dictionary={}
		for n: Variant in state["values"]:used[int(n)]=true
		if used.size()!=state["values"].size():state["values"]=spec["initial"].duplicate();state["solved"]=false
	if not same_values(state["values"],spec["target"]):state["solved"]=false
	if state["solved"]:return true
	while true:
		var choices: Array=[]
		for i: int in range(spec["controls"].size()):choices.append(["move"+str(i),str(spec["controls"][i])+" · "+("切换" if spec["kind"]=="dials" else "交换相邻卡片" if spec["kind"]=="sequence" else "拨动")])
		choices.append_array([["inspect","查看现场线索"],["submit","验证当前排列"],["hint","请求同伴提示"],["cancel","保留现场，暂时离开"]])
		var answer: String=await game.campaign.choose(caption(spec,state),choices)
		if answer=="cancel":return false
		if answer=="inspect":await inspect(spec,state);continue
		if answer=="hint":await game.campaign.dialog([{"actor":spec.get("helper","system"),"text":spec["hint"]}]);continue
		if answer=="submit":
			state["attempts"]=mini(999,int(state["attempts"])+1)
			if same_values(state["values"],spec["target"]):
				game.sounds.play("puzzle_success");state["solved"]=true;await game.campaign.dialog(spec.get("success",[]));game.task_system.changed.emit();return true
			await game.campaign.dialog(spec.get("failure",[{"actor":"system","text":"机关没有响应。线索仍在，可以换一种排列，不消耗物资。"}]))
			if int(state["attempts"])==3:await game.campaign.dialog([{"actor":spec.get("helper","system"),"text":spec["hint"]}])
			continue
		if not answer.begins_with("move"):continue
		game.sounds.play("puzzle_tick")
		var i: int=int(answer.trim_prefix("move"))
		if i<0 or i>=spec["controls"].size():continue
		if spec["kind"]=="dials":state["values"][i]=(int(state["values"][i])+1)%spec["tokens"][i].size()
		elif spec["kind"]=="sequence":var n: int=int(state["values"][i]);state["values"][i]=state["values"][i+1];state["values"][i+1]=n
		else:
			for lamp: Variant in spec["links"][i]:state["values"][int(lamp)]=1-int(state["values"][int(lamp)])
	return false
