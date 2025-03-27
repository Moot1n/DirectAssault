extends CharacterBody3D
class_name PlayerDet
const MOVE_FORWARD = 1 << 1;
const MOVE_LEFT = 1 << 2;
const MOVE_RIGHT = 1 << 3;
const MOVE_BACK = 1 << 4;
const JUMP = 1 << 5;
const FIRE = 1 << 6;
var accel = 40;
var _process_delta = 0;
var physics_delta: float:
	get:
		if Engine.is_in_physics_frame():
			return 1.0/Engine.physics_ticks_per_second
		else:
			return _process_delta
func _process(delta: float) -> void:
	_process_delta = delta;
func simulate_input(delta: float, client_input):
	var input_flags = client_input.input_flags
	var look_angles:Vector2 = client_input.look_angles
	var movement = Vector3.ZERO;
	
	#velocity.y = 0;
	#if (input_flags & JUMP):
	#	velocity.y = 5;

	#else:
	
	#velocity.y-=20*delta;
	
	#var input_flags = input_struct.input_flags;
	movement.x = int(bool(input_flags & MOVE_RIGHT)) \
	- int(bool(input_flags & MOVE_LEFT)) 
	movement.z = int(bool(input_flags & MOVE_BACK)) \
	- int(bool(input_flags & MOVE_FORWARD)) 
	#velocity = velocity.rotated(Vector3(0,1,0),look_angles.y)
	var wishdir = -Vector3.FORWARD.rotated(Vector3.UP, look_angles.y)
	var current_dir = velocity/4;
	wishdir = wishdir*movement.z
	
	velocity += (wishdir-current_dir)*accel*delta;
	
	#velocity = velocity.rotated(Vector3(0,1,0),look_angles.y)
	#velocity = velocity*(delta/_process_delta)
	#global_position += velocity*delta;
	move_and_collide(velocity*delta)
	#velocity = velocity*(_process_delta/delta)
