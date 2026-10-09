extends RefCounted

var game: Node2D
var affinity: Dictionary={}
var dead: Dictionary={}
var daily: Dictionary={}
var grievances: Array=[]
var revision:=0
var busy:=false
var content: Dictionary={}
var milestones: Dictionary={}
var romances: Dictionary={}
const COMPANIONS: Array[String]=["lao_li","lao_chou","fei_yan","lao_ao","lao_shuo","yang_zi","lao_dong","la_jiao","wr"]
const ADULTS: Array[String]=["homeroom_teacher","english_teacher","wen_cong","print_luo","sports_du","history_tian","chemistry_he","math_feng","chinese_xu","cook_hu","clerk_qiu","worker_hou","warden_chen","warden_zhou"]

func identity(record: Dictionary) -> String:
	return "local/"+str(record["uid"]) if record.get("character","") in game.npc_catalog.ORDINARY_IDS else str(record.get("character",""))

func alive(id: String) -> bool:return not dead.has(id)
func record_alive(record: Dictionary) -> bool:return alive(identity(record))
func bond(id: String) -> int:
	return int(affinity.get(id,game.campaign.flags.get("BOND_"+id,0)))

func configure() -> void:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(game.package_root.path_join("关系与攻略配置.json")))
	if value is Dictionary:content=value

func change(id: String, amount: int, story_gain: bool=false) -> void:
	# Gouga's positive bond belongs exclusively to the five non-repeatable stories.
	if id=="gou_ga" and amount>0 and not story_gain:return
	affinity[id]=clampi(bond(id)+amount,-100,100);revision+=1
	if not id.begins_with("local/"):game.campaign.flags["BOND_"+id]=affinity[id]

func once(id: String, action: String, amount: int) -> bool:
	var key:=id+"/"+action
	if int(daily.get(key,-1))==game.economy.day_serial:return false
	daily[key]=game.economy.day_serial;change(id,amount);return true

func massacre() -> bool:
	return dead.size()>=5 or COMPANIONS.filter(func(id: String):return not alive(id)).size()>=3

func journal() -> String:
	var text:="人际关系与生存\n"+("屠杀线：幸存者不再把你当作保护者。" if massacre() else "角色死亡永久记录在当前存档；切磋不致死，击杀不会给予刷级奖励。")+"\n死亡 %d 人\n" % dead.size()
	for id: String in COMPANIONS+ADULTS+["gou_ga"]:
		text+="\n%s：%s · 好感 %d" % [game.npc_catalog.characters.get(id,{}).get("display_name",id),"生还" if alive(id) else "已死亡",bond(id)]
	for row: Dictionary in grievances:text+="\n"+str(row["text"])
	text+="\n\n攻略：同学好感60开放恋爱话题，85可认真表白；可以拒绝或保持朋友。工作人员保持师生/工作边界。已建立的关系会回应失信与伤害。\n勾尬只能通过五段关键剧情获得好感，80开放恋爱话题，90及其他真相条件达标可救赎；恋爱不是救人的交换条件。"
	for id: String in romances:
		text+="\n"+str(game.npc_catalog.characters.get(id,{}).get("display_name",id))+"："+("交往中" if romances[id]=="together" and alive(id) and bond(id)>=40 else "关系破裂" if romances[id]=="together" and alive(id) else "留存的约定" if not alive(id) else "保持朋友")
	var stage:=next_gou_story()
	if not stage.is_empty():text+="\n勾尬下一段："+stage["title"]+"\n"+gou_requirement(stage)
	return text

func open_journal() -> void:
	if game.story_system.running or game.battle_view.visible:return
	game.close_menu();game.story_system.begin_sequence()
	await game.campaign.choose(journal(),[["close","关闭关系与攻略手册"]])
	game.story_system.end_sequence()

