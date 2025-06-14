@tool

extends Node3D

@export var play_VFX: bool = false:
	set(value):
		for child in get_children():
			if child is CPUParticles3D:
				child.emitting = true;
				
@export var VFX_SpeedScale: float = 1.0:
	set(value):
		VFX_SpeedScale = value;
		for child in get_children():
			if child is CPUParticles3D:
				child.speed_scale = value
