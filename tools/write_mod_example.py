from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
def save(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def L(a,t):return [dict(actor=a,text=t)]
manifest=dict(api=1,id='campus_example',name='示例：广播台的一张便笺',version='1.0.0',enabled=False,order=100,requires=[],content='content.json')
content=dict(items=[dict(id='campus_example:tea',name='温茶',description='示例 Mod 消耗品：回复精力上限 18% 与 10 MP；战斗使用占一回合。',buy_price=12,sell_price=4,restore={'mp':10},restore_ratio={'energy':.18})],monsters=[dict(id='campus_example:ink_drop',base='ink_slime',name='漏墨团',hp_scale=1.2,attack_scale=.8)],event_dialogue={'patrol_done':L('lao_li','广播台的便笺也收到了，轮值表可以再补一项。〔示例 Mod〕')},quests=[dict(id='campus_example:note',type='side',title='Mod · 广播台的一张便笺',auto_start=False,prerequisites=[],side_story=dict(owner='lao_li',min_index=3,description='示例扩展任务：到主席台收便笺，再交回牢李。',intro=L('lao_li','主席台有人留了张便笺，说广播偶尔会漏一个字。帮我收回来，我会按实际故障查，不先责怪报问题的人。'),outro=L('lao_li','时间和位置都写清楚了。这是帮忙的酬劳，还有广播台备的温茶。'),epilogue=L('lao_li','便笺已归档，后来的轮值人也能看见。〔示例 Mod 完成〕'),reward={'g':20,'items':{'campus_example:tea':2}}),steps=[dict(location='S02',hint='到主席台收取广播故障便笺',event='side/campus_example:note/0',dialogue=L('hero','便笺写着下午第二次提示音缺了一拍。我记下位置和时间，没有把一次异常写成整台机器都坏了。'),question='便笺最有用的信息是什么？',choices=[['right','时间、位置和实际听到的现象'],['wrong','报问题的人是不是懂技术'],['cancel','稍后再读']],correct='right',resolution=L('hero','留下可复测的信息，后来的人才能接着查。'),retry=L('hero','懂不懂技术不改变听到的现象，还是看能核验的内容。')),dict(actor='lao_li',hint='将便笺交给牢李',event='side/campus_example:note/1',dialogue=L('lao_li','我接着查。你没有把猜测写成结论，给维修省了不少路。'))])])
save(R/'mods/campus_example/manifest.json',manifest);save(R/'mods/campus_example/content.json',content)
manifest=dict(manifest,enabled=True)
save(R/'source/mod_example.json',dict(manifest=manifest,content=content))
print('Example data pack written (folder disabled; in-game install opt-in).')
