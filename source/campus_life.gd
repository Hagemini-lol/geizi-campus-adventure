extends RefCounted

# Schedules are sampled once from day/period/identity, never from frame time.
var game: Node2D
var print_room:=2
const STAFF={"cook_hu":"胡师傅","clerk_qiu":"邱姐","worker_hou":"侯师傅","warden_chen":"陈阿姨","warden_zhou":"周叔","print_luo":"罗老师","sports_du":"杜老师","history_tian":"田老师","chemistry_he":"何老师","math_feng":"冯老师","chinese_xu":"许老师"}
const LAYOUTS={
	"cafeteria":{"floor":[60,270,1420,680],"boxes":[[435,175,625,130],[315,375,210,145],[665,375,210,145],[1010,375,210,145],[295,570,215,145],[660,570,215,145],[1020,570,220,145],[100,550,80,185]]},
	"dorm":{"floor":[60,80,1420,870],"boxes":[[315,166,165,312],[582,166,165,312],[846,166,166,312],[235,665,198,180],[635,665,200,180],[1080,665,200,180],[160,90,95,270],[1340,440,100,270],[1070,80,18,340],[1080,350,115,35],[1280,350,190,35],[1100,90,80,120],[1340,90,100,140]]},
	"gym":{"floor":[60,190,1420,760],"boxes":[[324,420,61,105],[1150,420,65,105],[420,190,220,45],[900,190,240,45]]},
	"print":{"floor":[60,270,1420,680],"boxes":[[520,80,455,210],[330,375,380,190],[840,375,420,190],[545,620,455,200],[90,600,120,180]]}
}

func configure(owner_game: Node2D) -> void:
	game=owner_game
	for id: String in STAFF:
		var entry: Dictionary
		if id not in ["cook_hu","clerk_qiu","worker_hou","warden_chen","warden_zhou"]:
			entry=game.npc_catalog.characters["english_teacher" if id in ["print_luo","chemistry_he","chinese_xu"] else "homeroom_teacher" if id=="history_tian" else "wen_cong"].duplicate(true)
		else:
			entry={"source":"res://assets/characters/staff_v15/"+id+".png","height_px":104,"source_regions":{}}
			for d: int in range(4):entry["source_regions"][["front","back","left","right"][d]]=[128*d,0,128,160]
		entry["id"]=id;entry["display_name"]=STAFF[id];game.npc_catalog.characters[id]=entry
	install_interiors()

func install_interiors() -> void:
	for spec: Array in [["B07","食堂","cafeteria"],["B08","小食堂","cafeteria"],["B03","体育馆","gym"],["B16","宿舍","dorm"]]:
		var building: Dictionary=game.interior_info["buildings"]["B02"].duplicate(true)
		building["id"]=spec[0];building["name"]=spec[1]
		building["floor_count"]=3 if spec[0]=="B16" else 1
		building["floors"].resize(building["floor_count"])
		for row: Dictionary in building["floors"]:
			if spec[0]!="B16":row["rooms"].resize(1)
			for room: Dictionary in row["rooms"]:
				room["class10"]=false;room["office"]=false
				room["life_layout"]=spec[2]
				room["name"]="用餐大厅" if spec[2]=="cafeteria" else "篮球场与环形跑道" if spec[2]=="gym" else ("男生" if row["floor"]==2 else "女生")+str(int(row["floor"])*100+int(room["index"])+1)+"室 · 三人寝独卫"
				if spec[0]=="B16" and row["floor"]==1:
					room.erase("life_layout");room["office"]=true;room["office_asset"]="office_wood"
					room["name"]=["宿管值班与访客区","公共自习室","失物登记室","女生宿管接待室","洗衣登记处","维修值班室"][int(room["index"])]
		game.interior_info["buildings"][spec[0]]=building
	for entry: Dictionary in game.interior_info["entrances"]:
		if entry["id"] in ["B03","B07","B08","B16"]:entry["has_interior"]=true
	var office: Dictionary=game.interior_info["buildings"]["B15"]
	var best:=-INF
	for room: Dictionary in office["floors"][0]["rooms"]:
		var end: float=float(room["span"][1])*24
		if end<float(office["stairs_center_x"]) and end>best:best=end;print_room=int(room["index"])
	var printing: Dictionary=office["floors"][0]["rooms"][print_room]
	printing["name"]="打印室";printing["life_layout"]="print";printing["office"]=true

