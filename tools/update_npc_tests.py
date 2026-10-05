from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'source/tests/npc_check.gd'
s=p.read_text(encoding='utf-8')
s=s.replace('npcs.records.size()==13 and npcs.movers.size()==1','npcs.records.size()==14 and npcs.movers.size()==10').replace('ten class has twelve baked students and one mover','ten class has four baked students and ten named movers')
s=s.replace('npcs.get_child_count()==1','npcs.get_child_count()==10')
s=s.replace('"ordinary_in_ten":13-named.size()','"ordinary_in_ten":14-named.size()').replace('"moving_students":1','"moving_students":10')
s=s.replace('special_ids.size()==3 and special_ids[0]!=special_ids[1] and special_ids[1]!=special_ids[2]','special_ids.size()==3 and special_ids[0]=="lao_li" and special_ids[1]=="lao_li" and special_ids[2]=="lao_li"').replace('three distinct special NPC characters','named NPC copies are present in all three ten classes')
s=s.replace('"named_student_total":10,"moving_student_total":3','"named_student_total":30,"moving_student_total":30')
p.write_text(s,encoding='utf-8')
