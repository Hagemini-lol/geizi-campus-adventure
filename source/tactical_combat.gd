extends RefCounted

# Pure turn rules shared by the actual UI and the deterministic balance tests.
# No timers, random rolls, or hidden difficulty scaling.
var spec: Dictionary={}
var state: Dictionary={}
var intent: Dictionary={}
var staggered:=false
var countered:=false
var slowed:=false

func setup(monster_spec: Dictionary, saved: Dictionary={}) -> void:
	spec=monster_spec.get("tactics",{})
	state={"phase":1,"meter":0,"turn":1,"phase_seen":false}
	for key: String in state:
		if saved.has(key):state[key]=saved[key]
	state["phase"]=clampi(int(state["phase"]),1,2)
	state["meter"]=clampi(int(state["meter"]),0,2)
	state["turn"]=clampi(int(state["turn"]),1,1000000)
	staggered=false;countered=false;slowed=false

func begin_turn(enemy: Dictionary, number: int) -> Dictionary:
	state["turn"]=number;countered=false;slowed=false;staggered=false
	var patterns: Array=spec.get("phase_patterns",[]) if int(state["phase"])==2 else spec.get("patterns",[])
	if patterns.is_empty():
		intent={"name":"普通攻击","kind":"physical","power":1.0,"counters":[],"hint":"每回合自然回复精力；冰系能迟滞这次攻击。"}
	else:intent=patterns[(number-1)%patterns.size()].duplicate(true)
	# In Gouga's battle the active conduit is visible and is the only changed
	# affinity. No random immunity and no punishment for the last-used element.
	if spec.has("phase_at"):
		enemy["elemental_reductions"]={str(intent["counters"][0]):-.25}
	return intent

func hit(action: Dictionary) -> Dictionary:
	var element: String=action.get("element","")
	var matched: bool=not element.is_empty() and element in intent.get("counters",[])
	if action.get("id","")=="resonance_break":matched=not intent.get("counters",[]).is_empty()
	countered=matched
	slowed=element=="frost"
	if matched:
		state["meter"]=int(state["meter"])+1+(1 if action.get("id","")=="resonance_break" else 0)
		if int(state["meter"])>=int(spec.get("break_limit",2)):
			staggered=true;state["meter"]=0
	return {"counter":matched,"break":staggered,"slow":slowed}

func change_phase(enemy: Dictionary) -> bool:
	if spec.has("phase_at") and int(state["phase"])==1 and int(enemy["hp_current"])>0 and int(enemy["hp_current"])<=floori(int(enemy["hp"])*float(spec["phase_at"])):
		state["phase"]=2;state["phase_seen"]=true;state["meter"]=0
		# The change costs the enemy its action, making the phase transition
		# survivable. It never heals the boss or adds a surprise extra attack.
		staggered=true
		return true
	return false

func reduction() -> float:
	return .65 if countered else .2 if slowed else 0.0

func description() -> String:
	if spec.is_empty():return "下一步："+str(intent.get("name","普通攻击"))
	return "阶段 %d · 架势 %d/%d\n预告：%s\n%s" % [int(state["phase"]),int(state["meter"]),int(spec.get("break_limit",2)),str(intent.get("name","")),str(intent.get("hint",""))]

func snapshot() -> Dictionary:return state.duplicate(true)