func chance(id: String, threshold: int) -> bool:
	return absi((id+"/"+str(game.economy.day_serial)+"/"+str(game.day_clock.current_period)).hash())%100<threshold

func teacher_for(building: String, period: int) -> String:
	return ({"B12":["history_tian","chemistry_he"],"B05":["math_feng","chinese_xu"]}.get(building,["homeroom_teacher","english_teacher"]))[0 if period==1 else 1]

func location(id: String) -> String:
	var p: int=game.day_clock.current_period
	var printing: String="B15:1:"+str(print_room)
	if id in ["history_tian","chemistry_he","math_feng","chinese_xu"]:
		var school: String="B12" if id in ["history_tian","chemistry_he"] else "B05"
		if p in [1,2] and teacher_for(school,p)==id:return school+":3:0"
		if p in [1,5,2]:return printing if chance(id,40) else "B15:2:0"
		return ""
	match id:
		"cook_hu":return "B07:1:0" if p in [1,5,2,3] else ""
		"clerk_qiu":return "B08:1:0" if p in [1,5,2,3] else ""
		"warden_chen":return "B16:1:3"
		"warden_zhou":return "B16:1:0"
		"worker_hou":return "B15:1:corridor" if p in [1,2] else "B16:1:5" if p in [5,3] else ""
		"print_luo":return printing if p in [1,5,2] else ""
		"sports_du":return "B03:1:0" if p in [1,2,3] else "B07:1:0" if p==5 else ""
		"homeroom_teacher","english_teacher":
			if p==(1 if id=="homeroom_teacher" else 2):return "B01:3:0"
			if p in [1,2]:return printing if chance(id,40) else "B15:2:0"
			if p==5:return "B07:1:0" if chance(id,55) else printing
	return ""

func student_location(id: String, home: String) -> String:
	if game.day_clock.current_period==5 and chance(id,55):return "B07:1:0" if chance(id+"canteen",75) else "B08:1:0"
	# Services remain accessible in public areas; private sleeping rooms are separate.
	if game.day_clock.current_period in [3,4] and chance(id,45):return "B16:1:1"
	return home

func layout(name: String) -> Dictionary:
	return LAYOUTS.get(name,{})

func polygon(name: String) -> PackedVector2Array:
	var r: Array=LAYOUTS[name]["floor"]
	return PackedVector2Array([Vector2(r[0],r[1])*.3,Vector2(r[0]+r[2],r[1])*.3,Vector2(r[0]+r[2],r[1]+r[3])*.3,Vector2(r[0],r[1]+r[3])*.3])

func source(name: String) -> String:
	return game.package_root.path_join("资源/新增内景/v1.5/"+name+".png")

func configure_room(scene: Node2D, name: String) -> void:
	for value: Array in LAYOUTS[name]["boxes"]:
		var box:=Rect2(value[0]*.3,value[1]*.3,value[2]*.3,value[3]*.3)
		scene.blockers.append(box)
		scene.furniture_art.append({"rect":box,"edge":box.end.y})
	var direct: bool=scene.state["building"] in ["B03","B07","B08"]
	for side: String in ["front","rear"]:
		var at:=Vector2(1400,350 if side=="front" else 885)*.3
		if name=="dorm" and side=="front":continue # One private room entrance.
		scene.portal(at,Rect2(at-Vector2(10,7),Vector2(20,14)),"outside" if direct else "corridor",{"side":side,"art_rect":Rect2(at-Vector2(12,55),Vector2(24,65))})

