@tool
class_name VFXElement
extends Node3D

@export var VFX_Playing: bool = false:
	get:
		for child in get_children():
			if child is CPUParticles3D:
				return child.emitting
		return false;
	set(value):
		Set_VFX_Emitting(value)
				
@export var VFX_SpeedScale: float = 1.0:
	set(value):
		VFX_SpeedScale = value;
		for child in get_children():
			if child is CPUParticles3D:
				child.speed_scale = value

func Set_VFX_Emitting(value: bool):
	for child in get_children():
		if child is CPUParticles3D:
			child.emitting = value;
