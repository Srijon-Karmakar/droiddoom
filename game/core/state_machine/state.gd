class_name State
extends RefCounted
## One state of a StateMachine. Override what you need. States are plain
## objects (not nodes), so dozens of enemies stay cheap, and the owner decides
## how often to tick (AI LOD, P1-08).

## The machine running this state. Set by `StateMachine.add()`.
var machine: StateMachine
## The actor the machine belongs to.
var actor: Node


func enter(_previous: StringName) -> void:
	pass


func exit(_next: StringName) -> void:
	pass


## Called by `StateMachine.update()` at the owner's AI tick rate.
func update(_delta: float) -> void:
	pass