func populate(manager: Node2D, image: Image) -> bool:
	var scene: Node2D=manager.scene
	var here: String="%s:%s:%s" % [scene.state["building"],scene.state["floor"],scene.state.get("room",-1) if scene.state["kind"]=="classroom" else "corridor"]
	var managed: bool=not scene.life_layout.is_empty() or scene.state["building"] in ["B15","B16"] or scene.is_office
	if not managed:return false
	var ids: Array=[]
	for id: String in STAFF.keys()+["homeroom_teacher","english_teacher"]:
		if location(id)==here:ids.append(id)
	if game.campaign.active():
		for id: String in game.npc_catalog.NAMED_IDS+["wen_cong"]:
			if game.campaign.scheduled_location(id)==here:ids.append(id)
	var bounds:=Rect2(25,100,260,80) if scene.life_layout.is_empty() else Rect2(30,95,390,175)
	for i: int in range(ids.size()):
		var proposed:=Vector2(bounds.position.x+30+float(i%4)*60,bounds.position.y+20+float(i/4)*42)
		if ids[i] in ["cook_hu","clerk_qiu"]:proposed=Vector2(520,330)*.3
		add_actor(manager,str(ids[i]),proposed,bounds)
	if scene.life_layout=="cafeteria":
		var count: int=8 if game.day_clock.current_period==5 else 3 if game.day_clock.current_period in [1,2,3] else 0
		for i: int in range(count):add_actor(manager,game.npc_catalog.ORDINARY_IDS[i%6],Vector2(55+float(i%4)*97,140+float(i/4)*105),bounds,false)
	elif scene.state["building"]=="B16" and scene.state["kind"]=="classroom" and int(scene.state["floor"])>1 and game.day_clock.current_period in [3,4,0]:
		var id: String="student_male" if int(scene.state["floor"])==2 else "student_female"
		for i: int in range(2):add_actor(manager,id,Vector2(160+80*i,175),bounds,false)
	return true

func add_actor(manager: Node2D, id: String, proposed: Vector2, bounds: Rect2, named: bool=true) -> void:
	if not game.relationships.alive(id):return
	var at: Vector2=manager.valid_point(proposed,bounds)
	if not is_finite(at.x):return
	var uid: String="life/%s/%d/%d/%s/%d/%d" % [manager.scene.state["building"],int(manager.scene.state["floor"]),int(manager.scene.state.get("room",-1)),id,roundi(proposed.x),roundi(proposed.y)]
	var record: Dictionary=manager.make_record(uid,id,str(game.npc_catalog.characters[id]["display_name"]) if named else "同学",at,0,named)
	if not game.relationships.record_alive(record):return
	var sprite:=Sprite2D.new();sprite.position=at;sprite.z_index=10;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;manager.add_child(sprite)
	var frames: Array[Texture2D]=[]
	var art: Image=game.npc_catalog.source_image(id)
	for d: int in range(4):
		var crop: Image=game.npc_catalog.frame(id,d,art);crop.generate_mipmaps();frames.append(ImageTexture.create_from_image(crop));manager.texture_bytes+=crop.get_data_size()
	record.merge({"sprite":sprite,"frames":frames,"range":bounds,"path":PackedVector2Array(),"wait":2.0})
	if id in ["cook_hu","clerk_qiu","worker_hou","warden_chen","warden_zhou"]:
		var gait:=preload("res://life_walk.gd").new()
		if gait.configure(game.npc_catalog.project_root,game.npc_catalog.characters[id],sprite,record["height"],frames):record["gait"]=gait;manager.texture_bytes+=1310720
	elif game.walk_library.has(id):
		var gait:=preload("res://walk_animation.gd").new()
		if gait.configure(game.npc_catalog.project_root,game.walk_library[id],sprite,record["height"],frames):record["gait"]=gait
	manager.records.append(record);manager.face(record,0)
	# Staff work at their posts; students move only when a walk sheet exists.
	if record.has("gait") and id not in ["cook_hu","clerk_qiu","warden_chen","warden_zhou"]:
		manager.movers.append(record);manager.set_process(true)

func handle(item: Dictionary) -> bool:
	if item["action"]=="entrance" and item.get("building","") in ["B03","B07","B08"]:
		game.change_interior({"building":item["building"],"floor":1,"kind":"classroom","room":0});return true
	if item["action"]=="room" and game.interior_state.get("building","")=="B16" and int(game.interior_state.get("floor",1))==3:
		game.show_notice("女生寝室是私人空间。请到一楼女生宿管接待室登记、会面或报修。");return true
	if item["action"]!="npc" or game.terrain.current_scene.npcs==null:return false
	var record: Dictionary=game.terrain.current_scene.npcs.find(item["uid"])
	if record.get("character","") not in STAFF:return false
	talk(str(record["character"]));return true

