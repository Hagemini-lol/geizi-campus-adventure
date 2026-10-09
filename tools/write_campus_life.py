"""Author only v1.5 campus-life entries; retain all earlier campaign content."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def read(name): return json.loads((root/name).read_text(encoding='utf-8'))
def write(name,value): (root/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
economy=read('物资与交易配置.json')
materials=[
 ('rice_pack','米饭原料包',8,2,'cook_hu','食材','由食堂保管的小份米料；交给工作人员加工。'),
 ('vegetable_pack','净菜包',7,2,'cook_hu','食材','已清洗的蔬菜，加工前按份计数。'),
 ('egg','鸡蛋',6,1,'cook_hu','食材','熟食窗口可代加工，不建议直接食用。'),
 ('milk','盒装牛奶',16,4,'clerk_qiu','食品','补充少量体能的常温奶。'),
 ('fruit','当季水果',12,3,'clerk_qiu','食品','轻便补给，恢复少量生命与精力。'),
 ('salt_packet','盐糖调配包',5,1,'cook_hu','食材','用于食堂调配补给饮料。'),
 ('clean_paper','空白纸',5,1,'print_luo','文具','打印和整理记录使用；不能替代任务中的原始证据。'),
 ('binder_clip','长尾夹',4,1,'print_luo','文具','装订资料，避免不同版本混页。'),
 ('tape','纸胶带',6,1,'print_luo','文具','标记归还物品、装订和制作安全提示卡。'),
 ('cloth','干净布料',9,2,'warden_zhou','日用品','制作护膝垫、整理袋；不能作为医用无菌材料。'),
 ('soap','肥皂',10,2,'warden_chen','日用品','日常清洁与生活委托物资。'),
 ('sewing_thread','针线包',8,2,'warden_chen','日用品','交给宿管修补整理袋，不改动装备属性。'),
 ('scrap_metal','分类废金属',-1,3,'','回收物','安全收集后的金属边料；交工作人员回收。'),
 ('old_cardboard','废纸板',-1,2,'','回收物','去除尖锐订钉后分类回收，可制作登记夹。'),
 ('recycling_ticket','回收登记票',-1,7,'','凭证','校内分类回收的兑换凭证。'),
 ('rice_meal','热饭套餐',32,6,'cook_hu','餐食','正常饭量，按最大精力比例恢复，适合章节间补给。'),
 ('egg_sandwich','鸡蛋夹饼',26,5,'clerk_qiu','餐食','便携餐食，少量恢复生命并补充精力。'),
 ('sports_drink','运动补给饮',28,5,'clerk_qiu','饮料','补充运动消耗；不会恢复魔力或替代休息。'),
 ('fruit_yogurt','水果酸奶',30,6,'clerk_qiu','餐食','轻食补给，兼顾生命与精力。'),
 ('cloth_bag','布质整理袋',-1,8,'','制成品','委托整理道具；不凭空增加背包容量。'),
 ('route_card','绕行提示卡',-1,5,'','制成品','用清楚的箭头帮助同学避开施工区域。'),
 ('bound_notes','装订笔记',-1,7,'','制成品','校对页码后的副本，不能伪造主线证据。'),
 ('knee_pad','运动缓冲垫',-1,8,'','制成品','轻便布垫，休整时缓解疲劳，不是永久装备。'),
 ('cleaning_kit','清洁整理包',-1,7,'','制成品','公共区清洁用品；不进入他人的寝室使用。'),
]
ratios={'milk':{'energy':.08},'fruit':{'hp':.04,'energy':.06},'rice_meal':{'energy':.26,'hp':.06},'egg_sandwich':{'energy':.18,'hp':.06},'sports_drink':{'energy':.20},'fruit_yogurt':{'energy':.15,'hp':.10},'knee_pad':{'energy':.12}}
ids={x[0] for x in materials};economy['items']=[x for x in economy['items'] if x['id'] not in ids]
for ident,name,buy,sell,vendor,category,description in materials:
 row={'id':ident,'name':name,'buy_price':buy,'sell_price':sell,'description':description,'category':category,'restore':{}}
 if vendor:row['vendor']=vendor
 if ident in ratios:row['restore_ratio']=ratios[ident]
 economy['items'].append(row)
recipes=[
 ('life_meal','热饭套餐','cook_hu',{'rice_pack':1,'vegetable_pack':1,'egg':1},{'rice_meal':1},2),
 ('life_sandwich','鸡蛋夹饼','clerk_qiu',{'rice_pack':1,'egg':1},{'egg_sandwich':1},3),
 ('life_drink','运动补给饮','cook_hu',{'water':1,'salt_packet':1},{'sports_drink':1},2),
 ('life_yogurt','水果酸奶','clerk_qiu',{'milk':1,'fruit':1},{'fruit_yogurt':1},1),
 ('life_notes','装订笔记','print_luo',{'clean_paper':2,'binder_clip':1},{'bound_notes':1},2),
 ('life_sign','绕行提示卡','print_luo',{'clean_paper':1,'tape':1},{'route_card':1},1),
 ('life_bag','布质整理袋','warden_chen',{'cloth':1,'sewing_thread':1},{'cloth_bag':1},2),
 ('life_pad','运动缓冲垫','warden_zhou',{'cloth':1,'tape':1},{'knee_pad':1},2),
 ('life_clean','清洁整理包','warden_chen',{'soap':1,'cloth':1},{'cleaning_kit':1},1),
 ('life_recycle','分类回收换票','worker_hou',{'old_cardboard':2,'scrap_metal':1},{'recycling_ticket':1},0),
]
economy['recipes']=[{'id':a,'name':b,'station':c,'ingredients':d,'outputs':e,'fee':f} for a,b,c,d,e,f in recipes]
write('物资与交易配置.json',economy)

tasks=read('任务配置.json')
print('task container',list(tasks)[:8])
# Every completed step spends one period. Looking/accepting/cancelling spends none.
def line(actor,text):return {'actor':actor,'text':text}
def step(q,n,hint,actor='',location='',dialogue=(),periods=None,choice=None):
 d={'event':f'side/{q}/{n}','count':1,'hint':hint,'marker':hint,'dialogue':list(dialogue)}
 if actor:d['actor']=actor
 if location:d['location']=location
 if periods is not None:d.update(periods=periods,period_names=[{1:'上午',5:'午休',2:'下午',3:'晚上',4:'深夜',0:'凌晨'}[p] for p in periods])
 if choice:
  question,a,b,ta,tb=choice
  d.update(question=question,choices=[['a',a],['b',b],['cancel','先想一想']],branches={'a':[line('narrator',ta)],'b':[line('narrator',tb)]})
 return d
stories=[]
def story(key,title,owner,description,intro,steps,outro,reward,epilogue,daily=False):
 ident='life_'+key
 stories.append({'id':ident,'type':'side','title':title,'description':description,'prerequisites':[], 'steps':steps,'side_story':{'owner':owner,'min_index':0,'life_story':True,'daily':daily,'description':description+' 每完成一步推进一个时段，时机不合时可以再来。','intro':[line(owner,intro)],'outro':[line(owner,outro)],'epilogue':[line(owner,epilogue)],'reward':reward}})

story('ladle','不是少盛一勺','cook_hu','查清午饭份量争执，听完窗口两侧的说法。','有人说我故意给后排少盛。我下意识想拿剩饭证明自己，可锅里剩多少，说明不了他碗里拿到多少。你愿意陪我把这事看清吗？',[
 step('ladle',0,'午休查看窗口份量记录',location='B07:1:0',periods=[5],dialogue=[line('narrator','同一条队里，前半段使用宽勺，后半段换了窄勺。记录只写“每人两勺”，没有写勺子的容量。一个学生把空碗藏到身后，说自己并不想被当作贪吃。'),line('zhao_mugei','我以前也会觉得开口要饭很丢脸。可吃不饱不是谁的错。')]),
 step('ladle',1,'向胡师傅说明量勺差异',actor='cook_hu',dialogue=[line('cook_hu','我忙得只顾数勺，竟没看见换勺。我先把漏掉的补齐。道歉不能让你替我说。')],choice=('如何公布补领办法？','在窗口贴统一补领说明','请值日生私下通知需要的人','补领公告不点名。胡师傅划掉了“凭证不足不补”的旧备注。','值日生逐一询问时先说明自愿，未把任何人的饭量写进名单。')),
 step('ladle',2,'午休核对调整后的供餐',location='B07:1:0',periods=[5],dialogue=[line('narrator','两种勺子旁都标上克重。前一天争执的同学再次排队，胡师傅先递碗，再问够不够，没有让他重讲那场难堪。')]),
 step('ladle',3,'回窗口听胡师傅的后话',actor='cook_hu',dialogue=[line('cook_hu','小的时候我也在窗口抬不起头，所以才总说我懂。今天才知道，懂过一次，不等于以后就不会疏忽。')])], '以后按标准份量供应，不够可以正常补领。先吃好，再去忙你的事。',{'g':35,'items':{'rice_meal':2,'rice_pack':2,'vegetable_pack':2}},'新勺子已经标好了。今天又有人说够了，我就知道不是所有沉默都代表满意。')

story('receipt','小票上的第二声滴','clerk_qiu','重复收款的误会，让双方都害怕被指责。','昨天有人说扫码响了两次，我却只看到一笔。我急着说不可能，他就再也没来。机器的记录和人的感觉，我该一起听。',[
 step('receipt',0,'午休查看小食堂终端说明',location='B08:1:0',periods=[5],dialogue=[line('narrator','终端有“扫描成功”和“结算成功”两种提示音。两声提示不一定代表两笔付款，但离线重试也可能留下待处理订单。')]),
 step('receipt',1,'在打印室整理匿名核对表',location='B15:1:2',dialogue=[line('print_luo','只记时间、金额、终端流水后四位。姓名和账户不要贴到公共栏。核实问题不需要把人摊开。')]),
 step('receipt',2,'把两类提示音说明交给邱姐',actor='clerk_qiu',dialogue=[line('clerk_qiu','原来确实有一笔待撤销。我嘴里的“不可能”，让他连拿小票回来都不敢。你帮我留出一个不用争辩的退款流程吧。')],choice=('退款核对怎样安排？','提供可密封投递的核对单','设窗口旁单独核对时间','密封单不公开账户信息，确认后按原付款渠道退回。','单独核对避开午休排队高峰，邱姐把认错放在解释之前。')),
 step('receipt',3,'午休回访小食堂核对流程',location='B08:1:0',periods=[5],dialogue=[line('narrator','窗口旁贴着两种提示音说明，也写着“没有小票可协助查询”。邱姐认出了那位同学，先递出核对结果，没有要求他原谅。')])], '退款办好了，他愿不愿再来，由他自己决定。谢谢你没让我把一句道歉也做成收款条件。',{'g':30,'items':{'egg_sandwich':2,'fruit':2}},'现在我会先问“发生了什么”，不再抢着说“不会的”。')

story('quiet','敲击声停下以后','worker_hou','施工噪声与考试安排错开，学生只参与安全的路线登记。','施工单写着下午，考试单也写着下午。两张都盖了章，最后却要让教室里的人忍着。我不想再拿“按单干活”挡回去。',[
 step('quiet',0,'上午核对办公楼施工告示',location='B15:1:corridor',periods=[1],dialogue=[line('narrator','施工单标“下午可作业”，旁边新贴的补考通知同样安排在下午。时间更改后没有人更新另一张纸。')]),
 step('quiet',1,'午休在打印室整理新绕行图',location='B15:1:2',periods=[5],dialogue=[line('print_luo','路线只标可通行的门和楼梯，不让同学翻围挡取捷径。先确定停工时段，再画路线。')],choice=('安全绕行图如何画？','按楼层分别标入口和出口','用一张总图配醒目的禁行区','分层小图在转角处重复标示，减少走到围挡才发现无路的情况。','总图上标出清楚的替代路线，禁行区旁不留下模糊捷径。')),
 step('quiet',2,'下午核对安静的考试走廊',location='B15:1:corridor',periods=[2],dialogue=[line('narrator','冲击钻没有启动，工具收进锁柜。工人在室外核对材料，考场门口只剩翻页声。侯师傅在新单上写明恢复作业需要再次确认。')]),
 step('quiet',3,'向侯师傅交还核对记录',actor='worker_hou',dialogue=[line('worker_hou','今天少做一点，明天还能补；让人受着委屈把考试熬过去，补不回来。你没碰电线也没爬架子，帮的忙已经够大了。')])], '以后变更时间，两边都签收。别拿学生的安全和安静赶工期。',{'g':40,'items':{'old_cardboard':4,'scrap_metal':2,'route_card':1}},'午休和考试都停噪声作业，专业维修仍由我们来。你想帮忙就帮我看看告示是不是清楚。')

story('key','没有交出去的备用钥匙','warden_chen','在帮助与隐私之间学会先取得同意。','有人替室友来拿钥匙，我没给。他觉得我是故意刁难。以前我总拿规矩解释，这回想把为什么也说清楚。',[
 step('key',0,'在一楼女生宿管接待室听说明',actor='warden_chen',dialogue=[line('warden_chen','三人寝并不等于三个人的东西都归一起。钥匙能开一间房，也能让没准备好的人突然被看见。帮忙得先问本人。')]),
 step('key',1,'查看公共区失物登记规则',location='B16:1:2',dialogue=[line('narrator','登记页只记物品特征和领取口令，没有寝室号和姓名的公开列表。一串钥匙被放进编号封袋，等待本人核对。')],choice=('怎样联系失主？','请宿管按登记私下联系','在公共栏贴不含寝室号的提示','陈阿姨通过登记的联系方式核验，没有把联系方式交给其他人。','提示只描述钥匙扣的大致颜色，细节留给本人核对。')),
 step('key',2,'晚间核对访客登记区',location='B16:1:0',periods=[3],dialogue=[line('narrator','来帮室友取资料的同学等在一楼。本人下楼把资料交给他，宿管没有打开任何寝室门。两个人说话时，比上午都轻松。')]),
 step('key',3,'告诉陈阿姨会面顺利',actor='warden_chen',dialogue=[line('warden_chen','他们说“原来还能这样”。我也该早点告诉他们替代办法，不能只给一个不字。')])], '规矩要守，也要让人知道怎样得到帮助。三楼私人寝室不对访客开放，一楼一直可以登记会面。',{'g':25,'items':{'soap':2,'sewing_thread':2}},'今天有人主动先问室友愿不愿意。我没有多说，只给他们腾了张椅子。')

story('water','墙里有人敲门','warden_zhou','水管异响让室友互相指责，证据带来一次迟到的道歉。','有人说楼上故意敲地板。我听了一会儿，也差点认定是学生。可值夜的人若只凭耳朵就判人，和传闲话有什么分别？',[
 step('water',0,'晚上在维修值班室登记异响时间',location='B16:1:5',periods=[3],dialogue=[line('narrator','记录显示声音总在多人集中用水之后出现，位置靠近独立卫生间的立管。你只在公共值班室登记，没有进入寝室或拆开管道。')]),
 step('water',1,'请周叔提交专业报修',actor='warden_zhou',dialogue=[line('warden_zhou','我把“疑似楼上敲击”划掉，写“集中用水后立管异响”。这两个写法，会把工单带去完全不同的地方。')]),
 step('water',2,'下午查看已签收的维修说明',location='B16:1:5',periods=[2],dialogue=[line('worker_hou','专业人员检查出固定件松动，水流变化会带来撞击。修完要观察，不能让你们拿敲墙当测试。')],choice=('如何告知先前被怀疑的室友？','先单独解释并道歉','在公共公告更正原因但不点名','周叔私下说明自己也曾判断太快，给对方留下回应的余地。','公告明确是管道问题，撤销先前指责，不把被误会者的寝室号写上去。')),
 step('water',3,'晚间回值班区听修复后的记录',location='B16:1:0',periods=[3],dialogue=[line('warden_zhou','今天没再收到异响。那几个孩子还没和好，我也没催。修一根管子比把话收回来容易，可都得有人开始做。')])], '记录会留着继续观察。你帮我记的是发生过什么，不是替谁找罪证。',{'g':35,'items':{'cloth':2,'tape':2}},'报修单先写事实。这句话我贴在桌上，提醒的首先是我。')

story('version','最后一页不是答案','print_luo','印错的资料让学生互相责备，老师承认自己也会出错。','我把两份不同版本的练习混在一起发下去了。有人因此被说成藏答案。我本想悄悄换掉，后来发现那样只会让误会留在他身上。',[
 step('version',0,'上午查看打印室的版本记录',location='B15:1:2',periods=[1],dialogue=[line('print_luo','第一份末页是空白答题区，第二份末页是解析。文件名只差一个字，修改时间差了六分钟。要把这六分钟说明白，不能只把错页收走。')]),
 step('version',1,'在公共自习室整理页码对照',location='B16:1:1',dialogue=[line('narrator','你把“总页数、末页标题、修订时间”排成三列，两份材料的差异一目了然。没有把任何学生的笔迹当成隐瞒的证据。')],choice=('更正说明应先写什么？','先写老师分发版本有误','先列版本差异并署名负责','罗老师把责任写在第一句，让同学不用先为自己辩解。','三项差异后面是罗老师的署名，并注明分发错误与学生无关。')),
 step('version',2,'午休在打印室核对更正通知',location='B15:1:2',periods=[5],dialogue=[line('print_luo','这次先印一份核样，再印全班。你看，承认出错以后，反而终于知道从哪一步改。')]),
 step('version',3,'向罗老师交回已校对的副本',actor='print_luo',dialogue=[line('print_luo','我以前总催你们“认真一点”，说得像认真就永远不会错。以后我会多教一句：出错时怎样留下可追溯的改正。')])], '更正已经发出。谢谢你帮我核对，也谢谢你没有替我把责任藏起来。',{'g':30,'items':{'clean_paper':6,'binder_clip':3,'bound_notes':1}},'原件封存，副本标明版本。今天有老师没课来打印，我们一起先核样再开机。')

story('track','两条路都要留出来','sports_du','篮下的球滚上跑道，竞争中的人开始照顾彼此。','昨天球滚到跑道，差点绊着人。打球的说跑步的人不看，跑步的说篮下的人不管。场地是共用的，不能只让声音小的人退。',[
 step('track',0,'下午观察篮球场外环跑道交叉点',location='B03:1:0',periods=[2],dialogue=[line('narrator','跑道绕着篮球场连续成环，取球的人却习惯直接横穿内侧弯道。问题集中在两个篮架附近，并不是整条跑道都不能用。')]),
 step('track',1,'向杜老师提出共用场地方案',actor='sports_du',dialogue=[line('sports_du','先停下取球、再看跑道来人。训练速度慢一点，也比靠别人躲开我们合理。')],choice=('怎样让共用规则更清楚？','在两端设取球等待点','为练球安排轮流看护落球的人','等待点离开跑道，队员先示意再取球，跑者保持方向和速度。','看护者提醒队友停步，不站在跑道上拦人；双方都保留活动空间。')),
 step('track',2,'晚上检查跑道与球场的共享安排',location='B03:1:0',periods=[3],dialogue=[line('narrator','一个队员冲着滚走的球迈了半步，又主动停下来。跑者经过后抬了抬手，不像胜利，也不像退让，只是终于看见了对方。')]),
 step('track',3,'找杜老师做一次回访',actor='sports_du',dialogue=[line('sports_du','以前我只夸快、准、赢。今天那个停下来的动作，也该算一次好表现。')])], '训练会累，按体能安排节奏；别用补给饮料硬撑不适。明天两条路都继续有人走。',{'g':30,'items':{'sports_drink':2,'cloth':2}},'取球先看跑道，跑步保持方向。能互相留出一步，也是进步。')

story('sorting','空箱子也有去处','worker_hou','每天一次，帮忙整理公共区的安全回收物。','今天的废纸箱已拆好，金属边料也由工人处理过尖角。你只负责核对分类和登记，不进施工围挡。',[
 step('sorting',0,'在维修值班室核对安全回收分类',location='B16:1:5',dialogue=[line('narrator','纸板保持干燥，金属另放，带油污的材料留给工作人员处理。登记单不把所有东西笼统写成“垃圾”。')]),
 step('sorting',1,'向侯师傅交还分类记录',actor='worker_hou',dialogue=[line('worker_hou','分清楚以后能再利用，也不会让后来搬运的人摸到尖角。今天这一份完成了，明天再来。')])], '今天的整理工资结清，材料按登记留给你作校内回收。',{'g':18,'items':{'old_cardboard':2,'scrap_metal':1}},'今天这份已经结算，别重复搬来搬去。下一个游戏日还有新的一份。',True)

story('returns','归还不算多余的一步','warden_zhou','每天一次，登记公共区用品的借还。','公共区的夹子和清洁用品借出去以后常找不到。今天帮我对一张归还单，不去翻谁的柜子。',[
 step('returns',0,'查看公共自习室的借还表',location='B16:1:1',dialogue=[line('narrator','有一栏写“借用中”，有一栏写“已归还待清点”。你把两栏分开，没有把尚未到期的借用算成丢失。')]),
 step('returns',1,'找周叔核对归还单',actor='warden_zhou',dialogue=[line('warden_zhou','按记录问比挨个怀疑省事多了。这不是罚款，今天的登记工作按份给报酬。')])], '今天登记完了，报酬和备用文具给你。',{'g':15,'items':{'clean_paper':2,'binder_clip':1}},'今天的单据已封存，明天的新借还再登记。',True)

newids={s['id'] for s in stories}
container='quests' if 'quests' in tasks else 'tasks'
tasks[container]=[q for q in tasks[container] if q['id'] not in newids]+stories
write('任务配置.json',tasks)
print('Added',len(materials),'supplies,',len(recipes),'recipes,',len(stories),'staff stories/jobs with',sum(len(x['steps']) for x in stories),'steps')
