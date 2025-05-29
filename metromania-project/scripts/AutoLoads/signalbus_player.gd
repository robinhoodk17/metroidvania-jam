extends Node


signal startedaiming(current_body : Node3D)
signal stoppedaiming(current_body : Node3D)
signal child_picked_up
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
