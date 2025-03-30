extends Node
class_name playerInputs
@export var camera: Camera3D
var net_input_flags: int = 0;
var net_look_angles: Vector2 = Vector2.ZERO;
const MOVE_FORWARD = 1 << 1;
const MOVE_LEFT = 1 << 2;
const MOVE_RIGHT = 1 << 3;
const MOVE_BACK = 1 << 4;
const JUMP = 1 << 5;
const FIRE = 1 << 6;
var input_hist: Array;
var input_hist_size = 100;
var client_tick:int = 0;
var command_time:float = 1.0/30;
#var server_tick_time = 1.0/Engine.physics_ticks_per_second
var server_tick_time = 1.0/60;
var cmd_timer:float = 0;
var tick_timer:float = 0;
var redundant_inputs = 4;
var sv_input_queue:Array = [];
var is_auth: bool;
var action_was_pressed = false;
var last_sent_input = 0;
var cl_dummy_input_dict: Dictionary;
var sv_dummy_input_dict: Dictionary;
var inputs_last_sent: Dictionary;
class InputStruct:
	var input_flags: int = 0
	var input_tick: int = 0
	var look_angles: Vector2 = Vector2.ZERO;
	static func generate_dummy() ->Dictionary:
		return {0:0,1:0,2:Vector2.ZERO}
	func encode() ->Dictionary:
		return {0:input_tick,1:input_flags,2:look_angles}
	func encode_delta(dummy_input_dict:Dictionary) -> Dictionary:
		var output_dict:Dictionary = {}
		var encoded_dict = encode()
		for key in encoded_dict:
			if encoded_dict[key]!=dummy_input_dict[key]:
				output_dict.set(key, encoded_dict[key])
		return output_dict;
	func encode_input_tick():
		return {0:input_tick}
	func decode(dict:Dictionary):
		input_tick = dict[0]
		input_flags = dict[1]
		look_angles = dict[2]
	func decode_delta(dict:Dictionary, dummy_input_dict:Dictionary):
		var output:Dictionary = dummy_input_dict.duplicate()
		for key in dict:
			output[key] = dict[key]
		input_tick = output[0]
		input_flags = output[1]
		look_angles = output[2]

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("fire"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.x += (-event.relative.y*0.001)
		camera.rotation.y += (-event.relative.x*0.001)
		
func _ready() -> void:
	change_authority()
	cl_dummy_input_dict = InputStruct.generate_dummy()
	sv_dummy_input_dict = InputStruct.generate_dummy()
	inputs_last_sent = InputStruct.generate_dummy()
	if multiplayer.is_server():
		pass;
	input_hist.resize(input_hist_size)
	

func change_authority():
	is_auth = get_multiplayer_authority() == multiplayer.get_unique_id();
		
	set_process(is_auth)
	set_process_input(is_auth)

func _process(delta: float) -> void:
	
	tick_timer+=delta;
	var i = 0;
	while tick_timer >= server_tick_time:
		cmd_timer+=server_tick_time;
		var inputstruct = InputStruct.new();
		inputstruct.decode(inputs_last_sent)
		if cmd_timer >= command_time:
			# Send a command
			apply_inputs();
			inputstruct.input_flags = net_input_flags
			inputstruct.look_angles = Vector2(camera.rotation.x,camera.rotation.y)
			cmd_timer =0;
		
		inputstruct.input_tick = client_tick
		input_hist[client_tick%input_hist_size] = inputstruct;
		if multiplayer.is_server():
			
			send_inputs([inputstruct.encode_delta(inputs_last_sent)])
			inputs_last_sent = inputstruct.encode()
		else:
			var input_array: Array
			for j in range(-redundant_inputs+1,1):
				
				var client_input = input_hist[(client_tick+j)%input_hist_size];
				
				if client_input:
					input_array.append(client_input.encode_delta(inputs_last_sent))
				if j == 0:
					inputs_last_sent = client_input.encode()
			
			last_sent_input = client_tick;
			#if input_array[0].has(1):
			#	print("SENDING " + str(inputstruct.encode()))
			send_inputs.rpc_id(1,input_array)
		client_tick += 1;
		tick_timer-=server_tick_time;
	#print(timer)
		
		
func apply_inputs():
	net_input_flags = 0;
	if Input.is_action_pressed("fire"):
		net_input_flags = net_input_flags | FIRE;
	if Input.is_action_pressed("jump"):
		net_input_flags = net_input_flags | JUMP;
	if Input.is_action_pressed("move_left"):
		net_input_flags = net_input_flags | MOVE_LEFT;
		
	if Input.is_action_pressed("move_right"):
		net_input_flags = net_input_flags | MOVE_RIGHT;
	if Input.is_action_pressed("move_forward"):
		net_input_flags = net_input_flags | MOVE_FORWARD;

	if Input.is_action_pressed("move_back"):
		net_input_flags = net_input_flags | MOVE_BACK;
	
@rpc("authority","call_remote","unreliable")
func send_inputs(input_list:Array):
	var sender_id = multiplayer.get_remote_sender_id()
	for client_input in input_list:
		sv_input_queue.append(client_input);
@rpc("authority","call_remote","unreliable")
func test_rpc_input_tick(input_list:Array):
	var recv = InputStruct.new()
