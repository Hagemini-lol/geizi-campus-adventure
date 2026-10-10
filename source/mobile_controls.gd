extends Control

# One pointer owns the stick; another independently owns normal mouse/GUI input.
var game: Node2D
var direction:=Vector2.ZERO
var stick_index:=-1
var pointer_index:=-1
var button_touches: Dictionary={}
var base_art: Texture2D
var knob_art: Texture2D
var button_art: Texture2D
var stick_rect:=Rect2()
var x_rect:=Rect2()
var y_rect:=Rect2()
var run_rect:=Rect2()
var movement_available:=false
var menu_available:=false
var mouse_stick:=false
var running:=false
var active:=false
var pointer_scroll: ScrollContainer
var pointer_origin:=Vector2.ZERO
var scroll_origin:=0
var pointer_dragged:=false

func _ready() -> void:
	active=OS.has_feature("android") or "--mobile-controls" in OS.get_cmdline_user_args()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not active:hide();set_process(false);set_process_input(false);return
	Input.emulate_mouse_from_touch=false
	var root: String=game.resolve_path("资源/原项目/assets/ui/components/controls")
	base_art=art(root.path_join("joystick_base.png"))
	knob_art=art(root.path_join("joystick_knob.png"))
	button_art=art(root.path_join("action_disc.png"))
	resized.connect(layout)
	layout()

func art(path: String) -> Texture2D:
	var image:=Image.load_from_file(path)
	if image==null:return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func layout() -> void:
	var settings: Dictionary=game.preferences.values
	var scale: float=float(settings["control_scale"])
	var padding: float=float(settings["control_margin"])
	var bottom:=padding
	# Safe-area insets are converted from physical pixels to viewport coordinates.
	if OS.has_feature("android"):
		var screen:=DisplayServer.screen_get_size()
		var safe:=DisplayServer.get_display_safe_area()
		if screen.x>0 and screen.y>0 and safe.size.x>0:
			padding=maxf(padding,float(maxi(safe.position.x,screen.x-safe.end.x))*size.x/float(screen.x)+12.0)
			bottom=maxf(bottom,float(screen.y-safe.end.y)*size.y/float(screen.y)+12.0)
	scale=minf(scale,minf((size.x-2*padding-24)/480.0,(size.y-bottom-110)/250.0))
	scale=maxf(.5,scale)
	var stick:=220.0*scale
	var x:=112.0*scale
	var y:=104.0*scale
	var run:=96.0*scale
	var gap:=18.0*scale
	stick_rect=Rect2(padding,size.y-bottom-stick,stick,stick)
	x_rect=Rect2(size.x-padding-x,size.y-bottom-x-48*scale,x,x)
	y_rect=Rect2(size.x-padding-x-gap-y,size.y-bottom-run-gap-y,y,y)
	run_rect=Rect2(size.x-padding-x-gap-run,size.y-bottom-run,run,run)
	queue_redraw()

func refresh_availability() -> void:
	# Check on each input too: a modal can open between two process frames.
	var phone_blocked: bool=game.phone!=null and (game.phone.visible or game.phone.initiating)
	menu_available=game.game_started and not game.menu_view.visible and not game.map_view.visible and not game.paused and not phone_blocked and not game.front_end.visible and not game.dialogue_view.visible and not game.battle_view.visible and not game.transition_busy and not game.lesson_blocked() and not game.story_blocked()
	movement_available=menu_available and not game.menu_view.visible and not game.map_view.visible and not game.paused
	if not movement_available and (stick_index!=-1 or mouse_stick or running):reset_stick()
	visible=active and menu_available

func _process(_delta: float) -> void:
	refresh_availability()
	queue_redraw()

func reset_stick() -> void:
	stick_index=-1;mouse_stick=false;direction=Vector2.ZERO;running=false
	button_touches.clear()

func button_at(at: Vector2) -> String:
	refresh_availability()
	if menu_available and y_rect.has_point(at):return "menu"
	if movement_available and x_rect.has_point(at):return "interact"
	if movement_available and run_rect.has_point(at):return "run"
	return ""

func activate(action: String) -> void:
	if action=="menu":game.toggle_menu()
	elif action=="interact" and movement_available:game.interact()
	elif action=="run":running=true

func update_stick(at: Vector2) -> void:
	direction=((at-stick_rect.get_center())/(stick_rect.size.x*.35)).limit_length(1.0)
	if direction.length()<.15:direction=Vector2.ZERO
	if not direction.is_zero_approx():
		game.player.path.clear();game.pending_npc_talk="";game.pending_monster=""
	queue_redraw()

func handled() -> void:get_viewport().set_input_as_handled()

