"""Author the separate relationship story pack; never rewrite existing art or chapters."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def line(actor, text): return {'actor': actor, 'text': text}
profiles = {
 'lao_li': ('把清单放下之后', '你总说还有一件事没准备好。我想知道，没有清单的时候，你会想去哪里？', '校门口那家小店。我一直想试，又觉得可以等下次。你要愿意，我们这次就去。', '原来我不用先证明自己有用，你也会想跟我待在一起。'),
 'lao_chou': ('答案之外', '今天先不查线索，陪我走一段？不知道聊什么也没关系。', '我怕一安静，你就觉得无聊。其实我也有很多没有答案的事，比如为什么你一叫我，我就想回头。', '我愿意。遇到不懂的地方，我们可以直接问彼此。'),
 'fei_yan': ('并肩而非跟随', '这次没有招式要请教。我只是想约你一起散步。', '我还以为你终于发现我也会紧张了。走吧，今天不当谁的老师，咱们平着走。', '别总把我摆在什么都懂的位置。你也可以接住我，我想试试。'),
 'lao_ao': ('等你站起来', '等你康复，我们一起走操场；今天坐在这里也很好。', '你不用为了照顾我把自己的生活停下。我想要的是一起商量步子，不是让你一直等。', '那就慢慢走。快一点慢一点，都先说给对方听。'),
 'lao_shuo': ('不用逞强的一天', '你今天也累了吧？在我面前可以不用一直撑着。', '让我说我累，比让我再跑两圈还难。不过跟你待着，我想试着说实话。', '我愿意和你交往。有人能分担，不会让我变弱。'),
 'yang_zi': ('玩笑停下来的时候', '这次我没有接你的玩笑，是因为我想认真说：我喜欢和你一起。', '那我也认真一回。我不是每次都那么有把握；怕冷场，也怕你只是顺着我笑。', '以后不开心也告诉我。两个人可以安静，不能一直猜。'),
 'lao_dong': ('不写在家规里的约定', '这次你可以只按自己的想法回答。我想和你更亲近一点。', '以前我遇到选择，总先想家里会怎么看。现在我想先问自己：明天最想见的人是谁。答案是你。', '我愿意。这份约定我自己来守，也会把我的顾虑说清楚。'),
 'la_jiao': ('点名之后', '你总确认每个人在不在。今天换我问：你想不想和我单独待一会儿？', '想。我老怕一松手就漏掉谁，可你这样问，我才发现自己也可以被照顾。', '那就给我们留一点不用点名的时间。喜欢不是另一份值日表。'),
 'wr': ('把书合上', '不靠契约，也不交换任何代价。我想知道你愿不愿意和我靠近。', '愿意。但我有时会需要独处，读不完的书也不会因为交往就放下。你不必装成跟我一模一样。', '可以。喜欢一个人，不该把她变成自己的答案。'),
 'ordinary': ('放学后的一段路', '我们聊过很多次了。下次放学，愿意一起走一段路吗？', '愿意。先说好，不用因为约好了就勉强开心。有心事也可以慢慢说。', '我也喜欢你。先认真认识彼此，一起商量怎么相处。'),
 'gou_ga': ('不把求救当作承诺', '这次不是为了套你的话。门外安静的时候，我也想见你。', '你别因为可怜我就说这种话。我做过的事还在，别人不原谅我也是应该的。要靠近，就看清楚再来。', '我想试着和你在一起。但你不能替别人原谅我，也不能把救我当成我必须喜欢你的理由。修复那些伤害，是我自己的责任。')
}
romance = {}
for actor, (title, question, response, acceptance) in profiles.items():
 romance[actor] = {'title': title, 'topic': [line('zhao_mugei', question), line('target', response)], 'accept': [line('target', acceptance)], 'revisit': [line('target', '今天不用做出什么成绩。我们坐一会儿，听彼此把话说完。')], 'friend': [line('target', '好，朋友也值得认真对待。以后想法变了，再好好说。')]}
stages = [
 ('裂缝里的回声', 'book_queen', 16, {}, 0, 0, '听完她说话，不替她开脱', 'promise', [line('gou_ga', '门底有声音，喊得跟真的一样。有人说我能让它安静，所以我试了。后来每一次都要更多。'),line('zhao_mugei','听见声音不是你的错。把无辜的人拖进去是。我们先查清它怎么骗你。')], '你没有说“我懂你”，也没立刻走。那……这一段我说完。'),
 ('撤回错误的名字', 'yang_hearing', 18, {'F_LI_CLEAR': True, 'F_YANG_CLEAR': True}, 0, 0, '让她亲自留下更正的证词', 'record', [line('gou_ga','你还想让我当众承认？他们以后看我，都会想起这件事。'),line('zhao_mugei','他们已经在替你的谎话承担后果了。更正记录不是换取原谅，是先停止让错事继续。')], '我写。不是你替我写，也不说自己只是开玩笑。'),
 ('没人替你选的出口', 'seal_defend', 18, {}, 1, 40, '拆掉门底用来控制她的旧符结', 'release', [line('gou_ga','你拿着碎片可以封住我。现在把它用在回路上，不怕我转头跑了？'),line('zhao_mugei','我要切断控制，不是把控制权换到我手里。碎片还在封印中起作用，你走出去之后也要面对做过的事。')], '符结松了。原来没有人拽着，也可以迈出一步。'),
 ('把真相留在灯下', 'tide_clear', 22, {'F_TRUTH': True}, 3, 60, '把真相交给所有幸存者，而非私下藏起', 'share', [line('gou_ga','你已经知道是谁把我推到门边了。可以只告诉我吗？我不想再被别人议论。'),line('zhao_mugei','证据要留下，才能有人负责。你的私人感受不会贴在公告栏上；发生过的伤害也不能删掉。')], '那就把证据分开。该公开的公开，我害怕的事……可以只说给你听吗？'),
 ('这一次自己松手', 'preparation', 26, {'F_TRUTH': True, 'F_CIVILIAN_SAFE': True}, 4, 60, '承诺救人，同时保留证据和责任', 'stand', [line('gou_ga','最后要是我控制不住，你还会叫我的名字吗？别答应得太快。'),line('zhao_mugei','我会叫，也会挡下伤人的招式。我不会为了留住你让别人去死。等你能自己松手，我们再谈门外的日子。'),line('gou_ga','好。别让我躲进“全都是门的错”这句话里。我想出来，也要自己走完。')], '这不是赦免，也不是契约。她把那张写有出口的纸，认真折好放进校服口袋。')
]
gou=[]
for i,(title,after,gain,flags,shards,san,label,correct,dialogue,resolution) in enumerate(stages):
 gou.append({'id':f'gou_{i+1}', 'title':title,'after':after,'gain':gain,'flags':flags,'shards':shards,'san':san,'understand':4 if i>=3 else 0,'dialogue':dialogue,'choices':[[correct,label],['excuse','说她没有责任，只要跟着自己就好'],['cancel','先不回答，改天再谈']], 'correct':correct,'resolution':[line('gou_ga' if i<4 else 'system',resolution)],'retry':[line('gou_ga','你要是只想让我听话，那跟门底有什么不同？等你想清楚再来。')]})
pack={'version':1,'topic_affinity':60,'confess_affinity':85,'gou_topic_affinity':80,'gou_redemption_affinity':90,'romance':romance,'gou_stories':gou}
(root/'关系与攻略配置.json').write_text(json.dumps(pack,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

quests=json.loads((root/'任务配置.json').read_text(encoding='utf-8'))
for q in quests['tasks']:
 s=q.get('side_story')
 if not s: continue
 s['requires_affinity']=0 if s.get('chapter_bridge') or s.get('daily') or s.get('life_story') or not q.get('prerequisites') else 8
 # Third personal stories ask for a bond built through both earlier stories.
 if q['id'].endswith(('_equal','_return','_witness','_boundary','_future','_together','_answer','_listen','_name')) and s['requires_affinity']:s['requires_affinity']=16
(root/'任务配置.json').write_text(json.dumps(quests,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
