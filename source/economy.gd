extends RefCounted

signal changed
const STACK_CAP:=9999
var data: Dictionary={}
var catalog: Dictionary={}
var recipes: Dictionary={}
var inventory: Dictionary={}
var money:=0
var day_serial:=0
var last_allowance_day:=-1

func configure(path: String, content: Dictionary={}) -> bool:
	var parsed: Variant=content.duplicate(true) if not content.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("items") is Array:return false
	data=parsed;catalog={}
	if int(data.get("daily_allowance",50))<0:return false
	for value: Variant in data["items"]:
		if not value is Dictionary or not value.get("id") is String or value["id"].is_empty() or catalog.has(value["id"]):return false
		if not value.get("restore",{}) is Dictionary:return false
		if int(value.get("sell_price",0))<0 or int(value.get("buy_price",-1))< -1:return false
		if int(value.get("buy_price",-1))>=0 and int(value.get("sell_price",0))>int(value["buy_price"]):return false
		for stat: String in value.get("restore",{}):
			if not stat in ["hp","mp","energy","san"] or int(value["restore"][stat])<=0:return false
		for stat: String in value.get("restore_ratio",{}):
			if not stat in ["hp","mp","energy","san"] or float(value["restore_ratio"][stat])<=0 or float(value["restore_ratio"][stat])>1:return false
		catalog[value["id"]]=value.duplicate(true)
	recipes={}
	for recipe: Dictionary in data.get("recipes",[]):
		if not recipe.get("id") is String or recipes.has(recipe["id"]) or not recipe.get("ingredients") is Dictionary or not recipe.get("outputs") is Dictionary:return false
		if recipe["ingredients"].is_empty() or recipe["outputs"].is_empty() or int(recipe.get("fee",0))<0:return false
		for group: String in ["ingredients","outputs"]:
			for id: String in recipe[group]:
				if not catalog.has(id) or int(recipe[group][id])<1 or int(recipe[group][id])>STACK_CAP:return false
		recipes[recipe["id"]]=recipe
	reset();return true

func craft(id: String) -> Dictionary:
	if not recipes.has(id):return {"ok":false,"message":"配方不存在"}
	var recipe: Dictionary=recipes[id]
	if money<int(recipe.get("fee",0)):return {"ok":false,"message":"加工费不足"}
	var next: Dictionary=inventory.duplicate()
	for material: String in recipe["ingredients"]:
		if quantity(material)<int(recipe["ingredients"][material]):return {"ok":false,"message":"材料不足："+str(catalog[material]["name"])}
		next[material]=quantity(material)-int(recipe["ingredients"][material])
	for material: String in recipe["outputs"]:
		next[material]=int(next.get(material,0))+int(recipe["outputs"][material])
		if int(next[material])>STACK_CAP:return {"ok":false,"message":"成品持有已满，请先整理背包"}
	# Commit ingredients, outputs and fee together, with one observer notification.
	inventory=next;money-=int(recipe.get("fee",0));changed.emit()
	return {"ok":true,"message":"完成："+str(recipe["name"])}

func reset() -> void:
	money=0;day_serial=0;last_allowance_day=-1;inventory={}
	for id: String in data.get("initial_items",{}):
		if catalog.has(id):inventory[id]=clampi(int(data["initial_items"][id]),0,STACK_CAP)
	claim_allowance();changed.emit()

func claim_allowance() -> int:
	if last_allowance_day>=day_serial:return 0
	var amount:=int(data.get("daily_allowance",50))
	money+=amount;last_allowance_day=day_serial;changed.emit();return amount

func next_day() -> int:
	day_serial+=1;return claim_allowance()

func quantity(id: String) -> int:return int(inventory.get(id,0))

func add_item(id: String, amount: int=1) -> bool:
	if not catalog.has(id) or amount<=0 or quantity(id)+amount>STACK_CAP:return false
	inventory[id]=quantity(id)+amount;changed.emit();return true