func scroll_at(at: Vector2) -> ScrollContainer:
	for node: Node in game.find_children("*","ScrollContainer",true,false):
		var scroll:=node as ScrollContainer
		if scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(at) and scroll.get_v_scroll_bar().max_value>scroll.size.y:
			return scroll
	return null

func route_mouse(event: InputEvent) -> void:
	var mapped: InputEvent
	if event is InputEventScreenTouch:
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT;click.pressed=event.pressed
		click.position=event.position;click.global_position=event.position
		click.button_mask=MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
		mapped=click
	else:
		var motion:=InputEventMouseMotion.new()
		motion.position=event.position;motion.global_position=event.position
		motion.relative=event.relative;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		mapped=motion
	mapped.device=42 # Distinguish this mapping from a physical mouse.
	# ScreenTouch positions already use viewport coordinates. Do not apply
	# the phone's stretch transform a second time through Input.parse_input_event.
	get_viewport().push_input(mapped,true)

func _input(event: InputEvent) -> void:
	if not active:return
	refresh_availability()
	# Modal GUI still receives the touch-to-mouse mapping below.
	if event is InputEventScreenTouch:
		var at: Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
		if event.pressed:
			if movement_available and stick_index==-1 and stick_rect.has_point(at):
				stick_index=event.index;update_stick(at);handled();return
			var action:=button_at(at)
			if not action.is_empty():
				button_touches[event.index]=action;activate(action);handled();return
			if pointer_index==-1:
				pointer_index=event.index;pointer_origin=event.position;pointer_dragged=false
				pointer_scroll=scroll_at(at);scroll_origin=pointer_scroll.scroll_vertical if pointer_scroll!=null else 0
				route_mouse(event)
		else:
			if event.index==stick_index:reset_stick();handled();return
			if button_touches.has(event.index):
				if button_touches[event.index]=="run":running=false
				button_touches.erase(event.index);handled();return
			if event.index==pointer_index:
				if not pointer_dragged:route_mouse(event)
				else:handled()
				pointer_index=-1;pointer_scroll=null;pointer_dragged=false
	elif event is InputEventScreenDrag:
		if event.index==stick_index:
			update_stick(get_global_transform_with_canvas().affine_inverse()*event.position);handled()
		elif button_touches.has(event.index):handled()
		elif event.index==pointer_index:
			if is_instance_valid(pointer_scroll) and event.position.distance_to(pointer_origin)>10:
				if not pointer_dragged:
					# Cancel the pressed item before scrolling, avoiding an accidental purchase.
					var release:=InputEventScreenTouch.new();release.position=Vector2(-1000,-1000);release.pressed=false
					route_mouse(release);pointer_dragged=true
				pointer_scroll.scroll_vertical=scroll_origin-int(event.position.y-pointer_origin.y)
				handled()
			elif not pointer_dragged:route_mouse(event)
	elif event is InputEventMouseButton and event.device!=42 and event.button_index==MOUSE_BUTTON_LEFT:
		var at: Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
		if not event.pressed:
			if mouse_stick:reset_stick();handled()
			elif running:running=false;handled()
		elif movement_available and stick_rect.has_point(at):mouse_stick=true;update_stick(at);handled()
		else:
			var action:=button_at(at)
			if not action.is_empty():activate(action);handled()
	elif event is InputEventMouseMotion and mouse_stick:
		update_stick(get_global_transform_with_canvas().affine_inverse()*event.position);handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_stick()
		if pointer_index!=-1:
			var release:=InputEventScreenTouch.new();release.pressed=false
			route_mouse(release);pointer_index=-1

func disc(rect: Rect2, text: String, hint: String) -> void:
	if button_art!=null:draw_texture_rect(button_art,rect,false,Color(1,1,1,float(game.preferences.values["control_opacity"])))
	else:draw_circle(rect.get_center(),rect.size.x*.5,Color(.1,.15,.17,.8))
	draw_string(game.ui_font,rect.position+Vector2(0,rect.size.y*.56),text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,int(rect.size.x*.25),Color.WHITE)
	draw_string(game.ui_font,rect.position+Vector2(0,rect.size.y*.78),hint,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,int(rect.size.x*.16),Color.WHITE)

func _draw() -> void:
	if not menu_available:return
	disc(y_rect,"Y","菜单")
	if not movement_available:return
	if base_art!=null:draw_texture_rect(base_art,stick_rect,false,Color(1,1,1,float(game.preferences.values["control_opacity"])*.85))
	if knob_art!=null:draw_texture_rect(knob_art,Rect2(stick_rect.get_center()+direction*stick_rect.size.x*.27-Vector2.ONE*stick_rect.size.x*.205,Vector2.ONE*stick_rect.size.x*.41),false)
	disc(x_rect,"X","交互")
	disc(run_rect,"×2","奔跑")