func kill(record: Dictionary) -> bool:
	var id:=identity(record)
	if not alive(id):return false
	dead[id]={"character":record["character"],"name":record.get("name",id),"scene":game.interior_state.duplicate(true),"day":game.economy.day_serial,"period":game.day_clock.current_period}
	revision+=1
	for companion: String in COMPANIONS:
		if alive(companion):change(companion,-40)
	var witness: String=""
	for companion: String in COMPANIONS:
		if alive(companion):witness=companion;break
	var text: String=(str(game.npc_catalog.characters[witness]["display_name"])+"：" if not witness.is_empty() else "留下的记录：")+"你杀了"+str(record.get("name",id))+"。我们说好的是保护人，不是把不同意你的人都清掉。"
	grievances.append({"actor":witness if not witness.is_empty() else "system","text":text})
	while grievances.size()>40:grievances.pop_front()
	game.campaign.flags["F_CIVILIAN_SAFE"]=false
	change("gou_ga",-40)
	if massacre():game.campaign.flags["GENOCIDE_ROUTE"]=true
	game.record_game_event("npc_killed/"+str(record["character"]))
	return true

func speaker(id: String) -> String:
	if id in ["system","hero","zhao_mugei"] or alive(id):return id
	return "system"

func adapt_lines(lines: Array) -> Array:
	var result: Array=lines.duplicate(true)
	for row: Dictionary in result:
		var actor: String=row.get("actor","system")
		if speaker(actor)=="system" and actor!="system":
			row["actor"]="system"
			row["text"]="留存的笔记 · "+str(game.npc_catalog.characters.get(actor,{}).get("display_name",actor))+"\n"+str(row["text"])
	return result

func reaction(record: Dictionary, action: String) -> Array:
	var id:=identity(record);var actor: String=record["character"]
	var text:=""
	if not grievances.is_empty() and actor in COMPANIONS and bond(id)<0:
		text="我记得"+str(dead.values()[-1]["name"])+"。你现在来和我说笑，我做不到。想让我再信你，先停止伤害别人；有些事也不会因为几句好话就消失。"
	elif action=="flirt":
		if actor in ADULTS:text="夸奖我收到了，不过我们还是按老师、工作人员和学生的身份相处。把尊重放在玩笑前面。"
		elif bond(id)<10:text="你忽然说我今天很好看，我有点接不住。先把彼此当普通朋友慢慢认识吧。"
		else:text="你说跟我一起走这段路很开心……我也是。下次不用特地找借口，直接叫我就好。"
	elif bond(id)<0:text="我还在生气。你可以说，我会听，但别指望所有事情立刻恢复原样。"
	else:
		var lines: Dictionary={"lao_li":"我习惯先把东西准备齐，再说没事。你愿意问一句我累不累，比再多准备一张清单都有用。","fei_yan":"学会新招不等于每次都要用。能收住手，也算本事。","lao_ao":"坐着的时候才发现，别人愿意等你，比自己跑得快更难得。","yang_zi":"我话是多，你要真不想听可以告诉我。别一边忍一边走远，我会乱猜。","lao_chou":"我查线索不是因为不信人。是想让被冤枉的人，有东西能证明自己。","lao_dong":"我把该说的事拖了很久。现在有人愿意坐下来听，我会把话说完。","la_jiao":"点名的时候我会停一下，等每个人应声。不是为了整齐，是怕谁被漏了。","wr":"你不用假装懂我喜欢的书。愿意听我讲一点，再说你自己的想法，就已经很好。","cook_hu":"今天锅里的份量是够的。吃完再忙，别总把自己那一顿往后推。","worker_hou":"有时候先停工，才是把工作做好。人也一样，不用一直撑着。"}
		text=lines.get(actor,"今天的"+game.day_clock.display_text()+"能坐下来聊几句挺好。校园里每天都有人忙着自己的事，能被认真听见，我会记得。")
	if action=="chat":once(id,"chat",3)
	elif action=="flirt" and not actor in ADULTS and bond(id)>=0:once(id,"flirt",2)
	return [{"actor":"zhao_mugei","text":"今天想听你说说自己的事。" if action=="chat" else "跟你一起待着挺开心的。也想听听你怎么想。"},{"actor":actor,"text":text}]