func trade(id: String, count: int, buying: bool) -> Dictionary:
	if not catalog.has(id) or count<1 or count>STACK_CAP:return {"ok":false,"message":"交易物资或数量无效"}
	var spec: Dictionary=catalog[id]
	var price:=int(spec.get("buy_price",-1) if buying else spec.get("sell_price",0))
	if buying:
		if price<0:return {"ok":false,"message":"这件物资只可出售"}
		if money<price*count:return {"ok":false,"message":"资金不足"}
		if quantity(id)+count>STACK_CAP:return {"ok":false,"message":"该物资已达到持有上限"}
		money-=price*count;inventory[id]=quantity(id)+count
	else:
		if price<=0:return {"ok":false,"message":"这件物资不能出售"}
		if quantity(id)<count:return {"ok":false,"message":"持有数量不足"}
		inventory[id]=quantity(id)-count;money+=price*count
	changed.emit()
	return {"ok":true,"message":("购入" if buying else "出售")+str(spec["name"])+" ×%d，%s %dg" % [count,"支付" if buying else "获得",price*count]}

func can_use(id: String, hero: Dictionary) -> bool:
	if not catalog.has(id) or quantity(id)<=0:return false
	for stat: String in catalog[id].get("restore",{}):
		if int(hero[stat+"_current"])<int(hero[stat]):return true
	for stat: String in catalog[id].get("restore_ratio",{}):
		if int(hero[stat+"_current"])<int(hero[stat]):return true
	return false

func use(id: String, hero: Dictionary) -> Dictionary:
	if not can_use(id,hero):return {"ok":false,"message":"该物资无法使用，或相关状态已满"}
	for stat: String in catalog[id]["restore"]:
		hero[stat+"_current"]=mini(int(hero[stat]),int(hero[stat+"_current"])+int(catalog[id]["restore"][stat]))
	for stat: String in catalog[id].get("restore_ratio",{}):
		hero[stat+"_current"]=mini(int(hero[stat]),int(hero[stat+"_current"])+floori(int(hero[stat])*float(catalog[id]["restore_ratio"][stat])))
	inventory[id]=quantity(id)-1;changed.emit()
	return {"ok":true,"message":"使用了"+str(catalog[id]["name"])}

func award_loot(rarity: String) -> Dictionary:
	var awarded: Dictionary={}
	for id: String in data.get("monster_loot",{}).get(rarity,{}):
		if not catalog.has(id):continue
		var amount:=clampi(int(data["monster_loot"][rarity][id]),0,STACK_CAP-quantity(id))
		if amount<=0:continue
		inventory[id]=quantity(id)+amount;awarded[id]=amount
	if not awarded.is_empty():changed.emit()
	return awarded

func snapshot() -> Dictionary:
	return {"version":1,"money":money,"day_serial":day_serial,"last_allowance_day":last_allowance_day,"inventory":inventory.duplicate(true)}

func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("inventory") is Dictionary:return false
	for field: String in ["money","day_serial","last_allowance_day"]:
		var n: Variant=value.get(field)
		if not (n is int or n is float) or not is_finite(float(n)) or float(n)!=floor(float(n)) or float(n)<0 or float(n)>1e12:return false
	if int(value["last_allowance_day"])!=int(value["day_serial"]) or value["inventory"].size()>1000:return false
	for id: Variant in value["inventory"]:
		if not id is String or id.is_empty():return false
		var n: Variant=value["inventory"][id]
		if not (n is int or n is float) or not is_finite(float(n)) or float(n)!=floor(float(n)) or float(n)<0 or float(n)>STACK_CAP:return false
	return true

func restore(value: Dictionary) -> void:
	if value.is_empty():reset();return
	money=int(value["money"]);day_serial=int(value["day_serial"]);last_allowance_day=int(value["last_allowance_day"])
	inventory={}
	for id: String in value["inventory"]:inventory[id]=int(value["inventory"][id])
	changed.emit()
