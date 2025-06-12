extends Node

signal entered_level(entrance_number : int)

signal startedaiming(current_body : Node3D)
signal stoppedaiming(current_body : Node3D)

signal child_picked_up
signal child_captured
signal child_released

signal start_grapple(_position : Vector3)
signal end_retracting()

signal took_damage(amount : float, knockback : float)
signal jumped
signal landed
signal dashed
signal accelerated_to_full_speed
signal braked
signal grabbed_ledge
signal wall_jumped
signal grabbed_hook
signal yeeted_child 

###cam_signals
signal cam_attach
signal cam_shake(duration: float)
signal cam_tilt(duration: float)
signal cam_fast_zooms(duration: float)
signal cam_slomo(duration: float)
signal cam_pan(direction: float, duration: float)
