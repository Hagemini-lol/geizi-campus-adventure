extends RefCounted

var game: Node2D
var busy:=false
const DIRECT: Array[String]=["B03","B09","B10"]
const FOOD: Array[String]=["bread","rice_meal","egg_sandwich","fruit_yogurt","milk","fruit"]
const PLANS={
	"B04":{"name":"小仓库","layout":"warehouse","rooms":[["校园物资与体育器材库"],["旧讲义与备用器材库"]]},
	"B09":{"name":"设备辅助用房","layout":"equipment","rooms":[["设备检修与工具间"]]},
	"B10":{"name":"礼堂","layout":"auditorium","rooms":[["集会与排练大厅"]]},
	"B13":{"name":"新教学楼","rooms":[["阶梯自习教室","合作学习教室","教师备课室","班级活动室","资料室","值班办公室"],["语文研习教室","数学研习教室","英语研习教室","小组讨论室","共享自习室","教研办公室"],["综合活动教室","音乐理论教室","美术理论教室","社团讨论室","学生作品室","社团指导室"],["安静自习室","阅读交流室","学习资料室","课程展示室","学生议事室","楼层值班室"]]}
}

func configure(owner_game: Node2D) -> void:
	game=owner_game
	for id: String in PLANS:
		var spec: Dictionary=PLANS[id]
		var building: Dictionary=game.interior_info["buildings"]["B02"].duplicate(true)
		building["id"]=id;building["name"]=spec["name"];building["floor_count"]=spec["rooms"].size()
		building["floors"].resize(building["floor_count"])
		for floor_data: Dictionary in building["floors"]:
			var titles: Array=spec["rooms"][int(floor_data["floor"])-1]
			floor_data["rooms"].resize(titles.size())
			for room: Dictionary in floor_data["rooms"]:
				room["class10"]=false;room["office"]=false;room["name"]=titles[int(room["index"])]
				if spec.has("layout"):room["life_layout"]=spec["layout"]
				elif ["办公室","备课","教研","指导","值班"].any(func(word: String):return str(room["name"]).contains(word)):room["office"]=true;room["office_asset"]="office_wood"
		game.interior_info["buildings"][id]=building
	for entry: Dictionary in game.interior_info["entrances"]:
		if PLANS.has(entry["id"]):entry["has_interior"]=true
	# Keep existing room indices, campaign addresses and original corridor art.
	var offices: Array=["政教处与接待室","教务资料室","打印室","学生事务室","会议室","教师办公室"]
	var reading: Array=["阅览室","书库","借阅与咨询室","资料检索室","科技交流室","学习讨论室"]
	for id: String in ["B06","B15"]:
		for floor_data: Dictionary in game.interior_info["buildings"][id]["floors"]:
			for room: Dictionary in floor_data["rooms"]:
				if room.has("life_layout"):continue
				room["name"]=(offices if id=="B15" else reading)[int(room["index"])]+(" · "+str(floor_data["floor"])+"层")

func here(layout: String) -> bool:
	return not game.interior_state.is_empty() and game.interior_state.get("kind")=="classroom" and game.terrain.current_scene.life_layout==layout

func own_room() -> bool:
	return here("dorm") and game.interior_state["building"]=="B16" and int(game.interior_state["floor"])==2 and int(game.interior_state["room"])==0

func point_for(kind: String) -> Vector2:
	return Vector2(390,520)*.3 if kind=="sleep" else Vector2(590,535)*.3

func interactions() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if own_room():
		result.append({"action":"campus_sleep","at":point_for("sleep"),"trigger":Rect2(),"art_rect":Rect2(315*.3,166*.3,165*.3,312*.3)})
	if here("cafeteria"):
		result.append({"action":"campus_dine","at":point_for("dine"),"trigger":Rect2(),"art_rect":Rect2(315*.3,375*.3,210*.3,145*.3)})
	return result

func can_act(kind: String) -> bool:
	return not busy and game.game_started and not game.transition_busy and not game.paused and not game.phone.visible and not game.menu_view.visible and not game.map_view.visible and not game.battle_view.visible and not game.dialogue_view.visible and not game.story_system.running and (own_room() if kind=="sleep" else here("cafeteria")) and game.within_interaction(point_for(kind))

func open(kind: String) -> void:
	if not can_act(kind):return
	busy=true;game.story_system.begin_sequence()
	var options: Array=[]
	var title:=""
	if kind=="sleep":
		title="201室 · 你的床位\n小睡耗一时段：生命10%、魔力15%、精力50%；夜间睡到次日上午完全恢复这三项。理智与剧情进度不变。"
		options.append(["nap","小睡一会儿（一个时段）"])
		if game.day_clock.current_period in [0,3,4]:options.append(["night","睡到次日上午"])
	else:
		title="食堂就座用餐 · 所持 "+str(game.economy.money)+"g\n吃饭耗一时段，按食物本身恢复，坐下另恢复10%精力；只在确实需要恢复时消费。"
		var ids: Array=["rice_meal"] if game.interior_state["building"]=="B07" else ["egg_sandwich","fruit_yogurt"]
		var vendor: String="cook_hu" if game.interior_state["building"]=="B07" else "clerk_qiu"
		if not game.campus_life.at_service(vendor) or not game.relationships.alive(vendor):
			ids=[];title+="\n这里暂不售餐；可在此吃自带食物，供餐窗口在一楼。"
		for id: String in ids:options.append(["buy/"+id,str(game.economy.catalog[id]["name"])+" · %dg，现买现吃" % int(game.economy.catalog[id]["buy_price"])])
		options.append(["packed","吃背包里的食物"])
	options.append(["cancel","取消"])
	var answer: String=await game.campaign.choose(title,options)
	if answer=="packed":
		options=[]
		for id: String in FOOD:
			if game.economy.quantity(id)>0:options.append(["own/"+id,str(game.economy.catalog[id]["name"])+" ×"+str(game.economy.quantity(id))])
		options.append(["cancel","取消"])
		answer=await game.campaign.choose("选择一份自带食物；确认食用后扣一件并推进一时段。",options)
	if answer.begins_with("buy/") or answer.begins_with("own/"):
		if await game.campaign.choose("确认吃掉这份食物并花费一个时段？",[["yes","确认用餐"],["cancel","算了"]])!="yes":answer="cancel"
	game.story_system.end_sequence();busy=false
	if answer in ["nap","night"]:await sleep(answer)
	elif answer.begins_with("buy/") or answer.begins_with("own/"):
		var result: Dictionary=await dine(answer.get_slice("/",1),answer.begins_with("buy/"))
		game.show_notice(result["message"])

