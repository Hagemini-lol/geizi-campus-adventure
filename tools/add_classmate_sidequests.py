"""Nine classmate stories and two bounded daily jobs, using the saved task log."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def lines(*pairs): return [{'actor':a,'text':t} for a,t in pairs]
def scene(location,hint,dialogue,**extra): return dict(location=location,hint=hint,dialogue=dialogue,**extra)
def talk(actor,hint,dialogue,**extra): return dict(actor=actor,hint=hint,dialogue=dialogue,**extra)
def puzzle(question,correct,wrong,resolution,retry):
    return dict(question=question,choices=[['right',correct],['wrong',wrong],['cancel','暂时离开']],correct='right',resolution=resolution,retry=retry)
quests=[]
def quest(id,owner,title,description,minimum,intro,steps,outro,reward,epilogue,daily=False):
    for n,step in enumerate(steps): step.setdefault('event',f'side/{id}/{n}')
    quests.append(dict(id='side_'+id,type='side',title=title,auto_start=False,prerequisites=[],steps=steps,side_story=dict(owner=owner,description=description,min_index=minimum,intro=intro,outro=outro,reward=reward,epilogue=epilogue,daily=daily)))
quest('li_radio','lao_li','不是万能的维修员','旧广播机在异常发生后坏了。牢李想修好它，却不肯把自己的困难写进报修单。',3,
 lines(('lao_li','这机器不是拧两颗螺丝就能好。我拆了一晚上，还是没声。'),('hero','你也有修不好的东西？'),('lao_li','有。可大家都说找牢李就行，我就不太好意思说没有配件。'),('hero','这次别一个人包了。缺什么，咱们一起找。')),
 [scene('B04','去小仓库检查报废广播的零件',lines(('hero','报废箱里没有完好的整机，只有一只还能用的旋钮和接线图。'),('hero','我把可用件单独装好，没把仓库当成免费的货架；借用登记也得补上。'))),
  talk('lao_chou','找牢抽核对电路图',lines(('lao_chou','先断电。你看这条回路线，故障可能在接触点，不是牢李技术不行。'),('hero','你能把这句写大点吗？他应该比机器更需要这张检修单。'),('lao_chou','那就写：两人复核，尚待验证。咱们也别装万能。'))),
  talk('lao_li','把零件和检修单交给牢李',lines(('lao_li','这回有图、有登记，也有人肯替我查错。'),('hero','广播修好了，维修员也该下班了。')))],
 lines(('lao_li','线路接通了。我会把还没修好的几台列出来，明天请人一起做。'),('hero','他把维修费分了我一份。这次他没有说“顺手的”。'),('lao_li','给你两份墨渣和回路糖，都是结余登记过的，放心拿。')),
 dict(g=60,items={'ink_fragment':2,'concentration_candy':1}),
 lines(('lao_li','广播今天又卡了一下。我先断电，再找了人一起检查。'),('hero','没通宵？'),('lao_li','没。机器能等到明天，我也能。')))
quest('chou_proof','lao_chou','答案之外的署名','牢抽发现一本旧习题册的解法被人误署名。他想找出原作者，也要学着承认自己的猜测。',3,
 lines(('lao_chou','这道题我会做，可页边的解法比我的简洁。'),('hero','学霸发现隐藏大佬了？'),('lao_chou','我猜是老师写的。可“猜”不是证据，想请你帮我找原册。')),
 [scene('B06:1:0','在科技中心图书室核对旧习题册',lines(('hero','两本书的解法一样，其中一本页角写着值日日期，另一页只有复印印痕。'),('hero','直接按字漂亮不漂亮认人，好像不太可靠。')),
 **puzzle('如何判断原件？','比较日期、压痕和借阅记录','选字最漂亮的一页',lines(('hero','先拍下页角，再记下借阅号。要问人，也得带着能核验的东西。')),lines(('hero','字体能模仿，漂亮更不能证明是谁写的。还是回头查记录。')))),
  talk('la_jiao','请辣椒核对当年的借阅与值日记录',lines(('la_jiao','那天是普通同学帮忙整理书架，老师还没到。原作者的名字在借阅卡背面。'),('hero','我把名字抄下来，也把同意公开署名的确认记好了。'))),
  talk('lao_chou','把原作者的确认交给牢抽',lines(('lao_chou','原来我第一步就猜错了。'),('hero','你最后肯改答案，比第一步就猜中更厉害。')))],
 lines(('lao_chou','我会把署名改正，写清楚自己用了谁的思路。'),('hero','他把“标准答案”划掉，改成了“目前能证明的答案”。'),('lao_chou','这笔整理资料的酬劳，咱们一人一半。')),
 dict(g=50,items={'concentration_candy':2}),
 lines(('lao_chou','那位同学又送来一种解法。我没急着比较谁更聪明，先请他讲完了。'),('hero','学霸也有听课的一天。'),('lao_chou','挺好，比一个人对着答案发愁强。')))
quest('fei_precision','fei_yan','不会爆炸的示范课','费眼为巡查新人备课。他不想拿天赋与主角比较，想把能安全学会的东西教出来。',7,
 lines(('fei_yan','下次示范我准备整点大的——算了，新人看完只会更怕。'),('hero','你终于觉得一边打怪一边说笑容易误导人了？'),('fei_yan','我也紧张。帮我把课做成谁都跟得上的，别只适合你这天才。')),
 [scene('B02:1:corridor','在实验楼走廊整理安全示范流程',lines(('hero','板上写着：先退路，再目标，最后施法。旁边还有费眼涂掉的大爆炸草图。')),
 **puzzle('第一堂课先展示什么？','低功率、清晰退路和停止口令','全力爆破让新人服气',lines(('hero','我把停止口令写在第一行。会停手，才有下一堂课。')),lines(('hero','威力越大，围观的人越危险。费眼要教的是能活着学会的办法。')))),
  dict(hint='接取后击败两只墨泥怪，验证新人也能处理的目标；实验楼或正常刷怪区',event='monster_defeated/ink_slime',count=2),
  talk('fei_yan','向费眼交回两次低风险巡查记录',lines(('fei_yan','不用漂亮战绩，就写你什么时候想撤、什么时候重新站稳。'),('hero','我写了“第一次看错距离”。你敢拿去教人吗？'),('fei_yan','这段最该教。')))],
 lines(('fei_yan','天赋是你的，讲清楚风险是我的本事。以前总觉得教不过你，倒把这个忘了。'),('hero','他没有再把自己扮成丑角，只把板书认真擦了一遍。'),('fei_yan','巡查经费批下来了。这份劳务费和急救包，你拿着。')),
 dict(g=55,items={'first_aid':2,'concentration_candy':1}),
 lines(('fei_yan','新人的第一句问题是“什么时候该停”。这课没白备。'),('hero','那第二句呢？'),('fei_yan','问我板上的小人是不是你。这个我没承认。')))
quest('ao_beat','lao_ao','停在长按之前','牢傲的练习耳机坏了。节奏和休息都不是逞强，虚弱期间他也能坐着把这件事做好。',3,
 lines(('lao_ao','耳机左边总慢半拍。我昨天还以为是自己状态不好。'),('hero','你平时脾气这么好，判定一歪也会生气？'),('lao_ao','会。但机器错了就修机器，不能冲旁边的人发火。帮我测一下延迟吧。')),
 [scene('S02','到主席台安静处录下广播的三次节拍',lines(('hero','我按同样的间隔敲了三下，只记录差值，没有越敲越快。'),('hero','牢傲的留言写着：节拍准，比按得猛更重要。'))),
  talk('lao_li','找牢李检查耳机接点',lines(('lao_li','只是插头松了。校准时别开最大音量，耳朵也不是耗材。'),('hero','我把延迟记录交给他，顺手把音量调低了一格。'))),
  talk('lao_ao','把修好的耳机和校准记录交给牢傲',lines(('lao_ao','这次对上了。能陪我听完这一小段吗？坐着就行。'),('hero','行，不拼分数，也不比谁能撑到最后。')))],
 lines(('lao_ao','有些长按可以松手。休息不是把别人丢下。'),('hero','他把耳机分给我一只，播放完就合上了屏幕。'),('lao_ao','校准是有酬劳的。补给也给你，别空着肚子巡查。')),
 dict(g=35,items={'water':3,'bread':2}),
 lines(('lao_ao','最近听一小段就收起来。能安稳坐一会儿，也算今天的满连。'),('hero','那这一段我负责不抢拍。')))
quest('shuo_load','lao_shuo','背包里要有别人的位置','牢硕要整理巡查装备。他得学会让大家分担，而不是把所有重量背到自己身上。',3,
 lines(('lao_shuo','这些绳子、水和药包我一个人背就行。'),('hero','你是去巡查，还是去搬家？'),('lao_shuo','装备不能缺。'),('hero','人也不能累垮。咱们先算算怎么分。')),
 [scene('B04','在小仓库核对绳带和药包重量',lines(('hero','我把需要随身的和留在据点的分开，坏扣带也单独挑了出来。'),('hero','最重的不是护具，是他替每个人多备的一份水。'))),
  scene('S02','带一瓶饮用水到主席台，完成补给分配；消耗饮用水×1',lines(('hero','我把水交到补给箱，不去证明自己能一趟搬完。')),
  consume={'water':1},**puzzle('如何安排补给？','按体力分担，留一人检查退路','让最壮的人全部扛走',lines(('hero','重的分开，急救包放在都摸得到的位置。没人需要靠逞强证明有用。')),lines(('hero','最壮的人也要战斗。把他累倒，大家反而都没了退路。')))),
  talk('lao_shuo','向牢硕交回分配清单',lines(('lao_shuo','我原来以为多扛一点就是负责。'),('hero','有人愿意帮你扛，你也得给他留个位置。')))],
 lines(('lao_shuo','明天轮着背，出发前互相检查。训练是为了把人带回来。'),('hero','他第一次把最重的包放到了地上。'),('lao_shuo','仓库整理的报酬和补给，按登记领。')),
 dict(g=60,items={'water':3,'bread':1,'field_ration':1}),
 lines(('lao_shuo','今天我背药包，别人背水。队伍走得比以前整齐。'),('hero','也没人落在后面了。')))
quest('yang_pace','yang_zi','跑在同一个速度里','阳子想用跑步找回节奏，主角却不擅长长跑。两人需要一条能一起走完的路线。',3,
 lines(('yang_zi','陪我绕主席台跑一圈？慢一点就行。'),('hero','你这个“慢”，可能是我的遗言速度。'),('yang_zi','那这回你定速度。我也想试试，不用每次都跑到最前面。')),
 [scene('S02','在主席台旁选择适合两人的短距离路线',lines(('hero','地上还有昨晚的积水。近路更短，却看不见拐角。')),
 **puzzle('选择怎样的路线？','可见退路，跑走交替，累了就停','穿过湿滑近路拼最快',lines(('hero','我给转角留了步行段。阳子回了句：行，今天不计时。')),lines(('hero','湿滑近路省下的几秒，可能要拿伤来换。')))),
  talk('lao_shuo','请牢硕确认路线和停止口令',lines(('lao_shuo','短跑用精力爆发，长时间追击就要留恢复。停止口令说出口，所有人都得听。'),('hero','我把“喘不上气就停”写进计划，没再用笑话糊弄。'))),
  talk('yang_zi','把共同路线交给阳子',lines(('yang_zi','原来你真的怕跟不上。'),('hero','是。我力气大，可不是什么都能撑。'),('yang_zi','那就不催。以后你也别一个人把难处藏起来。')))],
 lines(('hero','我们没跑完一整圈。到第二个路口就停下喝水，反而第一次把话说完。'),('yang_zi','体育组的路线整理费有你一份。下回还按这个速度。')),
 dict(g=40,items={'water':3,'field_ration':1}),
 lines(('yang_zi','今天也不计时。你走慢点，我正好把昨天那个点子说完。'),('hero','这回你别一口气说三百字，我连听都喘。')))
quest('dong_box','lao_dong','锁着的家常','牢董想整理旧宅的一只木箱，里面的东西比家族法术更难开口。',21,
 lines(('lao_dong','旧宅有只箱子，锁没坏，是我一直没开。'),('hero','里面封着危险的法术？'),('lao_dong','应该是饭票和旧信。可我总想着，家里会不会只记得我做得不够好。')),
 [scene('STORY_HOUSE:1:0','在已开放的牢家旧宅找到普通木箱',lines(('hero','箱盖没有法阵，只有反复摸亮的木纹。信里叮嘱带伞，连最普通的家常话都留着。')),
 **puzzle('如何处理私人旧信？','封好带回，让牢董自己决定读哪封','先拆开所有信替他找答案',lines(('hero','我没有把他的家事当作待解的谜题，按原样封好了。')),lines(('hero','帮忙不等于替他决定。私人信件还是留给本人。')))),
  talk('lao_dong','把木箱交回牢董',lines(('lao_dong','原来没有考核，也没有训诫。只是叫我天冷多穿一点。'),('hero','你可以先做个想家的人，再做那个什么都能处理的人。')))],
 lines(('lao_dong','今晚我会回一封信。不谈守印，只说最近吃了什么。'),('hero','他把箱子放到身边，没有再锁上。'),('lao_dong','这是整理旧宅的报酬。家里备的补给，也分你一份。')),
 dict(g=70,items={'first_aid':2,'field_ration':2}),
 lines(('lao_dong','信寄出去了。写得很短，家里却回了三页。'),('hero','都说什么？'),('lao_dong','说米够不够吃。挺好。')))
quest('jiao_duty','la_jiao','空出来的一格','辣椒的值日表没有给自己留休息。她需要学会把班级的事分给班级的人。',3,
 lines(('la_jiao','别在门口堵着。我还要补三张表。'),('hero','你自己的休息那一栏怎么全是空的？'),('la_jiao','写了也没用，总有人忘带钥匙、忘交记录。'),('hero','那先把这些“总有人”写进轮值里。')),
 [scene('B01:3:0','在秋实楼十班核对告示栏的三张值日表',lines(('hero','班里大多数空格不是没人愿意做，是从来没问到本人。'),('hero','我没有代签名字，只把待确认的格子圈了出来。'))),
  talk('lao_shuo','请牢硕确认钥匙与安全检查轮值',lines(('lao_shuo','我负责核对钥匙。其余岗位也该问问本人，别全压给班长。'),('hero','签名和同意都齐了，这才算排班。'))),
  talk('la_jiao','把本人确认过的轮值表交给辣椒',lines(('la_jiao','你没替别人填名字？'),('hero','没，也没替你把休息划掉。')))],
 lines(('la_jiao','那今天最后十分钟，我也坐下来。谁临时缺席，先找当班的人。'),('hero','她把笔递给接班同学，手松开时还有点不习惯。'),('la_jiao','文具整理和登记的劳务费在这，别说我又自己包办了。')),
 dict(g=45,items={'bread':2,'concentration_candy':1}),
 lines(('la_jiao','今天有人来找我，我先让他看轮值表了。事情照样办完。'),('hero','你终于不用随身带着整个班了。')))
quest('wr_bookmark','wr','书页没有替你回答','wr借出的一本小说回来了，夹着一张把结局抄错的书签。她想知道读者为何需要那个假结局。',12,
 lines(('wr','这个读者把悲剧抄成了团圆。你觉得他没读懂？'),('hero','也可能是看懂了，所以不甘心。'),('wr','我原本想直接纠正他。现在有点好奇，能请你查查这张书签的来处吗？不许偷看借阅者私信。')),
 [scene('B06:1:0','在图书室比对小说两种版本的结尾',lines(('hero','旧版书页缺了一角，新版补回了离别的段落。书签背面却写着“我想让她回来”。')),
 **puzzle('怎样写读书会的提问？','先问读者为什么改写，再分清原文与愿望','宣布只有原文正确，愿望毫无意义',lines(('hero','我把原文和改写分开装好。事实不能乱写，心愿也不该被当笑话。')),lines(('hero','读书会不是审判。分清原文之后，也可以听听为什么想改。')))),
  talk('lao_chou','请牢抽核验版本差异，不猜测读者隐私',lines(('lao_chou','能确定的是版本缺页，不能确定的是他经历过什么。别把推理写到别人的伤口上。'),('hero','我只带走可公开的版本记录。'))),
  talk('wr','把版本记录和读书会提问交给wr',lines(('wr','不靠法术去看别人的秘密，反而要认真等他自己开口。'),('hero','你也可以只等，不一定每次都要猜中。')))],
 lines(('wr','读书会我会先说明哪段是原文，再让人说自己的结局。愿望不是证据，可也不是罪。'),('hero','她把那张书签夹回书里，露出没有写答案的一面。'),('wr','整理书目的酬劳和读书会补给。别以为魔女请人帮忙就可以不给钱。')),
 dict(g=60,items={'concentration_candy':2,'bread':1}),
 lines(('wr','他今天愿意说为什么改了。我们没替他施法，只听到散场。'),('hero','也算一种挺难的魔法。'),('wr','这个不用蓝。')))
quest('daily_supply','la_jiao','日常 · 据点补给登记','核对仓库，再送一瓶水到主席台，回来签收。每日一次，不和生活费重复计算。',3,
 lines(('la_jiao','据点补给要实物签收，不能在表上随手画个勾。'),('hero','行，这次我带一瓶水过去，回来交签收记录。')),
 [scene('B04','到小仓库核对今日补给清单',lines(('hero','我查了日期和数量，没有把昨天的登记重新交一遍。'))),
  scene('S02','带饮用水×1到主席台补给箱；交付后消耗',lines(('hero','水放进箱里，记录也写上了今天的日期。')),consume={'water':1}),
  talk('la_jiao','找辣椒交回补给签收单',lines(('la_jiao','数量对上了。劳务费和你的路上补给分开记，明天需要再来。')))],
 lines(('hero','这次的报酬结清了。表上的一个勾，终于对应了一件真做完的事。')),
 dict(g=30,items={'water':1,'bread':1}),lines(('la_jiao','今天这份已经结清。明天有新清单再接，别拿同一张重复报账。')),True)
quest('daily_cleanup','lao_shuo','日常 · 巡查残留回收','清点实验楼安全区，交回两份墨渣。每天一单，回收物不可同时出售。',3,
 lines(('lao_shuo','回收物要密封登记。两份墨渣换一笔清理补贴，今天只收一单。'),('hero','先去实验楼看一眼，再把材料带回来，明白。')),
 [scene('B02:1:corridor','到实验楼走廊确认回收区安全',lines(('hero','我确认了退路和封装箱；材料不够，可以在正常巡查中收集，不能凭空填数。'))),
  talk('lao_shuo','带墨渣×2找牢硕交付；实际扣除两份材料',lines(('lao_shuo','封口齐全，两份材料入库。战斗和回收的风险都算在补贴里。')),consume={'ink_fragment':2})],
 lines(('hero','材料入了库，不能再拿去卖一次。清理补贴比直接出售多一点，但得完成安全检查。')),
 dict(g=45,items={'water':1}),lines(('lao_shuo','今天结过这一单了。先留些材料，明天按新任务再来。')),True)
tasks=json.loads((root/'任务配置.json').read_text(encoding='utf-8'))
tasks['version']=2
tasks['tasks']=[t for t in tasks['tasks'] if not t.get('side_story')]+quests
(root/'任务配置.json').write_text(json.dumps(tasks,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
econ=json.loads((root/'物资与交易配置.json').read_text(encoding='utf-8'))
add=[dict(id='field_ration',name='巡查便当',description='恢复精力上限45%的精力；战斗使用占一回合',buy_price=25,sell_price=12,restore={},restore_ratio={'energy':.45}),
     dict(id='concentration_candy',name='回路糖',description='恢复60点及MP上限8%的MP；战斗使用占一回合',buy_price=20,sell_price=10,restore={'mp':60},restore_ratio={'mp':.08})]
econ['items']=[i for i in econ['items'] if i['id'] not in [a['id'] for a in add]]+add
(root/'物资与交易配置.json').write_text(json.dumps(econ,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'classmates':9,'stories':len(quests),'steps':sum(len(q['steps']) for q in quests),'one_time_g':sum(q['side_story']['reward']['g'] for q in quests if not q['side_story']['daily']),'daily_g_cap':75},ensure_ascii=False))
