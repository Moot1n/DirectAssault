extends Node
class_name EntityNode
@export var root_node: Node
@export var replicate_properties: Array[String]
var sv_server_tick:int = 0;

var property_to_id:Dictionary
var id_to_property:Dictionary
var data_table_hist:Array
var data_table_tick:Array[int]
var state_lerp_from:Dictionary;
var state_lerp_to: Dictionary;
var tick_lerp_from:int
var tick_lerp_to:int

var last_server_tick:int = 0
var interp_current_tick:int = 0
var snapshot_buffer_ticks = 4;
var snapshot_time:float = 1.0/30
var snapshot_time_adjust:float = 1*snapshot_time
var interp_tick_time = snapshot_time;
var interp_time = 0;
var tickrate = 0;
var time_scale = 1.0;
var error = 0
signal reconcile
func _ready() -> void:
	tickrate = Engine.physics_ticks_per_second
	for pid in range(len(replicate_properties)):
		property_to_id.set(replicate_properties[pid],pid)
		id_to_property.set(pid, replicate_properties[pid])
	set_process(!multiplayer.is_server())
	set_physics_process(!multiplayer.is_server())
		
func get_interp_time() -> float:
	return time_scale*10000;
func get_error():
	return error;

func _process(delta: float) -> void:
	#var popped_property_table = data_table_hist.pop_front()
	#var popped_pt_tick = data_table_tick.pop_front()
	#if popped_property_table:
		#set_properties(popped_property_table)
	
	interp_time+=delta*time_scale;
	
	while interp_time >= interp_tick_time:
		interp_time -= interp_tick_time;
		#interp_time = delta;

		if len(data_table_hist) >= snapshot_buffer_ticks+40000:
			data_table_hist.resize(snapshot_buffer_ticks);
			data_table_tick.resize(snapshot_buffer_ticks)
		# Too far behind speed up interp or too far ahead slow down
		
		#interp_tick_time-=snapshot_time_adjust;
		#print(len(data_table_hist))
		#if len(data_table_hist) < 1: print(len(data_table_hist))
		var popped_property_table = data_table_hist.pop_front()
		var popped_pt_tick = data_table_tick.pop_front()
		if popped_property_table:
			if !state_lerp_to:
				state_lerp_to = make_data_table()
				tick_lerp_to = 0
			state_lerp_from = state_lerp_to
			tick_lerp_from = tick_lerp_to
			set_properties(popped_property_table)
			state_lerp_to = make_data_table()
			tick_lerp_to = popped_pt_tick;
			interp_current_tick+=1;
				#var interp_distance = min(tick_lerp_to-tick_lerp_from,3);
				#interp_tick_time*interp_distance
				#break;
	error = (len(data_table_hist)-snapshot_buffer_ticks);
	var target_time_scale = 1+error*0.005;
	if time_scale >  target_time_scale:
		time_scale -= 0.0001
		if time_scale < target_time_scale:
			time_scale = target_time_scale
	elif time_scale < target_time_scale:
		time_scale += 0.0001
		if time_scale > target_time_scale:
			time_scale = target_time_scale
	#time_scale = 1+error*0.001	
	#print(time_scale)
	if root_node.input.is_auth:
		$"../Control".update_graph(interp_time/interp_tick_time)
	if interp_time/interp_tick_time >= 0 && interp_time/interp_tick_time <= 1:
		lerp_set_properties(state_lerp_from, state_lerp_to, interp_time/interp_tick_time)
	else:
		print("OUT!")
			
func make_data_table() -> Dictionary:
	var data_table: Dictionary;
	for property in replicate_properties:
		var pid = property_to_id[property]
		data_table.set(pid, root_node.get(property))
	return data_table;
	
func send():
	if multiplayer.is_server():
		send_data_table.rpc(make_data_table(),sv_server_tick)
		sv_server_tick += 1;
	
@rpc("authority","call_remote","unreliable")
func send_data_table(encdoded_properties: Dictionary, server_tick:int):
	#Last server tick was too far ahead of interpolation tick
	if server_tick > last_server_tick:
		
		data_table_hist.push_back(encdoded_properties);
		data_table_tick.push_back(server_tick);
		last_server_tick = server_tick

func set_properties(encoded_properties: Dictionary):
	for pid in encoded_properties:
		var property:String = id_to_property[pid];
		if property == "position":
			var oldpos:Vector3 = root_node.get(property)
			var newpos = encoded_properties[pid];
		root_node.set(property, encoded_properties[pid])
	reconcile.emit()

func lerp_set_properties(from: Dictionary, to: Dictionary, time: float):
	for pid in from:
		var property:String = id_to_property[pid];
		var dont_lerp = true;
		var value_from = from[pid];
		if value_from is Vector3:
			if to.has(pid):
				dont_lerp = false;
				root_node.set(property, value_from.lerp(to[pid], time))
		if dont_lerp:
			root_node.set(property, from[pid])