func open(record: Dictionary) -> void:
	if busy or not record_alive(record) or game.story_system.running:return
	busy=true;game.story_system.begin_sequence()
	var id:=identity(record)
	var options: Array=[["chat","对话：近况与心事"],["flirt","调情：表达好感 / 夸奖"],["plot","剧情 / 支线 / 工作服务"],["duel","战斗：点到为止的切磋"],["kick","开大脚：踢开对方（伤害关系）"],["kill","击杀：战斗至死亡（不可逆）"],["apology","道歉：承认自己的行为"],["close","告辞"]]
	if romance_available(record):options.push_front(["romance","恋爱话题 · "+romance_profile(record).get("title","彼此的心意")])
	if record["character"]=="gou_ga" and not next_gou_story().is_empty():options.push_front(["gou_story","攻略剧情 · "+next_gou_story()["title"]])
	var answer: String=await game.campaign.choose(str(record["name"])+" · 好感 %d" % bond(id),options)
	if answer in ["chat","flirt"]:await game.campaign.dialog(reaction(record,answer))
	elif answer=="romance":await romance(record)
	elif answer=="gou_story":await gou_story()
	elif answer=="apology":
		if bond(id)<0:once(id,"apology",2)
		await game.campaign.dialog([{"actor":record["character"],"text":"我听见了。但你得用之后的行为证明。有些伤害不能挽回，也不该靠送礼或反复道歉一笔勾销。"}])
	elif answer=="kick":
		await kick(record)
		change(id,-20)
		for ally: String in COMPANIONS:
			if ally!=id and alive(ally):change(ally,-5)
		await game.campaign.dialog([{"actor":record["character"],"text":"别动手！你有意见可以说，不能拿别人撒气。"}])
	elif answer=="kill":
		answer="lethal" if await game.campaign.choose("击杀会永久移除当前角色，严重降低队友好感，并可能改变剧情路线。切磋不致死。",[["yes","发动致命战斗"],["no","收手离开"]])=="yes" else "close"
	game.story_system.end_sequence();busy=false
	if answer in ["duel","lethal"]:start_battle(record,answer=="lethal")
	elif answer=="plot":
		var actor: String=record["character"]
		if actor in game.campus_life.STAFF:game.campus_life.talk(actor)
		elif game.campaign.active() and actor in COMPANIONS+["gou_ga"]:game.campaign.npc_service(actor)
		elif game.story_system.data["role_greetings"].has(actor):game.story_system.named_conversation(record)
		else:game.dialogue_view.greet(record)

func start_battle(record: Dictionary, lethal: bool) -> bool:
	if not record_alive(record):return false
	var actor: String=record["character"]
	var id: String="npc/"+actor
	var spec: Dictionary=game.combat_rules.data["monsters"]["ink_slime"].duplicate(true)
	spec.merge({"name":record["name"],"rarity":"normal","scripted_only":true,"physical_reduction":0.1,"elemental_reductions":{},"multipliers":{"hp":4,"attack":.8,"defense":1,"magic_resistance":.7}},true)
	spec.erase("portrait_atlas");spec.erase("tactics")
	game.combat_rules.data["monsters"][id]=spec
	var level:=clampi(int(game.combat_rules.hero["level"]),1,60)
	var stats: Dictionary=game.combat_rules.monster_stats(id,level)
	var image: Image=game.npc_catalog.dialogue_portrait(actor)
	var encounter: Dictionary={"monster":{"uid":"npc-duel","id":id,"level":level,"hp":stats["hp"]},"portrait":ImageTexture.create_from_image(image),"npc_target":record.duplicate(),"lethal":lethal}
	var started: bool=game.battle_view.start(encounter,"npc")
	if not started:game.combat_rules.data["monsters"].erase(id)
	return started

func romance_profile(record: Dictionary) -> Dictionary:
	return content.get("romance",{}).get(record["character"],content.get("romance",{}).get("ordinary",{}))

func romance_available(record: Dictionary) -> bool:
	return record_alive(record) and not record["character"] in ADULTS and not massacre() and bond(identity(record))>=int(content.get("gou_topic_affinity",80) if record["character"]=="gou_ga" else content.get("topic_affinity",60))

func targeted(lines: Array, record: Dictionary) -> Array:
	var result: Array=lines.duplicate(true)
	for row: Dictionary in result:
		if row.get("actor","")=="target":row["actor"]=record["character"]
	return result

