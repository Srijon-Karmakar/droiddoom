extends GutTest
## P1-07: ObjectPool hands out, takes back and recycles pre-made nodes.


class Pooled:
	extends Node
	var acquired: int = 0
	var released: int = 0

	func on_acquire() -> void:
		acquired += 1

	func on_release() -> void:
		released += 1


var _parent: Node
var _pool: ObjectPool


func before_each() -> void:
	_parent = Node.new()
	add_child_autofree(_parent)
	_pool = ObjectPool.new(func() -> Node: return Pooled.new(), 3, _parent)


func test_creates_all_nodes_up_front() -> void:
	assert_eq(_parent.get_child_count(), 3)
	assert_eq(_pool.get_free_count(), 3)
	assert_eq(_pool.get_active_count(), 0)


func test_acquire_and_release_cycle() -> void:
	var node: Pooled = _pool.acquire()
	assert_eq(node.acquired, 1)
	assert_eq(_pool.get_active_count(), 1)
	_pool.release(node)
	assert_eq(_pool.get_free_count(), 3)
	_pool.release(node)
	assert_eq(_pool.get_free_count(), 3, "double release is ignored")


func test_exhausted_pool_recycles_oldest() -> void:
	var first: Pooled = _pool.acquire()
	_pool.acquire()
	_pool.acquire()
	var fourth: Pooled = _pool.acquire()
	assert_eq(fourth, first, "oldest active node is reused")
	assert_eq(_pool.get_size(), 3, "never grows")
	assert_eq(_parent.get_child_count(), 3)
