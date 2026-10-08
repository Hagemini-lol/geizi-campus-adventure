"""Apply the physical stamina rules requested on 2026-10-08, idempotently."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def load(name): return json.loads((root/name).read_text(encoding='utf-8'))
def save(name,data): (root/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
c=load('战斗与刷新配置.json')
c['energy_rules']={'turn_ratio':.03,'minimum':10,'settlement':'Only a completed living battle turn; no recovery on opening, cancelling, retreating or failed actions. Items consume one battle turn.'}
for a in c['actions']:
    a.pop('energy_restore',None)
    if a['id']=='guard': a['description']='防御，本次减伤50%；精力只按回合自然恢复'
    if a['id']=='rest': a['description']='恢复至少20或上限5%的MP；精力只按回合自然恢复，敌方仍会行动'
s=c['skills']
for ident,ratio in [('mana_cycle',.08),('focus',.08),('steady_guard',.14),('wind_step',.18)]:
    s[ident].pop('energy_cost',None);s[ident]['energy_ratio']=ratio
s['focus']['description']='集中注意力，下一次法术伤害+25%，消耗8%精力，冷却3回合'
s['mana_cycle']['description']='集中注意力引导回路，消耗8%精力，回复至少一次低级施法的MP；本次减伤50%，冷却3回合'
s['steady_guard']['description']='收紧全身保持稳固防线，消耗14%精力，本次攻击减伤65%，冷却3回合'
s['wind_step'].update(name='蹬地撤步',description='短距离爆发换位，消耗18%精力，必定避开本次攻击与附加干扰，冷却3回合；不回复MP')
s['clarity']['description']='净化封蓝/易伤并免疫两次干扰，本次减伤35%；不额外回复精力'
s.update({
 'shoulder_check':{'name':'沉肩撞击','kind':'physical','teacher':'lao_shuo','level':1,'price':0,'chapter_reward':True,'energy_ratio':.18,'cooldown':3,'multiplier':1.45,'description':'收肩蹬地撞开架势，1.45倍物理伤害；本次物理反击减伤65%，无法截住法术；消耗18%精力，冷却3回合'},
 'short_combo':{'name':'短拳连打','kind':'physical','teacher':'lao_shuo','level':1,'price':0,'chapter_reward':True,'energy_ratio':.24,'cooldown':3,'multiplier':1.85,'description':'贴身两记短拳，合计1.85倍物理伤害，一并结算护壳；消耗24%精力，冷却3回合，出拳时无法格挡'},
 'brace_guard':{'name':'架臂格挡','kind':'support','teacher':'lao_shuo','level':1,'price':0,'chapter_reward':True,'energy_ratio':.12,'cooldown':2,'description':'架臂护住要害，本次物理减伤70%、法术减伤30%；消耗12%精力，冷却2回合'}
})
c.get('tactical_rules',{}).pop('break_damage_bonus',None)
save('战斗与刷新配置.json',c)
e=load('物资与交易配置.json')
for item in e['items']:
    if item['id']=='water':item.update(description='恢复30点及精力上限20%的精力；战斗使用占一回合',restore_ratio={'energy':.2})
    elif item['id']=='bread':item.update(description='恢复120生命、50点及精力上限30%的精力；战斗使用占一回合',restore_ratio={'energy':.3})
save('物资与交易配置.json',e)
p=load('剧情配置.json');campaign=p['campaign']
lessons={
 'team_meet':(['shoulder_check','brace_guard'],[
  {'actor':'lao_shuo','text':'你力气大，跑长距离却吃亏。别追着怪乱跑，沉肩撞进去，再架臂护住头。对面念咒时，胳膊可挡不住全部法术。'},
  {'actor':'hero','text':'我试了一遍，肩头发酸。短短一下就这么费劲，原来力气大也不能一直硬来。'},
  {'actor':'lao_shuo','text':'每个回合喘匀气，精力会慢慢回来。要补得快就喝水吃东西，可敌人不会等你吃完。'}]),
 'warehouse_trace':(['short_combo'],[
  {'actor':'lao_shuo','text':'刚才你抡得太大。贴近后只打两记短拳，脚要站稳；连打更费力，没力气就别强撑。'},
  {'actor':'hero','text':'我照着打完，没急着补第三拳。这次留出的半步，刚好够我接住下一次扑击。'}])}
for node in campaign['nodes']:
    if node['id'] in lessons:
        skills,lines=lessons[node['id']]
        node['learn_skills']=list(dict.fromkeys(node.get('learn_skills',[])+skills))
        existing={x['text'] for x in node.get('after_dialogue',[])}
        node['after_dialogue']+= [line for line in lines if line['text'] not in existing]
        node['cast']=list(dict.fromkeys(node.get('cast',[])+['lao_shuo']))
        campaign.setdefault('skill_milestones',{})[node['id']]=node['learn_skills']
for node in campaign['nodes']:
    for phase in ['dialogue','after_dialogue']:
        for line in node.get(phase,[]):
            line['text']=line['text'].replace('踏风步','蹬地撤步')
save('剧情配置.json',p)
print('STAMINA_CONFIG_READY')
