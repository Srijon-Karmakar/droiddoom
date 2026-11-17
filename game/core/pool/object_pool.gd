class_name ObjectPool
extends RefCounted
## Fixed-size node pool (TDD §6.3: no instancing during combat). All nodes are
## created up front by `factory` and parented to `parent`. `acquire()` hands out
## a free node, or recycles the oldest active one when the pool is exhausted
## (a dropped spark is better than a frame hitch). Pooled nodes may implement
## `on_acquire()` and `on_release()` to show/hide or reset themselves.

var _free: Array[Node] = []
var _active: Array[Node] = []


func _init(factory: Callable, size: int, parent: Node) -> void:
	for i in size:
		var node: Node = factory.call()
		parent.add_child(node)
		if node.has_method(&"on_release"):
			node.call(&"on_release")
		_free.append(node)


## Returns a node to use. Recycles the oldest active node if none are free.
func acquire() -> Node:
	var node: Node
	if _free.is_empty():
		node = _active.pop_front()
		if node.has_method(&"on_release"):
			node.call(&"on_release")
	else:
		node = _free.pop_back()
	_active.append(node)
	if node.has_method(&"on_acquire"):
		node.call(&"on_acquire")
	return node


## Gives a node back. Ignored if it isn't active (double release is safe).
func release(node: Node) -> void:
	var index: int = _active.find(node)
	if index == -1:
		return
	_active.remove_at(index)
	if node.has_method(&"on_release"):
		node.call(&"on_release")
	_free.append(node)


func get_size() -> int:
	return _free.size() + _active.size()


func get_active_count() -> int:
	return _active.size()


func get_free_count() -> int:
	return _free.size()
