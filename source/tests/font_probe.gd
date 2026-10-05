extends SceneTree
func _initialize() -> void:
	var font:=SystemFont.new()
	for property: Dictionary in font.get_property_list():
		if "oversampl" in str(property["name"]) or "multichannel" in str(property["name"]):print("FONT_PROPERTY ",property["name"])
	print("STRETCH_METHOD ",root.has_method("get_stretch_transform"))
	quit()
