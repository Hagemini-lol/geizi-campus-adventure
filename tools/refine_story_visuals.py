from pathlib import Path
root=Path(__file__).resolve().parents[1]/'source'
def change(file, pairs):
 p=root/file;s=p.read_text('utf-8-sig')
 for a,b in pairs:
  assert a in s,a[:100]
  s=s.replace(a,b,1)
 p.write_text(s,'utf-8')
change('story_system.gd',[
 ('z_index=8','z_index=12'),
 ('window_point=Vector2(float(box[0])+14.4,float(box[1]))*24','window_point=Vector2(float(box[0])+14.4,float(box[1]))*24+Vector2(0,32)'),
 ('rear_point=game.safe_outdoor(window_point-Vector2(0,30))','rear_point=game.safe_outdoor(window_point-Vector2(0,62))'),
 ('\tif stage==1 and game.interior_state.is_empty():\n\t\tif game.player.position.distance_to(rear_point)>1100:return\n\t\tdraw_arc(rear_point,6,0,TAU,40,Color.WHITE,1.3,true)\n\t\tdraw_rect(Rect2(window_point-Vector2(14,22),Vector2(28,18)),Color(.5,.76,1,.4+.35*sin(phase*12)),true)',
  '\tif stage>=1 and game.interior_state.is_empty():\n\t\tif game.player.position.distance_to(rear_point)>1100:return\n\t\t# Only this rear window is dynamic; the facade remains baked.\n\t\tdraw_rect(Rect2(window_point-Vector2(25,28),Vector2(50,57)),Color("8b5148"))\n\t\tdraw_rect(Rect2(window_point-Vector2(19,20),Vector2(38,38)),Color("dddcd2"))\n\t\tdraw_rect(Rect2(window_point-Vector2(16,17),Vector2(32,32)),Color("52798a"))\n\t\tif stage in [1,2]:draw_rect(Rect2(window_point-Vector2(16,17),Vector2(32,32)),Color(.6,.83,1,.35+.3*sin(phase*12)))\n\t\tdraw_line(window_point+Vector2(0,-19),window_point+Vector2(0,17),Color("dddcd2"),1.3,true)\n\t\tdraw_line(window_point+Vector2(-17,-5),window_point+Vector2(17,-5),Color("dddcd2"),1.3,true)\n\t\tif stage==1:draw_arc(rear_point,6,0,TAU,40,Color.WHITE,1.3,true)'),
 ('window_point-Vector2(0,18),65,.35','window_point,65,.35'),
 ('\t\timage=Image.load_from_file(game.battle_asset_root.path_join(game.combat_rules.data["monsters"][id]["art"]))\n\t\timage=image.get_region(image.get_used_rect())','\t\timage=preload("res://monster_scene.gd").portrait(game.battle_asset_root.path_join(game.combat_rules.data["monsters"][id]["art"])).get_image()')])
change('npc_dialogue.gd',[
 ('\tright_portrait.texture=null\n\tconfirm.text=', '\tright_portrait.texture=null\n\tfor row: Dictionary in script_lines:\n\t\tvar actor: String=row.get("actor","")\n\t\tif actor in ["system","zhao_mugei"] or not game.npc_catalog.characters.has(actor):continue\n\t\tvar other: Image=game.npc_catalog.frame(actor,0);other.generate_mipmaps()\n\t\tright_portrait.texture=ImageTexture.create_from_image(other);break\n\tconfirm.text=')])
change('battle_view.gd',[('charge_toggle.position=Vector2(420,20)','charge_toggle.position=Vector2(420,72)')])
change('tests/story_check.gd',[
 ('if child is Sprite2D and child.get_script()==load("res://magic_effect.gd"):await shot','if child is Sprite2D and child.get_script()==load("res://magic_effect.gd") and game.story_system.stage==4:await shot'),
 ('\tawait shot("03_震动教室门")\n',''),
 ('\tcheck(game.interaction_text(door).contains("震动"),','\tawait shot("03_震动教室门")\n\tcheck(game.interaction_text(door).contains("震动"),')])
print('Visual refinements applied')