func sleep(mode: String) -> Dictionary:
	if not can_act("sleep") or not mode in ["nap","night"]:return {"ok":false,"message":"请先走到自己寝室的床边。"}
	if mode=="night" and game.day_clock.current_period not in [0,3,4]:return {"ok":false,"message":"现在可以小睡；晚上再睡到次日上午。"}
	busy=true;game.story_system.begin_sequence()
	var count:=1
	if mode=="night":count=posmod(game.DayClock.ORDER.find(1)-game.DayClock.ORDER.find(game.day_clock.current_period),6)
	await game.story_system.black_scene("赵慕gei拉好被子，把闹钟放在伸手够不到的地方。\n\n"+("走廊渐渐安静下来，一觉睡到次日上午。" if mode=="night" else "先把脑子里的十七个小剧场暂停。小睡之后，身体缓过来一些。"))
	for step: int in range(count):game.advance_world_period()
	for key: String in ["hp","mp","energy"]:
		var ratio: float=1.0 if mode=="night" else {"hp":.1,"mp":.15,"energy":.5}[key]
		game.combat_rules.hero[key+"_current"]=mini(int(game.combat_rules.hero[key]),int(game.combat_rules.hero[key+"_current"])+maxi(1,floori(int(game.combat_rules.hero[key])*ratio)))
	game.record_game_event("campus/slept");game.relationships.social.reset(8)
	game.story_system.end_sequence();busy=false;game.sounds.play("rest");game.show_notice("休息结束 · "+game.day_clock.display_text())
	return {"ok":true,"message":"休息结束","periods":count}

func dine(id: String, buying: bool) -> Dictionary:
	if not can_act("dine") or not id in FOOD:return {"ok":false,"message":"请先在食堂餐桌旁坐下。"}
	var hero: Dictionary=game.combat_rules.hero
	var spec: Dictionary=game.economy.catalog[id]
	if buying:
		var vendor: String="cook_hu" if game.interior_state["building"]=="B07" else "clerk_qiu"
		if not game.day_clock.current_period in [1,5,2,3] or not game.relationships.alive(vendor):return {"ok":false,"message":"窗口现在不供餐，可以吃自带食物。"}
		if not game.campus_life.at_service(vendor):return {"ok":false,"message":"请先到一楼供餐窗口点餐，二楼可以吃自带食物。"}
		if spec.get("vendor","")!=vendor or int(spec["buy_price"])>game.economy.money:return {"ok":false,"message":"钱不够，或这份餐食不在此窗口供应。"}
	elif game.economy.quantity(id)<=0:return {"ok":false,"message":"背包里没有这份食物。"}
	var needed: bool=int(hero["energy_current"])<int(hero["energy"])
	for key: String in spec.get("restore",{}):needed=needed or int(hero[key+"_current"])<int(hero[key])
	for key: String in spec.get("restore_ratio",{}):needed=needed or int(hero[key+"_current"])<int(hero[key])
	if not needed:return {"ok":false,"message":"相关状态已满，先不浪费这份食物；没有扣钱或物品。"}
	busy=true;game.story_system.begin_sequence()
	if buying:
		game.economy.money-=int(spec["buy_price"]);game.record_game_event("items_bought/"+id);game.record_game_event("trade_completed")
	else:game.economy.inventory[id]=game.economy.quantity(id)-1
	game.economy.changed.emit()
	await game.story_system.black_scene("赵慕gei端着"+str(spec["name"])+"坐下。\n\n饭要一口一口吃，离谱的事可以等吃完再离谱。")
	for key: String in spec.get("restore",{}):hero[key+"_current"]=mini(int(hero[key]),int(hero[key+"_current"])+int(spec["restore"][key]))
	for key: String in spec.get("restore_ratio",{}):hero[key+"_current"]=mini(int(hero[key]),int(hero[key+"_current"])+maxi(1,floori(int(hero[key])*float(spec["restore_ratio"][key]))))
	hero["energy_current"]=mini(int(hero["energy"]),int(hero["energy_current"])+maxi(1,floori(int(hero["energy"])*.1)))
	game.record_game_event("item_used/"+id);game.record_game_event("campus/dined");game.advance_world_period();game.relationships.social.reset(8)
	game.story_system.end_sequence();busy=false;game.sounds.play("heal")
	return {"ok":true,"message":"吃完了"+str(spec["name"])+" · "+game.day_clock.display_text()}