func romance(record: Dictionary) -> void:
	if not romance_available(record):return
	var id:=identity(record);var profile:=romance_profile(record)
	await game.campaign.dialog(targeted(profile.get("topic",[]),record))
	var choices: Array=[["friend","保持朋友，尊重彼此的步调"],["close","今天聊到这里"]]
	if romances.get(id,"")=="together":choices.push_front(["revisit","约会：一起走一段 / 坐一会儿"]);choices.append(["end","认真说明：结束交往"])
	elif bond(id)>=int(content.get("confess_affinity",85)):choices.push_front(["confess","认真表白：愿不愿意试着交往？"])
	var answer: String=await game.campaign.choose("彼此的心意 · 好感 %d\n表白需要85好感；保持朋友不会扣好感。" % bond(id),choices)
	if answer=="confess":
		# A second simultaneous relationship needs honest consent; this story does not assume it.
		for other: String in romances:
			if other!=id and romances[other]=="together" and alive(other):
				await game.campaign.dialog([{"actor":record["character"],"text":"你还有一段没有说清的关系。先认真面对那个人，我不想让谁被蒙在鼓里。"}]);return
		romances[id]="together";revision+=1
		await game.campaign.dialog(targeted(profile.get("accept",[]),record));game.record_game_event("romance/"+str(record["character"]))
	elif answer=="revisit":
		await game.campaign.dialog(targeted(profile.get("revisit",[]),record))
		game.advance_world_period()
	elif answer in ["friend","end"]:
		if romances.get(id,"")!="together" or answer=="end":romances[id]="friends";revision+=1
		await game.campaign.dialog(targeted(profile.get("friend",[]),record))

func next_gou_story() -> Dictionary:
	for row: Dictionary in content.get("gou_stories",[]):
		if not milestones.get(row["id"],false):return row
	return {}

func gou_requirement(row: Dictionary) -> String:
	var title: String="相关章节"
	for node: Dictionary in game.campaign.data.get("nodes",[]):
		if node["id"]==row.get("after",""):title=node["title"];break
	var flags_text: Array[String]=[]
	var labels: Dictionary={"F_LI_CLEAR":"牢李案已澄清","F_YANG_CLEAR":"阳子案已澄清","F_TRUTH":"门底真相已核实","F_CIVILIAN_SAFE":"所有普通人安全"}
	for flag: String in row.get("flags",{}):flags_text.append(labels.get(flag,"相关证据已核实"))
	return "相关主线：%s · 真碎片至少%d（不消耗） · 理智%d · 理解%d/5\n%s" % [title,int(row.get("shards",0)),int(row.get("san",0)),int(row.get("understand",0)),"、".join(flags_text)]

func gou_ready(row: Dictionary) -> bool:
	if row.is_empty() or not alive("gou_ga") or massacre() or not row["after"] in game.campaign.done:return false
	if game.economy.quantity("seal_shard")<int(row.get("shards",0)) or game.campaign.san()<int(row.get("san",0)) or int(game.campaign.flags.get("GOU_UNDERSTAND",0))<int(row.get("understand",0)):return false
	for flag: String in row.get("flags",{}):
		if game.campaign.flags.get(flag,false)!=row["flags"][flag]:return false
	return true

func gou_story() -> void:
	var row:=next_gou_story()
	if not gou_ready(row):
		await game.campaign.dialog([{"actor":"system","text":"这一段还需要共同经历，无法靠重复聊天解锁。\n"+gou_requirement(row)}]);return
	await game.campaign.dialog(row["dialogue"])
	var answer: String=await game.campaign.choose(row["title"],row["choices"])
	if answer=="cancel":return
	if answer!=row["correct"]:await game.campaign.dialog(row["retry"]);change("gou_ga",-3);return
	milestones[row["id"]]=true;change("gou_ga",int(row["gain"]),true)
	await game.campaign.dialog(row["resolution"])
	game.record_game_event("relationship/"+str(row["id"]));game.advance_world_period()

func final_relief() -> int:
	return 0 if not alive("gou_ga") or massacre() else mini(30,floori(maxi(0,bond("gou_ga"))*30/100.0))

func redemption_ready() -> bool:
	return alive("gou_ga") and dead.is_empty() and not massacre() and bond("gou_ga")>=int(content.get("gou_redemption_affinity",90)) and milestones.get("gou_5",false) and game.campaign.flags.get("F_TRUTH",false) and game.campaign.flags.get("F_CIVILIAN_SAFE",false) and game.campaign.san()>=60 and int(game.campaign.flags.get("GOU_UNDERSTAND",0))>=4 and game.economy.quantity("seal_shard")>=4

