"""Author the playable 1.3 campaign; preserve event IDs and original assets."""
from pathlib import Path
import json, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
if (ROOT/'VERSION').read_text(encoding='utf-8-sig').strip() not in ['1.0.0','1.1.0','1.2.0','1.2.1','1.2.2']:
    raise SystemExit('Historical first-pass authoring template. The finished 1.3.0 configuration contains later edits; edit the JSON directly instead of rerunning this script.')
def read(name): return json.loads((ROOT/name).read_text(encoding='utf-8-sig'))
def write(name, obj): (ROOT/name).write_text(json.dumps(obj, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def lines(text):
    return [dict(actor=a, text=t) for a,t in (line.split('|',1) for line in text.strip().splitlines())]

# Each entry has a playable lead-in and a separate aftermath, delivered only
# after that event succeeds. These replace the former one-line summaries.
SCENES = {
'night_hunt': ('''
zhao_mugei|我回座位坐了半天，书一个字没看进去。窗玻璃一响，我就以为又是那东西。
fei_yan|第一次都这样。我当年开着灯睡，第二天还跟人吹自己熬夜看球。
zhao_mugei|你也害怕啊？我以为高手都不需要睡觉。
fei_yan|高手也得写作业。害怕不是丢人，逞能才容易出事。今晚我在门口接应，你先试一只。
zhao_mugei|那说好了，你别等我喊救命才出来。我喊得不一定好听。
fei_yan|墨泥怕电，普通拳头打上去会卸力。看清弱点再出手，别光挑名字最响的招。
fei_yan|MP 不足就休整，精力能靠防守恢复。打不过先撤，双方血量保留，你活着比面子值钱。
''','''
zhao_mugei|它没了。我手还在抖……刚才差点想把书扔了。
fei_yan|你没扔，还知道看我的位置，这就够了。墨渣收好，牢李能用。
zhao_mugei|回去吃点东西吧。今天那份炒饭我还没吃，救世界也不能空腹。
'''),
'next_dawn': ('''
zhao_mugei|洗了三遍手，总觉得指缝里还有墨。原来打完怪，肚子照样会叫。
fei_yan|护符放枕边，别捂在被子里。明天照常上课，别把正常日子也丢了。
zhao_mugei|那你呢？你不回去？
fei_yan|我再看一圈窗户。以前总觉得自己多撑一点，别人就少知道一点。
zhao_mugei|明早给你带个包子。别又拿“高手辟谷”糊弄我。
''','''
system|洗漱、吃饭、睡觉。夜里没有英雄凯旋，只有闹钟准时响起。
zhao_mugei|生活费到了。包子两个，再留点买药，今天得学着算账了。
system|操场边有人停下晨跑，盯着实验楼新补上的窗纸。阳子记住了那个方向。
'''),
'yang_awakened': ('''
yang_zi|赵慕gei，昨晚实验楼蓝一道白一道的。我跑三圈回来，它还在闪。
zhao_mugei|球形闪电，科技中心实验。包子要不要？还热。
yang_zi|你紧张就请人吃东西。器材室的黑印、看台的划痕，还有你袖口的墨，是同一回事吧？
fei_yan|别再编了。阳子，你也沾上魔力了。我能帮你把它稳住，但这事可不是报名兴趣班。
yang_zi|我不想看你们出事还装没看见。先说清楚，学不会能不能退出？
fei_yan|随时能。遇事先叫人，不能拿“我跑得快”当护身符。
zhao_mugei|欢迎入伙。你负责跑，我负责喘，真遇上事咱俩谁也别落下谁。
''','''
yang_zi|原来魔力上来是这个感觉。我还以为心慌是包子吃急了。
fei_yan|魔法书只有一本，讲义找牢李印。先约主席台后面，别在班里点火。
zhao_mugei|书咱俩一起看。别急着拯救世界，先把今天的课上完。
'''),
'team_meet': ('''
lao_ao|往里蹲一点，这里挡风。纸别烧了，我还想把背面的题做完。
yang_zi|你也会？咱班到底还有几个正常学生？
lao_ao|我也想当正常学生。平时只够点一点火，大的动静会有代价。
fei_yan|魔力积久了会凝成怪物。半年里越来越密，我和牢傲一直在补洞，可洞在往外长。
zhao_mugei|所以你老趴桌子，不是熬夜打游戏，是没睡成？
fei_yan|有时候也打。别一下把我想得太高尚，我也烦。
yang_zi|那就把活儿拆开。牢李修东西，牢抽记线索，牢硕看退路。你们别什么都自己扛。
lao_ao|这个安排我喜欢。还有，别因为我说“会一点”，就逼我证明会多少。
''','''
fei_yan|行。每次行动先报位置，结束也报一次。人没回来，谁都不能先当他没事。
zhao_mugei|我先记你那份包子账。你不肯算自己的事，我替你记一点。
system|草稿纸上第一次写下了所有人的名字。巡查从一份讲义开始。
'''),
'handout': ('''
lao_li|墨渣给我看看。别拿手碰打印头，我刚擦干净。
yang_zi|你这机器连魔法书都能印？你到底背着学校修了多少东西？
lao_li|原理还是导线和符号。麻烦的是页码，错一页，火就从你袖子里出来。
zhao_mugei|那可太适合我了，上课举手就能暖和。
lao_li|别试。我把失败那页留着，提醒自己检查。20g 和一份墨渣，纸钱算一半，另一半买保险丝。
yang_zi|我不会白拿。下次搬纸我来，今晚的记录也我抄。
''','''
lao_li|装订好了。四种低级法术在前面，最后一页是急停，先看最后一页。
zhao_mugei|你这字写得像维修说明，但我放心。以后东西坏了先告诉你，不自己瞎掰。
lao_li|嗯。也别只在东西坏了才来，正常聊两句也行。
'''),
'library_trace': ('''
lao_chou|管理员说是虫害，可书页断面太齐，连借阅日期都被咬掉了。
yang_zi|是有人不想让我们知道谁借过书？
lao_chou|现在只能说“有这种可能”。我一着急就想把答案说满，上次把一个同学吓哭了。
zhao_mugei|那今天先当不及格侦探。我拿手电，你说哪页咱就照哪页。
lao_chou|别动最里面那本。记位置、记时间，再找第二条证据，不用一个猜想解释所有事。
''','''
system|书脊夹着半张借阅单，咬痕沿着一条细细的黑线通向墙脚。
yang_zi|先不打，是吧？我把封条按回去了，管理员明天还得开门。
lao_chou|对。仓库也有报告，我们把两个现场摆在一起看。
'''),
'warehouse_trace': ('''
lao_shuo|大爷把门前杂物挪开了，咱出来别挡人推车。地上这条拖痕是新添的。
lao_chou|枯枝从墙角到了门口，跟图书室一样，都朝办公楼偏。暂时不是结论。
yang_zi|我在这里夜跑过，昨天还没这么多。绕一圈比硬踩过去快。
zhao_mugei|等下，这里挂着根校服袖子。别拿走，我拍个位置。
lao_shuo|会打也得会退。稳固防线不只是站着挨揍，是把身后的人留在安全地方。
''','''
system|众人用粉笔标出安全落脚处，把散落的枝条收进空箱，留出后勤通道。
lao_chou|三个点还差实验楼。光凭拖痕说有人养怪，太早。
zhao_mugei|那就再走一趟。回头咱报告里也写“大爷车能过去了”，别只写怪物。
'''),
'elite_lesson': ('''
fei_yan|先停。这件校服比昨晚那摊泥厚，魔力在外面结了壳。
zhao_mugei|我刚学会电，它就升级装备，针对我是吧？
fei_yan|换光系。精英护壳让单次最多掉七成生命，留着力气处理它下一步。
yang_zi|它袖口在缩，像要扑过来。你打，我盯动作。
fei_yan|这次也学会停手：防守能回精力，屏障挡两次。别因为第一下漂亮，第二下就把人赔进去。
''','''
zhao_mugei|打第二下之前，我居然先看了它的手。以前打游戏我只盯血条。
fei_yan|所以今天教你【稳息】：治疗少量伤势并减伤，三回合冷却。补状态也得看时机。
yang_zi|我记下来了。等我们都忘了的时候，就翻讲义最后一页。
'''),
'patrol_done': ('''
lao_chou|图书室咬痕、仓库拖痕、实验楼袖口，三条线都朝办公楼。还有人工刮开的导流槽。
fei_yan|我之前一直盯着怪在哪儿冒，没想到有人替它们修路。
zhao_mugei|你一个人巡，哪有空蹲下来拍地砖。现在我们人多了。
lao_li|我做个探针，灵敏度不高，但能排除普通电线。坏了别藏，拿回来我改。
lao_chou|下一步去图书室里面，看看那条黑线从哪里来。不能只因为像谁干的，就认定是谁。
''','''
fei_yan|先把等级和法术练稳。5 级能学中级，火、电、冰、光选哪一个都能推进。
zhao_mugei|你也去吃饭。今天的结论不是你漏了事，是咱们终于看全了一点。
system|费眼把巡夜本合上，第一次没有独自转身回实验楼。
'''),
'medium_lesson': ('''
fei_yan|低级法术练的是把力量送出去，中级练的是收回来。不能收，威力越大越危险。
zhao_mugei|像我说话说到一半知道该闭嘴？那我这科可能得补考。
fei_yan|差不多。你进步快，我有时候也不舒服，怕自己以后只能给你看门。
zhao_mugei|你教我别逞能，我转头就把老师忘了？那我学得也太差了。
fei_yan|行，嘴还是那个嘴。到 5 级，找我学任意一种中级，四系各 100g。准备好了再进图书室。
''','''
fei_yan|记住冰系不只是低伤害。它能让敌人动作迟下来，有些蓄势的大招能直接打断。
yang_zi|那我喊动作，你收力。咱俩别抢着当最厉害那个。
system|从这堂课起，赵慕gei开始认真写法术笔记，首页仍然画着一只很丑的包子。
'''),
'library_enter': ('''
la_jiao|你们三天没齐交过一次作业，今天一起申请图书室，理由写得还一模一样。
zhao_mugei|咱们班……学习氛围浓厚？
la_jiao|你先把“浓厚”写对。管理员说里面危险，我不能随便替你们担保。
yang_zi|我们查到啃书的东西了，想清掉它。真出事先撤，不拿书架挡门。
la_jiao|我可以开条子，但你们出去报平安。我管考勤，是怕有个人少了，大家还以为他只是逃课。
zhao_mugei|这次不糊弄你。钥匙和侧窗也能进，但回头损失该赔就赔。
''','''
system|门里闻得到潮纸味，门外辣椒把三人的名字写在借用单背面。
yang_zi|先从外排开始，退路是刚才那扇门。我不跑到你看不见的地方。
zhao_mugei|收到。今天火小一点，胆子也稳一点。
'''),
'books_clear': ('''
yang_zi|那本书自己翻页了。别急着放大火，借阅卡还夹在里面。
zhao_mugei|我把火缩到指头大，像给它点个蜡烛。
fei_yan|火别离手太近，按练的来。连续清三只，波间可以回白圈整备。
yang_zi|你喘气的时候换我盯着。我们来抓怪，不是比谁清得快。
fei_yan|低级精准火可以，中高阶或蓄力会触发喷淋、赔书。威力合适才算会用。
''','''
system|噬书怪散成黑屑，书页有几张救了回来，有几张已经只剩半边。
zhao_mugei|我刚才想一把火省事。现在看这借书卡……人家明天还要还书呢。
yang_zi|最里面有人。她没跑，还在帮咱们捡页码。
'''),
'wr_meet': ('''
wr|这张第七页，那张第八页。倒过来拼，读的人就永远找不到结尾。
zhao_mugei|你在这里干什么？消杀通知你没看？
wr|看了。有人把我借的书锁里面了。你们怕火失控，我也怕，有些手艺不适合拿到人前。
fei_yan|你手上那种黑火，会吃理智。别靠近他们。
wr|我知道你怕什么。可你们刚才也没把烧过的书直接扔掉。
yang_zi|能先一起把书救出来吗？你是什么人，出了门慢慢问。
wr|可以。真巢在半地下书库，我领路，你们别走在我背后装作看守。
''','''
wr|借阅卡背后是残页。先保管，别随便念，黑魔法便宜在蓝量，贵在你自己。
zhao_mugei|你也别一个人碰。要真有危险，就像刚才拼书一样叫个人帮忙。
system|wr 没有立刻答应，但把原本攥紧的手松开了。
'''),
'book_queen': ('''
wr|纸堆下面有脉搏。它把别人的批注和没写完的话当成了壳。
yang_zi|刚才那几只是在给它送纸？先清护巢的小怪，再打本体。
zhao_mugei|它那张嘴看着像要把整排书吞了。有没有个不用烧整间屋的办法？
wr|看它合页前的动作。小火拆纸甲，冰冻结纸刃，别往它准备好的方向硬撞。
fei_yan|看上方的招式预告。对准反制元素就能破招、压低这次反击，连破两次还能抢回一个空当。
zhao_mugei|那今天咱们比谁更会收手，试试。
''','''
system|大噬书怪塌成一册破书。wr 伸手接住书脊，指尖的黑火一点点熄掉。
wr|你们没有趁我动手，把“危险的人”一起处理掉。
zhao_mugei|你刚才替阳子挡了纸刃，我看见了。危险的东西和做错的事，咱分开算。
wr|那学个【清明印】吧。花一点 MP 整理呼吸，清掉封蓝和易伤。不是让你随便相信谁。
system|修好的借阅卡上，领书人签了四个名字。第二天，牢李的名字却出现在另一张名单里。
'''),
'li_start': ('''
lao_li|群里说我偷器材卖钱，截图里连我头像都一样。我把原记录发了，没人往上翻。
zhao_mugei|我去群里骂他们。
lao_li|别。你一骂，他们就说咱们急了。老师刚把办公室钥匙收走，我还没来得及解释。
lao_chou|咱们留原图、核对值日表，别用“他人好”代替证据。
lao_li|我不怕少做两单东西。我就是……不想以后碰什么，都得先问别人信不信我。
zhao_mugei|那我先坐这儿，不催你修，不逼你笑。等你想说了，咱一起找原件。
''','''
system|打印机没有开，牢李把工具一件件摆回盒里。护符坏了，他仍伸手接了过去。
lao_chou|先去找独立证据，三份互相核得上才提交。暂时搁置还可以补救。
zhao_mugei|不用急着证明你还有用。你歇一会儿，我们去跑腿。
'''),
'li_hearing': ('''
la_jiao|先把群消息放下。值日表、报修单、原图按日期摆，哪份谁拿来的，说清楚。
lao_chou|只读事实，不读评论。我们需要至少三个独立来源，缺的可以继续查。
lao_li|我想自己讲。之前我总觉得把东西修好，别人自然就会明白。
zhao_mugei|你讲，我不抢。要是说不下去，喝口水再来。
la_jiao|现在能提交，也能先保留。过了窗口仍可补证翻案，别为了赶日期凑假的。
''','''
lao_li|有没有结论，我都想把原记录留着。不是以后不帮忙，是得留一份能替自己说话的东西。
zhao_mugei|下回你干活我替你拍照，拍丑了可以重来。
system|那晚新的探针多了一只记录灯。下一条读数指向办公楼。
'''),
'office_infiltrate': ('''
fei_yan|原件上的墨跟图书室一样，但这不是说谁坐这里，谁就有罪。
lao_chou|对。顺着导流槽找装置，别顺着愤怒挑人。
zhao_mugei|我以前一听“调查”就想抓个坏人，现在才知道先得听人把话说完。
fei_yan|门边两只枯枝，先断它们的线。打完别碰封存的档案。
lao_li|我远处看探针。你们报读数，我把时间记上，这次记录有备份。
''','''
system|枝条退去，导流槽通向一张旧的校园排水图。最深处的树根正有规律地收紧。
fei_yan|有人改过阵，也有人故意让改阵失败。两种痕迹，不一定是同一个人。
zhao_mugei|先把出口留着。明天谁来上班，也得有地方落脚。
'''),
'ancient': ('''
gou_ga|你们最近真顺。救书、查案、当英雄，下次是不是要给自己挂个锦旗？
yang_zi|上次你把我引进器材室，说里面有人。今天还有什么话术？
gou_ga|你不是挺能跑吗？摔一次才知道谁会停下来等你。
zhao_mugei|拿别人受伤试这个，挺没意思的。你想知道有人会不会等，先别把门锁上。
fei_yan|别跟她站一个落点。老树在收根——火断根，冰拖慢蓄势，先救人再争输赢。
gou_ga|那就让我看看，你们能一起撑几轮。
''','''
system|老树倒下时，阳子先把牢李的探针捞了出来；gei 子伸手去拉阳子，没有追远处的勾尬。
yang_zi|你刚才不追她，是不是觉得我又要摔？
zhao_mugei|觉得这地滑。你想跑，等腿好利索，咱一起。
system|折断的树根露出第二层符文，和牢董曾在作业本上画的图一模一样。
'''),
'yang_frame': ('''
wen_cong|器材室撬锁、看台损坏，有人指认阳子夜间出入。先核实，不先定性。
yang_zi|我确实去过，可门是从外面锁的！上回受伤我没讲清，这回又像我编的。
la_jiao|我记得他回来时走不稳。那天的考勤还在，不能靠一张截图跳过。
zhao_mugei|阳子，先坐。我知道你着急，咱们把每个时间说清楚。
yang_zi|我想自己跑去把她找来……可上次就是这么被骗进去的。
wen_cong|那这次先查锁、查录像、查证人。校内处理要靠证据，我给你们核验的时间。
''','''
yang_zi|我第一次觉得跑得快没用。人家一句话，我跑一天也追不上。
zhao_mugei|你不用一个人追。你把事情讲完，剩下的路咱们分着走。
system|阳子把没发出去的争吵删掉，开始在纸上画那晚的路线。
'''),
'yang_hearing': ('''
wen_cong|时间线放第一份，监控和物证各放一边。指认也要经得起核验。
lao_chou|护腕压在碎玻璃上面，先破窗，后有人摔倒；不能倒着讲成他砸窗。
yang_zi|我那天真以为里面有人等着救。现在说出来还觉得丢脸。
zhao_mugei|想救人这事不丢脸。设局的人才该解释为什么骗你。
wen_cong|有三份独立证据就提交；若还有缺口，保留继续调查，不用用气话填上。
''','''
yang_zi|以后有人喊“就你能救”，我先叫上你们。不是我不敢，是我终于信有人会来。
zhao_mugei|学会【踏风步】吧，把跑得快用在换位上。躲开预告的大招，再拉别人一把。
system|阳子重新系紧鞋带。旧伤没有凭一句宽慰消失，下一次行动，他开始等队友到齐。
'''),
'dong_talk': ('''
lao_dong|你们拿到的符文，是我家封印上的。前些天我就认出来了。
zhao_mugei|所以你一直知道，怎么现在才说？
lao_dong|我以为少说，能把你们留在外面。看阳子坐在这里，我才知道沉默也会把人推到危险里。
fei_yan|我也干过。替别人决定什么都不知道，不一定算保护。
lao_dong|旧宅的钥匙在我手里。祖辈说门只能由守印人承担，我想让你们亲眼看看，再一起判断。
zhao_mugei|那这回别只说“没事”。你怕什么，也能说。
''','''
lao_dong|我怕把朋友带进去，又怕自己根本守不住。两件事，我都怕。
yang_zi|终于听见你说了。走吧，谁先害怕，谁先出声。
system|旧宅的位置写在地图上，不再只有牢董一个人知道回来的路。
'''),
'dong_house': ('''
lao_dong|这里以前住着祖母。她总留两双拖鞋，说守印人不该把家过成岗哨。
zhao_mugei|那另一双给谁？
lao_dong|给会来的人。我小时候以为是祖父，后来才明白，她也在等朋友。
wr|门底的污染不是凭空来的。有人引流养怪，有人泄压搅局，最后受伤的却是没选过的人。
lao_dong|勾尬幼时碰过门，成了半人半闸。她用恶意维持摇摆，伤害是真的，困境也是真的。
yang_zi|我能知道她为什么，跟原谅她是两回事。先别替我选原谅。
lao_dong|好。我们查清，把伤害停下，之后的事各自决定。
''','''
system|石室入口的灰被扫到一边。牢董把旧宅的第二把钥匙交给了众人。
zhao_mugei|你家这回可能有点吵。等忙完了，咱把拖鞋补够。
lao_dong|嗯。先把下面的灯点亮。
'''),
'rune': ('''
lao_chou|2、4、8、16。规律很简单，可边上磨损的笔画说明有人改过。
wr|别急着背答案。错一根会招来空壳，最多三波惩罚，能补救。
lao_chou|我总想第一个解出来，怕慢了就显得没用。这次你们帮我检查一遍。
zhao_mugei|我算数一般，但我能看哪根柱子晃。咱不拿一个人的聪明赌所有人的安全。
lao_dong|点对之后，把每个人站的位置都记下。最后守门时用得上。
''','''
system|第五根石柱亮起，光顺着几双鞋子的影子连成闭环。
lao_chou|是 32。可这次最有用的不是我答对，是你们没让我独自伸手。
lao_dong|学会【共鸣破印】。对准预告弱点能多拆一层架势，配合队友，力量才不会只压在一个人身上。
'''),
'seal_defend': ('''
lao_dong|阵已点亮，空壳沿着门缝来了。先光后火，分三波守，波间能整备。
wr|我守内圈。黑火不碰你们的影子，你们也别踩我的线。
yang_zi|我报方向，不乱跑。刚才哪根柱子晃，记住了吗？
zhao_mugei|记住了。以前我一听要分工就想躲活儿，现在发现分工才敢喘口气。
fei_yan|那就照约定来。谁掉队，先补位，别先问是谁的错。
''','''
system|最后一件空壳倒下，石柱没有碎，门却在远处重重跳了一下。
lao_dong|不是完全封住，只是把压力分开了。校园那边可能会有一波回冲。
zhao_mugei|给辣椒发消息。咱们守了阵，也得回去把人接住。
'''),
'tide_lab': ('''
fei_yan|回冲到了。实验楼灯灭一层，秋实楼还在上晚自习。
lao_li|广播能用，备用线也接好了。我在远端报位置，不让你们摸黑冲。
yang_zi|我和费眼去实验楼；牢董、牢硕守操场；你跟牢傲先顾教学楼。我看见缺口会先报。
zhao_mugei|咱从这里清出通道再分开。今天谁也不当“唯一能救的人”。
fei_yan|墨泥和空壳各一只。别省那口气，清完确认彼此在，再去南门。
''','''
lao_li|线路稳定。广播有杂音，但听得见，先别关。
fei_yan|通道能走了。阳子回过头等我，我突然觉得今晚不用撑到自己倒下。
system|电光沿着校园传开，下一处集合点是南门与操场。
'''),
'tide_gate': ('''
lao_shuo|后门我守，别让同学往黑处跑。先疏散再合闸，最后亮灯。
zhao_mugei|你一个人挡得住？
lao_shuo|挡不住就后撤两步，叫支援。想当军人不是站着逞强，是让人平安过去。
lao_li|我等口令。顺序一错会把人留在灯阵里面，听清了再按。
yang_zi|我去喊末排。你看着人数，跑腿我来。
''','''
system|人群走出暗处，灯阵才一排排亮起。牢硕握旗杆的手抖了抖，又松开。
lao_shuo|刚才真紧张。等会儿别说我脸白，我自己知道。
zhao_mugei|你已经够稳了。秋实楼那边还缺人，走，一起过去。
'''),
'tide_school': ('''
la_jiao|低楼层先下，高楼层等口令，不挤楼梯！名单给我，别在群里喊“应该齐了”。
zhao_mugei|我顶这边。你不怕？
la_jiao|怕。我记名字记得太清楚，少一个我都睡不着。现在先别问，帮我把出口守住。
lao_ao|袖口的黑线在往楼梯缠。先打空壳，再烧掉枯枝，别让火堵住逃生方向。
zhao_mugei|行。今天这份出勤，我替你守着写完。
''','''
system|楼梯口空出来，辣椒又数了一遍。广播里忽然传来升旗杆被拖动的金属声。
lao_ao|是领头的。我一直藏着，不是因为不在乎你们，是怕变完就拖后腿。
zhao_mugei|那就把代价告诉我们。我们一起选，别到最后才知道你要倒下。
'''),
'ao_transform': ('''
lao_ao|我能变身，一次能把它的壳拆掉大半。之后虚弱七天，这七天得坐着休养，不能参战。
fei_yan|你不变，我们也能换着守。你不用因为会这招，就觉得欠大家。
lao_ao|我知道。这次我想用，不是被逼出来的。之后作业、吃饭、巡夜，你们帮我分。
zhao_mugei|巡夜我接，饭阳子带，笔记牢抽抄。你负责别偷着来证明自己好了。
lao_ao|成交。升旗手举旗是在号令，光能打散，电能断令，冰能压住挥旗。我的光过后，还得靠你们接住。
''','''
system|光散去，牢傲没有立刻站稳。赵慕gei蹲下让他扶肩，阳子把水拧开。
lao_ao|我现在真的很没劲。你们别拿这个取笑我。
zhao_mugei|不笑。你歇七天，这不是欠我们的，是咱刚才说好的。
system|【牢傲进入七天虚弱期，坐在十班休养。协同请使用其他伙伴或强光雷。】
'''),
'tide_clear': ('''
la_jiao|点名开始。听见名字就答，替人答不算，没到的报最后位置。
lao_li|强光雷还有三枚，交给你们。我刚才差点接反线，幸好留了复核记录。
yang_zi|我从最后一排回来了。以前一跑就想甩开所有人，今天跑快是为了多回头一次。
zhao_mugei|别总结了，先喘匀。牢傲的水放桌边，别让他伸胳膊去够。
la_jiao|名单还要再核一遍。有没补清的事就继续补，不拿“打完怪”替谁消掉冤枉。
''','''
system|清晨有人换灯泡，有人拖地，有人送来热粥。战斗结束后的校园仍需要人一点点修。
fei_yan|我今天不巡夜了，补个觉。你们有事叫我，没事也能来。
zhao_mugei|好。下一个难关好像是期中考试，比怪还不讲道理。
'''),
'exam': ('''
lao_chou|这题从定义来，别背我昨天那个速解。我后来发现漏了条件，已经划掉了。
zhao_mugei|你都能认错，我也不能把空白卷子赖在门底身上。
fei_yan|考试不许魔法作弊。你法术快，题目不会因为你是天才就少一道。
lao_ao|帮我把卷子往近处推点。我手没劲，脑子还能用。
la_jiao|谁带多余的笔，借后排一支。今天咱们正常考，考完正常吃饭。
''','''
system|铃响，赵慕gei最后检查了姓名栏。他没把每道题写对，但这张卷子是自己写的。
yang_zi|今晚操场一圈？不比速度，走也行。
zhao_mugei|行。明天要面对什么，今天先把这顿饭吃完。
'''),
'preparation': ('''
yang_zi|旧伤还有点酸，我跑不出以前的成绩了。等门的事完了，我想重新练，慢一点也练。
lao_li|探针备份、药、灯，我都检查了。你们也检查我，别因为信我就省这一步。
wr|黑火的代价写清楚了。你愿不愿意用，自己选，别因为我教了就觉得必须还人情。
lao_dong|家里的门我会守，但不再拿朋友换一道封印。最后的阵位，大家一起定。
fei_yan|35 级以上再去，至少备一种超级法术。打勾尬先看她的手势，别被她的话牵着走。
zhao_mugei|我最早就想逃晚自习。现在还是想，可我想的是咱们一起放学。
yang_zi|证据、碎片、没说完的话，能补就先补。路线是分工，不是让你把其他人推出去。
''','''
system|背包检查完了，名单却没有合上。每个名字旁边，都写着有人会接替他的位置。
zhao_mugei|我害怕。你们都知道了，别等我装不下去才来帮忙。
fei_yan|这句话比你学会超级法术还像个高手。走，去见勾尬。
'''),
'gate': ('''
system|门扉没有出现陌生的怪物。勾尬站在阵心，手里捏着那张被撕碎的假指认。
gou_ga|你们把每条线都接上了。再往前一步，封门就得把我封在里面。现在还想说“一个都不少”？
yang_zi|你让我受伤，还想让我替你解释？我不会。但我也不会让你继续害别人。
wr|门在吞她的魔力，她又借门的力。先打断她操纵，不要向身后的空洞倒力量。
lao_dong|守印屏障已展开。勾尬是最后的对手，门的选择要等她停手以后，谁都不能替所有人决定。
gou_ga|那就看看，你们嘴里的朋友，被换走蓝、断了路、拆了护盾，还剩多少。
zhao_mugei|咱有前面一路一起犯过错、改过错的人。你这一招，我们不靠一个人扛。
fei_yan|看预告反制：光拆谣言，电断牵线，冰冻地缚。半血后她会失衡换招，不会暗中回满血。
''','''
system|断裂的紫光停在半空。勾尬膝盖一软，手里那张纸终于掉了下来，门仍在她身后震动。
gou_ga|怎么不继续？你们不是终于赢了吗？
yang_zi|让你停手，跟替你免掉做过的事，是两回事。先把门处理了，你还得说清楚。
zhao_mugei|我打的是你控制别人的那只手。现在它放下了，剩下的咱们认真选。
lao_dong|有三种处理，代价都摆出来。证据和准备会改变结果，先想清楚再动手。
'''),
'choice': ('''
gou_ga|你们知道我为什么搅局了，还会留我？我可没说我要变成好人。
yang_zi|我也没答应原谅你。可我不想让谁再被一句“只能这样”推下去。
wr|封住、吞噬、解开，各有代价。黑暗不能靠否认消失，也不能靠一句理解免掉责任。
lao_dong|真相、碎片和三边的人手够不够，先看清。条件不足，我们就承担有限的结果。
zhao_mugei|今天不再靠谁偷偷牺牲。大家知道代价，再做选择。
''','''
system|选择已经落下。无论此后怎样，众人都记得谁受过伤、谁伸过手，以及还有哪些事没有做完。
'''),
}

def intent(name, kind, power, counters, hint, **kwargs):
    return dict(name=name, kind=kind, power=power, counters=counters, hint=hint, **kwargs)

BOSS_TACTICS = {
'book_eater_queen': dict(break_limit=2, intro='它吞下的不是知识，是许多没写完的话。', patterns=[
    intent('吞页筑甲','physical',.65,['fire'],'小火拆开纸甲；无需大火烧书。'),
    intent('纸刃风暴','physical',1.35,['frost','fire'],'冰封纸刃或精准火破招；也可防守。'),
    intent('空白吞读','magic',.85,['light'],'光照露出书脊，清明印可预防封蓝。',status='seal')]),
'dry_branch_ancient': dict(break_limit=2,intro='每一下根须收紧，都把退路挤掉一点。',patterns=[
    intent('盘根束足','physical',.8,['fire'],'火断根；踏风步可保住退路。',status='vulnerable'),
    intent('旧铃回声','magic',.7,['lightning','light'],'电断铃声或光照符纸。'),
    intent('倒木重锤','physical',1.45,['frost','fire'],'蓄势明显，冰火反制或稳固防线。')]),
'empty_uniform_leader': dict(break_limit=2,intro='空校服也在点名，却没有一个名字得到回答。',patterns=[
    intent('列队号令','magic',.75,['lightning','light'],'电断号令，光拆空壳。',status='seal'),
    intent('旗枪横扫','physical',1.35,['frost'],'冰迟滞挥旗，踏风步能完全躲开。'),
    intent('空名敬礼','magic',.95,['light'],'光点亮真正的名字。')]),
'gou_ga_boss': dict(break_limit=2,phase_at=.5,intro='她依旧穿着那件校服。恶意与求救挤在同一句话里。',
    phase_line='勾尬：别用那种眼神看我！我不需要你们替我决定！\n阳子：那你也不能再替别人决定受伤。门底失衡，招式已换。',
    patterns=[
        intent('流言倒灌','magic',.65,['light'],'光揭破假指认；清明印能消除封蓝。',status='seal',mp_drain=.06),
        intent('借刀牵线','magic',.9,['lightning'],'电切断紫色牵线；护盾能挡伤害和干扰。',status='vulnerable'),
        intent('锁门地缚','physical',1.25,['frost'],'冰冻地缚；踏风步越过锁线，或守住阵位。')],
    phase_patterns=[
        intent('无声点名','magic',1.0,['light'],'光让每个名字被听见；防守或屏障保住理智。',status='seal',mp_drain=.08),
        intent('撕约返潮','magic',1.2,['lightning'],'电切断门与她的回路；共鸣破印能多拆一层。',status='vulnerable'),
        intent('门底坠落','physical',1.55,['frost'],'最强蓄势：冰破招、踏风步，或稳固防线。')]),
}

def main():
    story=read('剧情配置.json'); c=story['campaign']; c['version']=2
    for n in c['nodes']:
        before,after=SCENES[n['id']]
        n['dialogue']=lines(before); n['after_dialogue']=lines(after);n.pop('extra',None)
        n['cast']=list(dict.fromkeys(x['actor'] for x in n['dialogue']+n['after_dialogue'] if x['actor'] not in ['system','zhao_mugei']))
    c['chapter_titles']['part_9']='门前的同学 · 勾尬决战'
    for n in c['nodes']:
        if n['id']=='gate': n['battle']=['gou_ga_boss'];n['title']='门开之日：与勾尬正面对决'
        n['learn_skills']={'elite_lesson':['second_wind'],'book_queen':['clarity'],'yang_hearing':['wind_step'],'rune':['resonance_break']}.get(n['id'],[])
    c['skill_milestones']={'elite_lesson':['second_wind'],'book_queen':['clarity'],'yang_hearing':['wind_step'],'rune':['resonance_break']}
    c['banter']={
      'fei_yan': [lines('fei_yan|以前我以为把人挡在外面就够了。现在看，你们知道得越多，我睡得越踏实。\nzhao_mugei|那今天早点睡。我练错了会来问，不拿自己试着玩。'),lines('fei_yan|你现在有些法术比我强。我羡慕，可我也挺高兴。\nzhao_mugei|别光高兴，看看我这笔记，第三行我又没懂。')],
      'lao_li': [lines('lao_li|今天没接新委托，给自己修了台旧收音机。修了半天，还只会沙沙响。\nzhao_mugei|等修好了叫我，咱听点跟怪物无关的。'),lines('lao_li|我多留了一份原记录。相信别人和保护自己，应该能一起做。\nzhao_mugei|能。我替你看着，备份也别只放同一个柜里。')],
      'lao_chou': [lines('lao_chou|我把“肯定”改成“目前证据支持”了。四个字省不了，省了容易害人。\nzhao_mugei|我下次也少说一句“这我太懂了”。不保证一次改好。'),lines('lao_chou|能帮我验一遍吗？以前我不太敢问，怕别人觉得我也有不会的。\nzhao_mugei|你先教我怎么看，我可能验得慢，但我认真。')],
      'yang_zi': [lines('yang_zi|今天跑到转弯，我下意识看了看后面。以前那里只看成绩牌。\nzhao_mugei|我在后面喘呢。别催，至少没掉队。'),lines('yang_zi|我还会生气，听见她名字就生气。这不会让前面的努力白费吧？\nzhao_mugei|不会。咱保护人也没规定得先笑着。')],
      'la_jiao': [lines('la_jiao|那张出门条我还留着。以前我只在意填没填，现在还会看人回没回来。\nzhao_mugei|我也把作业交了，今天你能少操一点心。'),lines('la_jiao|大家喊我厉害的时候，我还是会怕自己漏了谁。\nzhao_mugei|名单给我一份。你能记住大家，大家也能帮你记。')],
      'lao_shuo': [lines('lao_shuo|今天练的第一项是后撤。以前总觉得这两个字说出来丢人。\nzhao_mugei|后撤两步人还在，咱下次就还有人练。'),lines('lao_shuo|我真想当军人，想得越多越知道光有热血不够。\nzhao_mugei|那就继续练，顺便练练喊我们帮忙，别一人包了。')],
      'lao_dong': [lines('lao_dong|家里第二双拖鞋已经摆到门口了。尺寸不太合，下次一起去买。\nzhao_mugei|多买两双，咱这伙人有点占地方。'),lines('lao_dong|祖辈留下来的规矩，我不再只问能不能改，也问不改会伤到谁。\nzhao_mugei|你慢慢问。我这回有空听你多说几句。')],
      'lao_ao': [lines('lao_ao|我把音游速度降了一档。手不跟我作对的时候，听歌本身也挺舒服。\nzhao_mugei|那今天不刷分。水在近处，你叫我拿就行。'),lines('lao_ao|上次说“不能拖后腿”，现在觉得挺伤人的，包括伤我自己。\nzhao_mugei|你坐着也是咱们的人，又没按伤害排名收朋友。')],
      'wr': [lines('wr|那本书终于能借了，我还没看完。你们总在最悬的时候喊我出门。\nzhao_mugei|下次借我，看完咱聊结尾，聊点不是门的。'),lines('wr|我会写清黑火的代价。别人愿意用才教，不把信任写成契约的小字。\nzhao_mugei|你有事也直接说，别总留一半让别人猜你会不会走。')],
      'gou_ga': [lines('gou_ga|你们又一起走。少一个人就那么难受？\nzhao_mugei|会难受。所以别拿别人试，有话可以直接说。'),lines('gou_ga|你以为查到原因，我就会哭着谢谢你？\nzhao_mugei|没以为。先停手，受伤的人有权不谢谢你。')],
    }
    # Chapter one's original jokes remain intact; surround them with everyday
    # relationships that can be recalled at the end of the story.
    d=story['dialogues']
    if not any('包子账' in x['text'] for x in d['morning']):
        d['morning'][0:0]=lines('lao_li|你的眼镜刚才又掉我桌上了，螺丝拧紧了，别拿袖子硬擦。\nzhao_mugei|记你一个包子，计入包子账。以后发达了都还。\nla_jiao|发达之前先坐好，阳子把窗关上，牢傲的书别吹跑了。')
        d['evening']+=lines('yang_zi|我去操场跑两圈，吃完来不来？\nzhao_mugei|我跑半圈就当两圈，先吃饭，回头找你。\nsystem|后来他才想起，那个随口说的“回头”，也该有人等着。')
        d['reveal']+=lines('fei_yan|刚才你站门口，我真怕你再往里一步。骂你不是嫌你多事。\nzhao_mugei|我知道。你下次也别等别人撞见了，才肯说自己在干什么。')
    write('剧情配置.json',story)
    rules=read('战斗与刷新配置.json'); rules['version']=3
    for name,spec in BOSS_TACTICS.items():
        if name=='gou_ga_boss':
            rules['monsters'][name]=json.loads(json.dumps(rules['monsters']['gate_entity']))
            rules['monsters'][name].update(name='勾尬 · 门底失衡',multipliers=dict(hp=10,attack=1.3,defense=1,magic_resistance=1),world_height=48)
        rules['monsters'][name]['tactics']=spec
        rules['monsters'][name]['portrait_atlas']=f'assets/characters/bosses/{name}/atlas.png'
        rules['monsters'][name]['art']=f'assets/characters/bosses/{name}/world.png'
    # Keep legacy id for existing discovered-monster and retreat saves.
    rules['monsters']['gate_entity']=json.loads(json.dumps(rules['monsters']['gou_ga_boss']))
    rules['skills'].update({
      'second_wind':dict(name='稳息',kind='support',teacher='fei_yan',level=1,price=0,mp_base=15,mp_growth=2,cooldown=3,description='治疗最大 HP 的18%，本次减伤35%；冷却3回合'),
      'clarity':dict(name='清明印',kind='support',teacher='fei_yan',level=1,price=0,mp_base=10,mp_growth=1,cooldown=3,description='净化封蓝/易伤并免疫两次干扰；恢复少量精力，减伤35%'),
      'wind_step':dict(name='踏风步',kind='support',teacher='lao_shuo',level=1,price=0,energy_cost=35,cooldown=3,description='必定闪开本次攻击和附加效果，恢复少量 MP；冷却3回合'),
      'resonance_break':dict(name='共鸣破印',kind='support',teacher='fei_yan',level=1,price=0,mp_base=15,mp_growth=2,cooldown=3,description='弱点魔力造成0.6倍攻击伤害，额外拆1层架势；冷却3回合'),
    })
    rules['tactical_rules']=dict(counter_reduction=.65,frost_reduction=.2,break_damage_bonus=.25,status_turns=2,phase_grace=True,mp_recovery_ratio=.12,heal_ratio=.18)
    write('战斗与刷新配置.json',rules)
    tasks=read('任务配置.json')
    def migrate(v):
        if isinstance(v,dict):return {k:migrate(x) for k,x in v.items()}
        if isinstance(v,list):return [migrate(x) for x in v]
        if isinstance(v,str):return v.replace('monster_defeated/gate_entity','monster_defeated/gou_ga_boss').replace('门扉之影','勾尬').replace('击败门扉','制止勾尬，守住门扉')
        return v
    write('任务配置.json',migrate(tasks))
    root=Path('C:/Users/李科奇/.codex/generated_images/01a119fe-4fad-75e1-9efd-2badd4b2ddcd')
    ids={'gou_ga_boss':('exec-0bbffbb9-b7a0-48bc-8556-d8df5aa75d87.png',4), 'book_eater_queen':('exec-fd36d411-45b2-4483-bf17-6cff5e7a3f9c.png',3),'dry_branch_ancient':('exec-bd14a8b2-c937-40df-b747-84f8816d9936.png',3),'empty_uniform_leader':('exec-723f478f-8a7d-47e6-91c0-d98d21b8e4e2.png',3)}
    asset_root=ROOT/'资源/原项目/assets/characters/bosses'
    art_report=[]
    for id,(filename,columns) in ids.items():
        folder=asset_root/id;folder.mkdir(parents=True,exist_ok=True)
        raw=Image.open(root/filename).convert('RGBA')
        # Only deterministic grid slicing/downsampling/packing of generated
        # artwork; no painted edits or synthesized substitute poses.
        w,h=raw.size; cw,ch=w//columns,h//2
        atlas=Image.new('RGBA',(columns*256,2*320))
        for i in range(columns*2):
            crop=raw.crop(((i%columns)*cw,(i//columns)*ch,(i%columns+1)*cw,(i//columns+1)*ch))
            crop.thumbnail((256,320),Image.Resampling.LANCZOS)
            atlas.alpha_composite(crop,((i%columns)*256+(256-crop.width)//2,(i//columns)*320+320-crop.height))
        atlas.save(folder/'atlas.png',optimize=True)
        portrait=atlas.crop((0,0,256,320));portrait.save(folder/'portrait.png',optimize=True)
        world=Image.new('RGBA',(256,320));world.alpha_composite(portrait)
        # Existing monster portrait() uses 2x2 source sheets.
        world_sheet=Image.new('RGBA',(512,640))
        for x,y in [(0,0),(256,0),(0,320),(256,320)]:world_sheet.alpha_composite(world,(x,y))
        world_sheet.save(folder/'world.png',optimize=True)
        manifest=dict(columns=columns,rows=2,cell=[256,320],poses={'idle':[0,1],'windup':[2],'attack':[3 if columns==3 else 3],'hit':[4 if columns==3 else 5],'guard':[0 if columns==3 else 4],'phase':[0 if columns==3 else 6],'defeat':[5 if columns==3 else 7]},fps=6)
        write(f'资源/原项目/assets/characters/bosses/{id}/motion.json',manifest)
        art_report.append(dict(id=id,atlas=str((folder/'atlas.png').relative_to(ROOT)),frames=columns*2,rgba_bytes=atlas.width*atlas.height*4,source=str(root/filename)))
    write('runtime/boss_art_manifest.json',art_report)
    print(json.dumps(dict(events=len(SCENES),dialogue_lines=sum(len(lines(a))+len(lines(b)) for a,b in SCENES.values()),bosses=len(ids),new_skills=4),ensure_ascii=False))

if __name__=='__main__':main()
