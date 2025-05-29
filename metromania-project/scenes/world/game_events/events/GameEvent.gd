class_name GameEvent extends Node3D

@export var triggers : Array[GameTrigger]

func _ready() -> void:
	if triggers.size() < 1:
		push_warning(name, " has no triggers")
	for triggering_event : GameTrigger in triggers:
		triggering_event.event_triggered.connect(activate)
	extensible_ready()

func extensible_ready():
	# Implemented by sub-classes.
	pass

func activate() -> void:
	# Implemented by sub-classes.
	pass


func first_activation() -> void:
	# Implemented by sub-classes.
	pass
