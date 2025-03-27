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
var command_time:float = 1.0/30.0;
var timer:float = 0;
var redundant_inputs = 5;
var sv_input_queue:Array = [];
var is_auth: bool;
var action_was_pressed = false;
var last_sent_input = 0;
class InputStruct:
	var input_flags: int = 0
	var input_tick: int = 0
	var look_angles: Vector2 = Vector2.ZERO;
	func encode() ->Dictionary:
		return {0:input_tick,1:input_flags,2:look_angles}
	func decode(dict:Dictionary):
		input_tick = dict[0]
		input_flags = dict[1]
		look_angles = dict[2]

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("fire"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.x += (-event.relative.y*0.001)
		camera.rotation.y += (-event.relative.x*0.001)
		
func _ready() -> void:
	change_authority()
	if multiplayer.is_server():
		pass;
	input_hist.resize(input_hist_size)
	

func change_authority():
	is_auth = get_multiplayer_authority() == multiplayer.get_unique_id();
		
	set_process(is_auth)
	set_process_input(is_auth)

func _process(delta: float) -> void:
	timer+=delta;
	var i = 0;
	while timer >= command_time:
		apply_inputs();
		var inputstruct = InputStruct.new();
		inputstruct.input_flags = net_input_flags
		inputstruct.input_tick = client_tick
		inputstruct.look_angles = Vector2(camera.rotation.x,camera.rotation.y)
		input_hist[client_tick%input_hist_size] = inputstruct;
		#if !multiplayer.is_server():
			#print("SEND " + str(InputStruct.encode()))
		if multiplayer.is_server():
			send_inputs([inputstruct.encode()])
		else:
			var input_array: Array
			for j in range(-redundant_inputs+1,1):
				var client_input = input_hist[(client_tick+j)%input_hist_size];
				if client_input:
					input_array.append(client_input.encode())
			last_sent_input = client_tick;
			send_inputs.rpc_id(1,input_array)
		client_tick += 1;
		timer -= command_time
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
	for client_input in input_list:
		var recv = InputStruct.new()
		recv.decode(client_input)
		net_input_flags = recv.input_flags;
		net_look_angles = recv.look_angles;
		sv_input_queue.append(recv);
