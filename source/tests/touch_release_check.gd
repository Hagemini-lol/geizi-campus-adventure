extends "res://tests/mobile_ui_fix_check.gd"

var choice_result:=""
func touch(at: Vector2, down: bool, index: int=0, cancelled: bool=false) -> void:
	var event:=InputEventScreenTouch.new();event.position=at;event.index=index;event.pressed=down;event.canceled=cancelled
	root.push_input(event,true)
func drag(at: Vector2, index: int=0) -> void:
	var event:=InputEventScreenDrag.new();event.position=at;event.index=index;event.relative=Vector2(0,-50)
	root.push_input(event,true)
func button(text: String, owner: Node) -> Button:
	for value: Button in owner.find_children("*","Button",true,false):
		if value.is_visible_in_tree() and value.text==text:return value
	return null
func choice() -> void:
	choice_result=await game.campaign.choose("抬手确认测试",[["yes","确认这项"],["no","取消这项"]])
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames(8)
	if "--wide-mobile" in OS.get_cmdline_user_args():DisplayServer.window_set_size(Vector2i(1600,900));await frames(8)
	var front: Control=game.front_end
	var at: Vector2=front.title_buttons["settings"].get_global_rect().get_center()
	touch(at,true);await frames(4);check(not front.settings_open,"title option waits for lift")
	touch(at,false);await frames();check(front.settings_open,"title option confirms on lift")
	var plus: Button=front.settings_controls["control_scale"]["plus"]
	at=plus.get_global_rect().get_center();var before: float=front.draft["control_scale"]
	touch(at,true);await frames();check(front.draft["control_scale"]==before,"stepper hold cannot modify settings")
	drag(at+Vector2(0,30));await frames();drag(at);touch(at,false);await frames()
	check(front.draft["control_scale"]==before,"non-scroll drag away and back cannot confirm stepper")
	touch(at,true);drag(at+Vector2(3,4));touch(at+Vector2(3,4),false);await frames()
	check(is_equal_approx(float(front.draft["control_scale"]),before+.05),"small finger jitter remains one tap")
	before=front.draft["control_scale"]
	touch(at,true);touch(at+Vector2(50,0),false);await frames()
	check(front.draft["control_scale"]==before,"far lift cancels even without a drag event")
	touch(at,true);touch(at,false,0,true);await frames();check(front.draft["control_scale"]==before,"OS cancelled touch does not confirm")
	touch(at,true);game.mobile_controls._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT);touch(at,false);await frames()
	check(front.draft["control_scale"]==before and game.mobile_controls.pointer_index==-1,"focus loss cancels pending tap without stuck pointer")
	# Another finger may not confirm or replace the owning GUI finger.
	touch(at,true);touch(at,true,1);touch(at,false,1);await frames()
	check(front.draft["control_scale"]==before,"second finger cannot confirm held option")
	touch(at,false);await frames();check(is_equal_approx(float(front.draft["control_scale"]),before+.05),"owner finger confirms exactly once after second finger lifts")
	front.close_modal();await frames();game.start_new_game()
	while game.transition_busy:await process_frame
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31;await frames()
	var controls: Control=game.mobile_controls
	at=controls.y_rect.get_center();touch(at,true);await frames()
	check(not game.menu_view.visible,"world menu Y also waits for lift")
	drag(at+Vector2(30,0));drag(at);touch(at,false);await frames()
	check(not game.menu_view.visible,"world menu Y drag-return is cancelled")
	await tap(at);check(game.menu_view.visible,"world menu Y lift opens menu")
	game.close_menu();await frames()
	# Joystick and sprint remain continuous rather than release actions.
	at=controls.stick_rect.get_center();touch(at,true);drag(at+Vector2(70,0));await frames()
	check(controls.stick_index==0 and controls.direction.x>.5,"stick responds while finger remains down")
	touch(controls.run_rect.get_center(),true,1);await frames();check(controls.running,"sprint responds while held by second finger")
	touch(controls.run_rect.get_center(),false,1);check(not controls.running and controls.stick_index==0,"sprint lift leaves joystick held")
	touch(at,false);await frames();check(controls.direction.is_zero_approx(),"stick lift stops continuous movement")
	game.story_system.begin_sequence()
	game.dialogue_view.begin_script([{"actor":"yang_zi","text":"第一句"},{"actor":"fei_yan","text":"第二句"},{"actor":"lao_li","text":"第三句"},{"actor":"system","text":"第四句"}]);await frames()
	at=Vector2(100,80);touch(at,true);await frames();check(game.dialogue_view.script_index==0,"blank dialogue waits for lift")
	drag(at+Vector2(80,0));drag(at);touch(at,false);await frames()
	check(game.dialogue_view.script_index==0,"blank non-scroll swipe-return never advances dialogue")
	touch(at,true);touch(at+Vector2(2,3),false);await frames();check(game.dialogue_view.script_index==1,"blank lift advances exactly one line")
	at=game.dialogue_view.confirm.get_global_rect().get_center();touch(at,true);await frames()
	check(game.dialogue_view.script_index==1,"special dialogue confirm waits for lift")
	touch(at,false);await frames();check(game.dialogue_view.script_index==2,"special dialogue confirm advances once on lift")
	at=Vector2(100,80);touch(at,true);game.dialogue_view.accept();touch(at,false);await frames()
	check(game.dialogue_view.script_index==3,"story changing during a held finger cancels stale tap")
	choice();await frames();at=button("确认这项",game.campaign.panel).get_global_rect().get_center()
	touch(at,true);await frames();check(choice_result.is_empty(),"story choice does not settle on press")
	drag(at+Vector2(60,0));drag(at);touch(at,false);await frames();check(choice_result.is_empty(),"story choice drag-return leaves modal open")
	await tap(at);check(choice_result=="yes","story choice settles on lift")
	game.dialogue_view.finish_script(true);game.story_system.end_sequence();await frames()
	# A scroll gesture beginning directly on an actionable item must never select it.
	var panel:=PanelContainer.new();panel.position=Vector2(300,100);panel.size=Vector2(450,260);game.phone.get_parent().add_child(panel)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(450,260);panel.add_child(scroll)
	var list:=VBoxContainer.new();scroll.add_child(list)
	var selections: Array[int]=[0]
	for i: int in range(15):
		var item:=Button.new();item.text="物资 "+str(i);item.custom_minimum_size=Vector2(400,64);item.pressed.connect(func():selections[0]+=1);list.add_child(item)
	await frames();at=list.get_child(1).get_global_rect().get_center()
	touch(at,true);await frames();check(selections[0]==0,"scroll item waits for lift")
	drag(at-Vector2(0,90));await frames();check(scroll.scroll_vertical>=80,"swipe scrolls while finger remains down")
	touch(at-Vector2(0,90),false);await frames();check(selections[0]==0,"scrolling over an item never selects it")
	scroll.scroll_vertical=0;await frames();at=list.get_child(1).get_global_rect().get_center()
	touch(at,true);drag(at-Vector2(0,60));drag(at);touch(at,false);await frames()
	check(selections[0]==0,"scroll away-return remains cancelled")
	await tap(at);check(selections[0]==1,"stationary scroll item lift confirms exactly once")
	# Crossing a button boundary inside slop still cannot activate a neighbour.
	var target: Button=list.get_child(1);at=target.get_global_rect().position+Vector2(1,30)
	touch(at,true);touch(at-Vector2(3,0),false);await frames();check(selections[0]==1,"lifting just outside original button cancels")
	panel.queue_free();await frames()
	# Actual modifier keypad buttons use the same release contract.
	game.world_editor.unlocked=true;game.phone.open();game.phone.editor("money");await frames()
	at=game.phone.inputs.values()[0]["button"].get_global_rect().get_center()
	touch(at,true);await frames();check(game.phone.page=="editor/money","modifier input waits for lift")
	touch(at,false);await frames();check(game.phone.page=="keypad","modifier input opens keypad on lift")
	at=button("5",game.phone).get_global_rect().get_center();var text: String=game.phone.keypad_text.text
	touch(at,true);await frames();check(game.phone.keypad_text.text==text,"keypad digit does not enter before lift")
	drag(at+Vector2(40,0));drag(at);touch(at,false);await frames();check(game.phone.keypad_text.text==text,"keypad drag-return does not type")
	await tap(at);check(game.phone.keypad_text.text!=text,"keypad digit enters once on lift")
	game.phone.close();await frames()
	var report:=FileAccess.open(output.path_join(report_name+".json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"method":"Actual ScreenTouch/ScreenDrag on title/settings, story choices and blank dialogue, scroll buttons, modifier keypad, world Y, two-finger stick/sprint, cancellation and focus loss. Desktop engine; no Android device/emulator."},"  "))
	print("TOUCH_RELEASE_CHECKS ",checks," FAILURES ",failures.size());game.queue_free();game=null;await frames();quit(0 if failures.is_empty() else 1)
