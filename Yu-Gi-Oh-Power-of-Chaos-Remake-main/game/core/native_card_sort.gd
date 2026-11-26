extends RefCounted
## 4471b0 -> CRT5860f0/586080: comparacion sin desempate añadido.
static func sort_records(items: Array, key: Callable, first := 0, last := -1) -> void:
	if last < 0: last = items.size() - 1
	if last <= first: return
	var count := last - first + 1
	var keys := PackedInt64Array()
	keys.resize(count)
	for i in count:
		keys[i] = int(key.call(items[first + i]))
	var lo := first
	var hi := last
	var stack: Array[Vector2i] = []
	while true:
		if hi - lo + 1 <= 8:
			while hi > lo:
				var largest := lo
				for i in range(lo + 1, hi + 1):
					if keys[i - first] > keys[largest - first]: largest = i
				_swap_with_keys(items, keys, first, largest, hi)
				hi -= 1
		else:
			var mid := lo + ((hi - lo + 1) >> 1)
			if keys[lo - first] > keys[mid - first]: _swap_with_keys(items, keys, first, lo, mid)
			if keys[lo - first] > keys[hi - first]: _swap_with_keys(items, keys, first, lo, hi)
			if keys[mid - first] > keys[hi - first]: _swap_with_keys(items, keys, first, mid, hi)
			var left := lo
			var right := hi
			while true:
				var pivot: int = keys[mid - first]
				if left < mid:
					left += 1
					while left < mid and keys[left - first] <= pivot: left += 1
					if left >= mid:
						left += 1
						while left <= hi and keys[left - first] <= pivot: left += 1
				else:
					left += 1
					while left <= hi and keys[left - first] <= pivot: left += 1
				right -= 1
				while right > mid and keys[right - first] > pivot: right -= 1
				if left > right: break
				_swap_with_keys(items, keys, first, left, right)
				if mid == right: mid = left
			var mid_key: int = keys[mid - first]
			right += 1
			if mid < right:
				right -= 1
				while right > mid and keys[right - first] == mid_key: right -= 1
				if right <= mid:
					right -= 1
					while right > lo and keys[right - first] == mid_key: right -= 1
			else:
				right -= 1
				while right > lo and keys[right - first] == mid_key: right -= 1
			if right - lo >= hi - left:
				if lo < right: stack.append(Vector2i(lo, right))
				lo = left
			else:
				if left < hi: stack.append(Vector2i(left, hi))
				hi = right
			if lo < hi: continue
		if stack.is_empty(): return
		var pending: Vector2i = stack.pop_back()
		lo = pending.x
		hi = pending.y

static func _swap(items: Array, a: int, b: int) -> void:
	if a == b: return
	var temporary: Variant = items[a]
	items[a] = items[b]
	items[b] = temporary

static func _swap_with_keys(items: Array, keys: PackedInt64Array, first: int, a: int, b: int) -> void:
	if a == b: return
	var temporary: Variant = items[a]
	items[a] = items[b]
	items[b] = temporary
	var ka: int = keys[a - first]
	keys[a - first] = keys[b - first]
	keys[b - first] = ka

## Joey CRT5c3ee9: pivote central intercambiado con primero, sin mediana de tres.
static func sort_joey(items: Array, key: Callable, first := 0, last := -1) -> void:
	if last < 0: last = items.size() - 1
	if last <= first: return
	var count := last - first + 1
	var keys := PackedInt64Array()
	keys.resize(count)
	for i in count:
		keys[i] = int(key.call(items[first + i]))
	var stack: Array[Vector2i] = [Vector2i(first, last)]
	while not stack.is_empty():
		var bounds: Vector2i = stack.pop_back()
		var lo := bounds.x
		var hi := bounds.y
		if hi - lo + 1 <= 8:
			while hi > lo:
				var largest := lo
				for i in range(lo + 1, hi + 1):
					if keys[i - first] > keys[largest - first]: largest = i
				_swap_with_keys(items, keys, first, largest, hi)
				hi -= 1
			continue
		_swap_with_keys(items, keys, first, lo + ((hi - lo + 1) >> 1), lo)
		var pivot: int = keys[lo - first]
		var left := lo
		var right := hi + 1
		while true:
			left += 1
			while left <= hi and keys[left - first] <= pivot: left += 1
			right -= 1
			while right > lo and keys[right - first] >= pivot: right -= 1
			if left > right: break
			_swap_with_keys(items, keys, first, left, right)
		_swap_with_keys(items, keys, first, lo, right)
		if lo + 1 < right: stack.append(Vector2i(lo, right - 1))
		if left < hi: stack.append(Vector2i(left, hi))