func kick(record: Dictionary) -> void:
	game.sounds.play("attack_swing");game.sounds.play("impact")
	var manager: Node2D=game.terrain.current_scene.npcs
	var direction: Vector2=(record["at"]-game.player.position).normalized()
	if direction.is_zero_approx():direction=Vector2.RIGHT
	var nav: RefCounted=game.motion_navigation()
	var route: PackedVector2Array=nav.route(record["at"],nav.safe_landing(record["at"]+direction*14))
	# Seated/baked actors react in dialogue; moving actors recoil only along a valid short path.
	if record.has("sprite") and not record.get("seated",false) and not route.is_empty():
		var sprite: Sprite2D=record["sprite"];var old: Vector2=sprite.position
		var tween:=game.create_tween()
		var previous:=old
		for at: Vector2 in route:
			if at.distance_to(old)>22:break
			tween.tween_property(sprite,"position",at,maxf(.025,previous.distance_to(at)/90));previous=at
		if tween.get_total_elapsed_time()==0:tween.tween_interval(.05)
		await tween.finished
		record["at"]=sprite.position;record["path"]=PackedVector2Array();record["wait"]=1.5
	manager.queue_redraw()

func snapshot() -> Dictionary:return {"version":1,"affinity":affinity.duplicate(),"dead":dead.duplicate(true),"daily":daily.duplicate(),"grievances":grievances.duplicate(true),"milestones":milestones.duplicate(),"romances":romances.duplicate()}

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1:return false
	for key: String in ["affinity","dead","daily"]:
		if not value.get(key) is Dictionary or value[key].size()>10000:return false
	for id: Variant in value["affinity"]:
		if not id is String or id.length()>180:return false
		var n: Variant=value["affinity"][id]
		if not (n is int or n is float) or not is_finite(float(n)) or n!=floor(float(n)) or n< -100 or n>100:return false
	for id: Variant in value["dead"]:
		var row: Variant=value["dead"][id]
		if not id is String or not row is Dictionary or not row.get("character") is String or not row.get("name") is String or not row.get("scene") is Dictionary:return false
		for field: String in ["day","period"]:
			var n: Variant=row.get(field)
			if not (n is int or n is float) or not is_finite(float(n)) or n!=floor(float(n)) or n<0 or (field=="period" and n>5):return false
	for key: Variant in value["daily"]:
		var n: Variant=value["daily"][key]
		if not key is String or not (n is int or n is float) or not is_finite(float(n)) or n!=floor(float(n)) or n<0:return false
	if not value.get("grievances") is Array or value["grievances"].size()>40:return false
	for row: Variant in value["grievances"]:
		if not row is Dictionary or not row.get("actor") is String or not row.get("text") is String or row["text"].length()>1000:return false
	if not value.get("milestones",{}) is Dictionary or not value.get("romances",{}) is Dictionary:return false
	if value.get("milestones",{}).size()>5 or value.get("romances",{}).size()>10000:return false
	for key: Variant in value.get("milestones",{}):
		if not key in ["gou_1","gou_2","gou_3","gou_4","gou_5"] or not value["milestones"][key] is bool:return false
	for key: Variant in value.get("romances",{}):
		if not key is String or key.length()>180 or not value["romances"][key] in ["together","friends"]:return false
	return true

func restore(value: Dictionary) -> void:
	affinity=value.get("affinity",{}).duplicate();dead=value.get("dead",{}).duplicate(true);daily=value.get("daily",{}).duplicate();grievances=value.get("grievances",[]).duplicate(true);revision+=1;busy=false
	milestones=value.get("milestones",{}).duplicate();romances=value.get("romances",{}).duplicate()
	for id: String in affinity:affinity[id]=int(affinity[id])
	for id: String in daily:daily[id]=int(daily[id])
	for id: String in dead:
		for field: String in ["day","period"]:dead[id][field]=int(dead[id][field])
		for field: String in ["floor","room"]:
			if dead[id]["scene"].has(field):dead[id]["scene"][field]=int(dead[id]["scene"][field])
