extends RefCounted

signal period_advanced(previous: int, current: int)

const PERIODS: Array[Dictionary]=[
	{"name":"凌晨","outdoor":Color(.56,.64,.78),"indoor":Color(.82,.86,.94)},
	{"name":"上午","outdoor":Color(1,1,1),"indoor":Color(1,1,1)},
	{"name":"下午","outdoor":Color(1,.95,.85),"indoor":Color(1,.98,.94)},
	{"name":"晚上","outdoor":Color(.55,.56,.70),"indoor":Color(.88,.88,.95)},
	{"name":"深夜","outdoor":Color(.30,.37,.55),"indoor":Color(.77,.81,.91)},
	{"name":"午休","outdoor":Color(1,.99,.94),"indoor":Color(1,1,.98)}
]
# Preserve the first five persisted IDs; chronology is independent of storage.
const ORDER: Array[int]=[0,1,5,2,3,4]
var current_period:=1

func period_index() -> int:
	return current_period

func next_period() -> void:
	var previous:=current_period
	current_period=next_index()
	period_advanced.emit(previous,current_period)

func next_index() -> int:
	return ORDER[(ORDER.find(current_period)+1)%ORDER.size()]

func slot(day: int) -> int:
	return day*ORDER.size()+ORDER.find(current_period)

static func migrate_slot(value: int, cycle: int) -> int:
	if value<0 or cycle==6:return value
	return floori(float(value)/5)*6+ORDER.find(value%5)

func display_text() -> String:
	return str(PERIODS[current_period]["name"])

func tint(indoors: bool) -> Color:
	return PERIODS[period_index()]["indoor" if indoors else "outdoor"]
