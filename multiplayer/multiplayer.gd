extends Node

const IP_ADDRESS = "localhost"
const PORT = 7000
const MAX_CLIENTS = 4
var is_server = false;
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create client.
	var args = Array(OS.get_cmdline_args())
	if args.has("-server"):
		# Create server.
		is_server = true;
		var peer = ENetMultiplayerPeer.new()
		peer.create_server(PORT, MAX_CLIENTS)
		multiplayer.multiplayer_peer = peer
	else:
		var peer = ENetMultiplayerPeer.new()
		peer.create_client(IP_ADDRESS, PORT)
		multiplayer.multiplayer_peer = peer
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var status = multiplayer.multiplayer_peer.get_connection_status()
	pass
