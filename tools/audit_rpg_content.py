"""Count authored playable text, not generated screenshots, docs or repeated UI."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
read=lambda name:json.loads((root/name).read_text(encoding='utf-8'))
story=read('剧情配置.json');tasks=read('任务配置.json')
def dialogue(value):
    found=[]
    if isinstance(value,dict):
        if isinstance(value.get('text'),str):found.append(value['text'])
        for key,sub in value.items():
            if key!='text':found+=dialogue(sub)
    elif isinstance(value,list):
        for sub in value:found+=dialogue(sub)
    return found
def count(texts):
    unique=list(dict.fromkeys(texts))
    return {'lines':len(texts),'unique_lines':len(unique),'characters':sum(len(re.sub(r'\s','',s)) for s in unique),'chinese_characters':sum(len(re.findall(r'[\u3400-\u9fff]',s)) for s in unique)}
campaign=story['campaign'];chapters=[]
for id,title in campaign['chapter_titles'].items():
    nodes=[n for n in campaign['nodes'] if n['chapter']==id]
    chapters.append({'id':id,'title':title,'events':len(nodes),**count(dialogue(nodes))})
side=[t for t in tasks['tasks'] if t.get('side_story')]
bridges=[t for t in side if t['side_story'].get('chapter_bridge')]
personal=[t for t in side if not t['side_story'].get('daily') and not t['side_story'].get('chapter_bridge') and not t['side_story'].get('life_story')]
report={'version':(root/'VERSION').read_text(encoding='utf-8-sig').strip(),'main':count(dialogue(story)), 'main_chapters':chapters,'main_events':len(campaign['nodes']),'side':count(dialogue(side)),'chapter_investigations':len(bridges),'chapter_investigation_steps':sum(len(t['steps']) for t in bridges),'personal_stories':len(personal),'personal_story_steps':sum(len(t['steps']) for t in personal),'daily_jobs':sum(t['side_story'].get('daily',False) for t in side),'side_steps':sum(len(t['steps']) for t in side)}
staff=[t for t in side if t['side_story'].get('life_story') and not t['side_story'].get('daily') and not t['side_story'].get('memo_story')]
memoirs=[t for t in side if t['side_story'].get('memo_story')]
report['class_ten_memoirs']=len(memoirs)
report['class_ten_memoir_steps']=sum(len(t['steps']) for t in memoirs)
report['class_ten_memoir_dialogue']=count(dialogue(memoirs))
report['character_voice_profiles']=len(story.get('character_voice',{}))
report['character_voice_dialogue']=count(dialogue(story.get('character_voice',{})))
report['campus_staff_stories']=len(staff)
report['campus_staff_steps']=sum(len(t['steps']) for t in staff)
report['campus_staff_dialogue']=count(dialogue(staff))
relationships=read('关系与攻略配置.json')
report['relationship_stories']=len(relationships['gou_stories'])
report['romance_profiles']=len(relationships['romance'])
report['relationship_dialogue']=count(dialogue(relationships))
gift_text=[profile[field] for profile in relationships.get('gifts',{}).get('profiles',{}).values() for field in ['liked','neutral','refusal'] if field in profile]
report['gift_dialogue']=count(gift_text)
all_text=dialogue(story)+dialogue(side)+dialogue(relationships)+gift_text
report['total']=count(all_text)
report['interactive_puzzles']=sum('puzzle' in s for q in side for s in q['steps'])
report['reading_minutes_at_300_cpm']=round(report['total']['characters']/300,1)
report['reading_minutes_at_220_cpm']=round(report['total']['characters']/220,1)
report['method']='Unique authored dialogue strings only. Includes mutually exclusive endings and replayable daily dialogue, so total reading time is NOT a single-route playtime. Excludes menus, hints, descriptions, docs, duplicate sentences and travelling/waiting. Actual 4-hour playtime has not been measured.'
def route_task(t):
    texts=dialogue(t['side_story']['intro'])+dialogue(t['side_story']['outro'])
    for step in t['steps']:
        texts+=dialogue(step.get('dialogue',[]))+dialogue(step.get('resolution',[]))
        if step.get('puzzle'):texts+=dialogue(step['puzzle']['clues'])+dialogue(step['puzzle'].get('success',[]))
        if step.get('branches'):texts+=dialogue(next(iter(step['branches'].values())))
    return texts
route_main=dialogue(story['dialogues'])
for node in campaign['nodes']:
    for field in ['dialogue','long_dialogue','after_dialogue']:route_main+=dialogue(node.get(field,[]))
route_main+=dialogue(campaign['ending_dialogues']['GE-H'])
required=route_main+sum((route_task(q) for q in bridges),[])
normal_personal=[q for q in personal if q['side_story']['min_index']<30]
normal=required+sum((route_task(q) for q in normal_personal),[])
completion=required+sum((route_task(q) for q in personal),[])
report['single_route']={'ending':'GE-H','required_main_and_investigations':count(required),'normal_with_personal_episodes':len(normal_personal),'normal_dialogue':count(normal),'completion_with_personal_episodes':len(personal),'completion_dialogue':count(completion),'main_battle_waves':sum(len(n.get('battle',[])) for n in campaign['nodes']),'normal_extra_required_kills':sum(int(s.get('count',1)) for q in normal_personal for s in q['steps'] if s.get('event','').startswith('monster_defeated/')),'excludes':'Other endings, alternate branches, retry dialogue, daily jobs, banter, optional epilogue revisits, grinding, AFK and waiting for real time.'}
report['playtime_estimates']=[]
for label,texts,cpm,travel,combat,decisions,management in [
    ('main_only_standard',required,250,25,25,26,15),
    ('normal_standard',normal,250,40,30,37,20),
    ('normal_leisurely',normal,220,55,40,50,25),
    ('normal_fast_reading_and_travel',normal,300,20,20,17,10),
    ('all_personal_stories_standard',completion,250,50,30,42,20)]:
    reading=count(texts)['characters']/cpm
    report['playtime_estimates'].append(dict(profile=label,dialogue_characters=count(texts)['characters'],reading_cpm=cpm,reading_minutes=round(reading,1),travel_minutes=travel,combat_minutes=combat,decision_minutes=decisions,management_minutes=management,total_minutes=round(reading+travel+combat+decisions+management,1),measured=False))
memo_route=normal+sum((route_task(q) for q in memoirs),[])
report['normal_with_class_ten_memoirs']={'dialogue':count(memo_route),'extra_travel_decision_minutes_assumed':15,'estimated_minutes_at_250_cpm':round(count(memo_route)['characters']/250+40+30+37+20+15,1),'measured':False}
report['playtime_method']='Planning estimates, not observed human playthroughs. Normal profile completes main + 9 chapter investigations + the first two personal episodes for all 9 classmates (18/27 episodes). Non-reading budgets are explicit assumptions for movement, 25 compulsory encounters, choices and inventory/skill preparation. Reading assumes characters including punctuation per minute; fast/skip play can be under 4 hours. In-game active clock now enables real timing, excluding background/pause and inactivity beyond 60 seconds.'
report['before_expansion']={'dialogue_characters':14085,'main_events':33,'personal_stories':9,'daily_jobs':2,'side_steps':31}
(root/'runtime/content_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