func at_service(id: String) -> bool:
	return not location(id).is_empty() and game.campaign.location_matches(location(id))

func recipe_text(recipe: Dictionary) -> String:
	var parts: Array[String]=[]
	for id: String in recipe["ingredients"]:parts.append(str(game.economy.catalog[id]["name"])+" ×"+str(int(recipe["ingredients"][id])))
	return str(recipe["name"])+"："+"、".join(parts)+"；加工费 %dg；耗时一时段" % int(recipe["fee"])

func trade(id: String) -> void:
	if not at_service(id):return
	var choices: Array=[]
	for item: String in game.economy.catalog:
		var spec: Dictionary=game.economy.catalog[item]
		if spec.get("vendor","")==id and int(spec.get("buy_price",-1))>=0:choices.append([item,str(spec["name"])+" · %dg / 份" % int(spec["buy_price"])])
	choices.append(["cancel","取消"])
	var item: String=await game.campaign.choose("购买一份物资 · 不推进时间\n所持 %dg" % game.economy.money,choices)
	if item=="cancel" or not at_service(id):return
	var result: Dictionary=game.economy.trade(item,1,true)
	if result["ok"]:game.sounds.play("trade");game.record_game_event("items_bought/"+item);game.record_game_event("trade_completed")
	game.show_notice(result["message"])

func craft(id: String) -> void:
	if not at_service(id):return
	var choices: Array=[]
	for key: String in game.economy.recipes:
		var recipe: Dictionary=game.economy.recipes[key]
		if recipe.get("station","")==id:choices.append([key,recipe_text(recipe)])
	choices.append(["cancel","取消"])
	var key: String=await game.campaign.choose("工作人员加工／兑换\n成功后推进一时段；材料不足或取消不扣物品和时间。",choices)
	if key=="cancel" or not at_service(id):return
	var result: Dictionary=game.economy.craft(key)
	if result["ok"]:game.sounds.play("paper" if id=="print_luo" else "craft");game.record_game_event("crafted/"+key);game.advance_world_period()
	game.show_notice(result["message"])

func talk(id: String) -> void:
	if game.story_system.running:return
	game.story_system.begin_sequence()
	var options: Array=[["chat","聊聊今天的工作"]]
	if not game.economy.catalog.values().filter(func(item: Dictionary):return item.get("vendor","")==id).is_empty():options.append(["supplies","购买校园物资"])
	if not game.economy.recipes.values().filter(func(recipe: Dictionary):return recipe.get("station","")==id).is_empty():options.append(["craft","加工／分类兑换"])
	options.append_array(game.side_quests.options_for(id));options.append(["close","告辞"])
	var answer: String=await game.campaign.choose(str(STAFF[id])+" · "+game.day_clock.display_text(),options)
	if answer.begins_with("side/"):await game.side_quests.service(id,answer.trim_prefix("side/"))
	elif answer=="supplies":await trade(id)
	elif answer=="craft":await craft(id)
	elif answer=="chat":
		var lines: Dictionary={"cook_hu":"午休排队时别空着肚子。份量够不够，等大家吃完再来问我，别只看锅里还剩多少。","clerk_qiu":"找零和收款都要让人看清。我怕的不是忙，是有人带着误会走。","worker_hou":"午休和考试时停噪声作业。你们可以帮忙登记绕行路线，电路和高处留给持证工人。","warden_chen":"宿舍一间三人，每间都有独立卫生间。女生层在三楼，男生层在二楼；访客在一楼登记，不替别人开私人房门。","warden_zhou":"夜里水管响了先报修，不一定是有人故意吵。值班表上有我，别让室友互相猜。","print_luo":"这是进办公楼后左手第一间打印室。老师有课时会回教室，没课可能来印资料；校对时先看版本和页码。","sports_du":"篮球场外这一圈是跑道。跑步按同一方向，取球先看跑道，不让练球和跑步的人撞到一起。"}
		await game.campaign.dialog([{"actor":id,"text":lines.get(id,"上课时我在自己的教室，没课会去办公室备课，也可能到打印室核样。拿到不同版本的资料可以直接问，别为了怕打扰就一直猜。")}])
	game.story_system.end_sequence()
