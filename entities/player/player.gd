extends CharacterBody3D
class_name Player
@onready var input: playerInputs = $Input
var accel = 40;
@export var player_id: int = -1;
var last_recieved_input = 0;
@onready var entity_node: EntityNode = $EntityNode
var _process_delta;
var timer = 0;
var jumping = false;
var physics_delta: float:
	get:
		if Engine.is_in_physics_frame():
			return 1.0/Engine.physics_ticks_per_second
		else:
			return _process_delta
func _ready() -> void:
	input.set_multiplayer_authority(player_id)
	input.change_authority()
	if input.is_auth:
		$Camera3D.current = true;
		if !multiplayer.is_server():
			entity_node.reconcile.connect(reconciliate)
			Performance.add_custom_monitor("game/interp_time", entity_node.get_interp_time)
			Performance.add_custom_monitor("game/error", entity_node.get_error)
	#set_physics_process(multiplayer.is_server())
	

func _process(delta: float) -> void:
	_process_delta = delta;
	
	if !multiplayer.is_server(): return;
	timer+=delta;
	while timer >= entity_node.snapshot_time:
		
		entity_node.send()
		timer -= entity_node.snapshot_time
		
	if !input.sv_input_queue.is_empty():
		for encoded_input in input.sv_input_queue:
			#FIXME: THIS METHOD APPLIES IN WRONG ORDER!!!
			var client_input = input.InputStruct.new()
			client_input.decode_delta(encoded_input,input.sv_dummy_input_dict)
			
			input.net_input_flags = client_input.input_flags;
			input.net_look_angles = client_input.look_angles;
			if client_input.input_tick > last_recieved_input:
				if client_input.input_tick -last_recieved_input >1:
					print("SERVER: MISSED")
				input.sv_dummy_input_dict = client_input.encode()
				
				last_recieved_input = client_input.input_tick;
				#if player_id != 1:
					#print(input.sv_dummy_input_dict)
					#print("SERVER SIMULATING  " + str(input.sv_dummy_input_dict))
				simulate_input(input.server_tick_time,client_input)
		input.sv_input_queue.clear()

func reconciliate():
	if !multiplayer.is_server():
		var last_recvd =  input.input_hist[last_recieved_input%input.input_hist_size];
		if last_recvd:
			input.cl_dummy_input_dict = input.input_hist[last_recieved_input%input.input_hist_size].encode()
		var last = -1;
		for i in range(last_recieved_input, input.last_sent_input):
			var client_input = input.input_hist[i%input.input_hist_size]
			if client_input:
				
				if client_input.input_tick > last_recieved_input:
					#if client_input.input_tick-last !=1 && last!=-1:
						#print("WARN!!!!")
						#print("SIMMING %d" % [client_input.input_tick])
						#print("LAST %d" % [last])
					last = client_input.input_tick;
					#print("SIMMING %d" % [client_input.input_tick])
					#print("last tick rcv %d last tick sent %d " %[last_recieved_input, input.client_tick])
					#print("rtt %f " %[(input.client_tick-last_recieved_input)*input.command_time])
					simulate_input(input.server_tick_time, client_input)

func _physics_process(delta: float) -> void:
	if !multiplayer.is_server(): return;
	#entity_node.send()

func simulate_input(delta: float, client_input):
	var input_flags = client_input.input_flags
	var look_angles:Vector2 = client_input.look_angles
	var movement = Vector3.ZERO;
	#velocity = Vector3.ZERO
	
	#velocity.y = 0;
	#if (input_flags & JUMP):
	#	velocity.y = 5;

	#else:
	
	#velocity.y-=20*delta;
	
	#var input_flags = input_struct.input_flags;
	movement.x = int(bool(input_flags & input.MOVE_RIGHT)) \
	- int(bool(input_flags & input.MOVE_LEFT)) 
	movement.z = int(bool(input_flags & input.MOVE_BACK)) \
	- int(bool(input_flags & input.MOVE_FORWARD)) 
	#velocity = velocity.rotated(Vector3(0,1,0),look_angles.y)
	var wishdir = -Vector3.FORWARD.rotated(Vector3.UP, look_angles.y)
	var current_dir = velocity/6;
	wishdir = wishdir*movement.z
	
	velocity += (wishdir-current_dir)*accel*delta;
	
	#velocity = velocity.rotated(Vector3(0,1,0),look_angles.y)
	velocity = velocity*(delta/_process_delta)
	#global_position += velocity*delta;
	#move_and_collide(velocity*delta)
	move_and_slide()
	velocity = velocity*(_process_delta/delta)
