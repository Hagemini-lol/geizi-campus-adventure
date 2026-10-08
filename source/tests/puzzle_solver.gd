extends RefCounted
static func actions(spec: Dictionary,current: Array=[]) -> Array[String]:
	var values: Array=(spec["initial"] if current.is_empty() else current).duplicate()
	var result: Array[String]=[]
	if spec["kind"]=="dials":
		for i: int in range(values.size()):
			while int(values[i])!=int(spec["target"][i]):
				values[i]=(int(values[i])+1)%spec["tokens"][i].size();result.append("move"+str(i))
	elif spec["kind"]=="sequence":
		for target_index: int in range(values.size()):
			var at: int=-1
			for i: int in range(values.size()):
				if int(values[i])==int(spec["target"][target_index]):at=i;break
			while at>target_index:
				var n: Variant=values[at-1];values[at-1]=values[at];values[at]=n
				result.append("move"+str(at-1));at-=1
	else:
		for mask: int in range(1<<spec["links"].size()):
			var attempt: Array=values.duplicate();var moves: Array[String]=[]
			for i: int in range(spec["links"].size()):
				if mask&(1<<i):
					moves.append("move"+str(i))
					for n: Variant in spec["links"][i]:attempt[int(n)]=1-int(attempt[int(n)])
			if preload("res://puzzle_board.gd").same_values(attempt,spec["target"]):result=moves;break
	result.append("submit");return result
