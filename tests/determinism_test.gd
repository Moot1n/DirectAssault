extends Node3D
@export var p1: PlayerDet
@export var p2: PlayerDet
const MOVE_FORWARD = 1 << 1;
const MOVE_LEFT = 1 << 2;
const MOVE_RIGHT = 1 << 3;
const MOVE_BACK = 1 << 4;
const JUMP = 1 << 5;
const FIRE = 1 << 6;
var timer:float = 0.0;
var command_time:float = 1.0/30.0
var net_input_flags = 0;
@onready var camera: Camera3D = $Camera3D

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
		
func _process(delta: float) -> void:
	timer+=delta;
	var i = 0;
	while timer >= command_time:
		apply_inputs();
		
		var inputstruct = InputStruct.new();
		inputstruct.input_flags = net_input_flags
		inputstruct.input_tick = 0
		inputstruct.look_angles = Vector2(camera.rotation.x,camera.rotation.y)
		
		p1.simulate_input(command_time,inputstruct)
		p2.simulate_input(command_time,inputstruct)
		timer-=command_time;

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
