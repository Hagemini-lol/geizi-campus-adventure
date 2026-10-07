extends Node2D
var game: Node2D
var scene: Node2D
var records: Array[Dictionary]=[]
var texture_bytes:=0

func setup(owner_game: Node2D, owner_scene: Node2D, ids: Array) -> void:
	game=owner_game;scene=owner_scene;y_sort_enabled=true
	for i: int in range(ids.size()):
		var id: String=ids[i]
		var image: Image=game.npc_catalog.frame(id,0);image.generate_mipmaps()
		var sprite:=Sprite2D.new();sprite.z_index=10;sprite.texture=ImageTexture.create_from_image(image);sprite.scale=Vector2.ONE*game.npc_catalog.height(id)/image.get_height();sprite.offset.y=-image.get_height()*.5
		var at:=Vector2(35+35*i,173)
		if id=="wr":at=Vector2(55,178)
		if not scene.navigation.walkable(at):at=scene.landing()
		sprite.position=at;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(sprite);texture_bytes+=image.get_data_size()
		records.append({"uid":"campaign/"+id,"character":id,"name":game.npc_catalog.characters[id]["display_name"],"at":at,"height":game.npc_catalog.height(id),"width":image.get_width()*sprite.scale.x})
func find(uid: String) -> Dictionary:
	for record: Dictionary in records:
		if record["uid"]==uid:return record
	return {}
func interactions() -> Array[Dictionary]:
	var items: Array[Dictionary]=[]
	for record: Dictionary in records:
		items.append({"action":"npc","uid":record["uid"],"name":record["name"],"at":record["at"],"art_rect":Rect2(record["at"]-Vector2(record["width"]*.5,record["height"]),Vector2(record["width"],record["height"]))})
	return items
func approach(uid: String, from: Vector2) -> PackedVector2Array:
	var record:=find(uid)
	return scene.navigation.route(from,record["at"]) if not record.is_empty() else PackedVector2Array()
