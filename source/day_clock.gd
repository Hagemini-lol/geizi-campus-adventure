extends RefCounted

signal period_advanced(previous: int, current: int)

const PERIODS: Array[Dictionary]=[
	{"name":"凌晨","outdoor":Color(.56,.64,.78),"indoor":Color(.82,.86,.94)},
	{"name":"上午","outdoor":Color(1,1,1),"indoor":Color(1,1,1)},
	{"name":"下午","outdoor":Color(1,.95,.85),"indoor":Color(1,.98,.94)},
	{"name":"晚上","outdoor":Color(.55,.56,.70),"indoor":Color(.88,.88,.95)},
	{"name":"深夜","outdoor":Color(.30,.37,.55),"indoor":Color(.77,.81,.91)}
]
var current_period:=1

func period_index() -> int:
	return current_period

func next_period() -> void:
	var previous:=current_period
	current_period=(current_period+1)%PERIODS.size()
	period_advanced.emit(previous,current_period)

func display_text() -> String:
	return str(PERIODS[current_period]["name"])

func tint(indoors: bool) -> Color:
	return PERIODS[period_index()]["indoor" if indoors else "outdoor"]
