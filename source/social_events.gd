extends RefCounted

var game: Node2D
var moments: Dictionary={}
var cursors: Dictionary={}
var scan_left:=0.0
var grace:=5.0
var pending_uid:=""
var pending_scene:=0
var warning_left:=0.0

func profile(actor: String) -> Dictionary:
	var profiles: Dictionary=game.relationships.content.get("social",{}).get("profiles",{})
	return profiles.get(actor,profiles.get("ordinary",{}))

func say(record: Dictionary, context: String) -> String:
	var rows: Array=profile(record["character"]).get(context,[])
	if rows.is_empty():return game.voice.reply(record["character"],"angry")
	var id: String=game.relationships.identity(record)
	var key: String=id+"/"+context
	var at: int=int(cursors.get(key,0))%rows.size();cursors[key]=(at+1)%rows.size()
	return str(rows[at]["text"]).replace("{name}",str(record.get("name","同学")))

func remember(id: String, event: String) -> void:
	moments[id]={"event":event,"day":game.economy.day_serial}

func response_context(record: Dictionary) -> String:
	var rel: RefCounted=game.relationships
	var id: String=rel.identity(record);var bond: int=rel.bond(id)
	if bond<0:
		if rel.romances.get(id,"")=="together":return "lover_hurt"
		return "hostile" if bond<= -60 else "bitter" if bond<= -25 else "cold"
	if rel.romances.get(id,"")=="together":
		if bond<40:return "lover_hurt"
		return "after_date" if moments.get(id,{}).get("event","")=="date" else "after_confess"
	var event: String=moments.get(id,{}).get("event","")
	var age: int=game.economy.day_serial-int(moments.get(id,{}).get("day",0))
	if event in ["apology","spared"] and age>2:return ""
	if event in ["friends","breakup","apology","spared"]:return "after_"+event
	return ""

func response(record: Dictionary) -> String:
	var context: String=response_context(record)
	if context.is_empty():return ""
	var text: String=say(record,context)
	if context in ["after_confess","after_date"]:
		var id: String=game.relationships.identity(record);var key: String=id+"/event_mix"
		cursors[key]=int(cursors.get(key,0))+1
		if int(cursors[key])%3==0:text+=" "+game.voice.reply(record["character"],"chat","",game.relationships.bond(id))
	return text

func hostile(record: Dictionary) -> bool:
	var rel: RefCounted=game.relationships
	if record.is_empty() or not record.has("character"):return false
	if not rel.record_alive(record) or record.get("weak",false) or record.get("seated",false):return false
	if game.campaign.actor_weak(record["character"]):return false
	var bond: int=rel.bond(rel.identity(record))
	return bond<= -60 or rel.massacre() and bond<20

func available(record: Dictionary) -> bool:
	return hostile(record) and int(game.relationships.daily.get(game.relationships.identity(record)+"/hostile",-1))!=game.economy.day_serial

func reset(grace_seconds: float=5.0) -> void:
	pending_uid="";pending_scene=0;warning_left=0;scan_left=0;grace=grace_seconds

func blocked() -> bool:
	return not game.game_started or game.transition_busy or game.paused or game.front_end.visible or game.menu_view.visible or game.map_view.visible or game.dialogue_view.visible or game.battle_view.visible or game.phone.visible or game.phone.initiating or game.lesson_blocked() or game.story_blocked() or game.relationships.busy or game.interior_state.is_empty() or game.campaign.index<2

func tick(delta: float) -> bool:
	if "--manual-story-checks" in OS.get_cmdline_user_args() and not "--hostile-checks" in OS.get_cmdline_user_args():return false
	if blocked():
		pending_uid="";warning_left=0;grace=maxf(grace,2.0);return false
	grace=maxf(0,grace-delta)
	if grace>0:return false
	scan_left-=delta
	if scan_left>0:return false
	scan_left=.5 # Only the current room; at most two scans per second.
	var manager: Node2D=game.terrain.current_scene.npcs
	if manager==null:return false
	var scene_id: int=manager.get_instance_id()
	if pending_scene!=scene_id:pending_uid="";warning_left=0
	if not pending_uid.is_empty():
		var target: Dictionary=manager.find(pending_uid)
		if target.is_empty() or not available(target) or target["at"].distance_to(game.player.position)>48 or not manager.scene.navigation.segment_clear(target["at"],game.player.position):
			reset(8);return false
		warning_left-=.5
		if warning_left<=0 and target["at"].distance_to(game.player.position)<=32:
			reset(45)
			if game.relationships.start_battle(target,false,true):
				game.relationships.daily[game.relationships.identity(target)+"/hostile"]=game.economy.day_serial
				return true
		return false
	var nearest: Dictionary={};var distance:=48.0
	for record: Dictionary in manager.records:
		if not available(record):continue
		var length: float=record["at"].distance_to(game.player.position)
		if length<distance and manager.scene.navigation.segment_clear(record["at"],game.player.position):nearest=record;distance=length
	if nearest.is_empty():return false
	pending_uid=nearest["uid"];pending_scene=scene_id;warning_left=2.5
	game.show_notice(str(nearest["name"])+"："+say(nearest,"warning"));game.notice_time=3
	return false

func chase(record: Dictionary) -> bool:
	return not blocked() and grace<=0 and available(record) and record["at"].distance_to(game.player.position)<80

func combat_spec(record: Dictionary) -> Dictionary:
	var spec: Dictionary=profile(record["character"]).get("combat",{})
	return spec.duplicate(true)

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()>10000:return false
	for id: Variant in value:
		if not id is String or id.length()>180 or not value[id] is Dictionary:return false
		var row: Dictionary=value[id];var day: Variant=row.get("day")
		if not row.get("event") in ["confessed","date","friends","breakup","apology","spared"]:return false
		if not (day is int or day is float) or not is_finite(float(day)) or day!=floor(float(day)) or day<0:return false
	return true

func restore(value: Dictionary) -> void:
	moments=value.duplicate(true);cursors.clear();reset(5)
	for id: String in moments:moments[id]["day"]=int(moments[id]["day"])
