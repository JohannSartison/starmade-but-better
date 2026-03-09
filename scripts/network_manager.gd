## NetworkManager – Autoload
## Verwaltet Multiplayer-Verbindungen (ENet, autoritativer Host-Modus).
extends Node

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 64

signal server_started
signal server_stopped
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal joined_server
signal left_server
signal connection_failed

var is_server: bool = false
var is_client: bool = false

# -----------------------------------------------------------------------
# Host / Join / Leave
# -----------------------------------------------------------------------

func host(port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("NetworkManager: Server konnte nicht gestartet werden (Fehler %d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_client = false
	_connect_signals()
	server_started.emit()
	print("NetworkManager: Server gestartet auf Port %d" % port)

func join(address: String, port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: Verbindung fehlgeschlagen (Fehler %d)" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_server = false
	is_client = true
	_connect_signals()
	print("NetworkManager: Verbinde mit %s:%d ..." % [address, port])

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_server = false
	is_client = false
	left_server.emit()
	print("NetworkManager: Verbindung getrennt.")

# -----------------------------------------------------------------------
# Hilfsfunktionen
# -----------------------------------------------------------------------

func get_own_id() -> int:
	return multiplayer.get_unique_id()

func is_connected_to_server() -> bool:
	return is_client and multiplayer.multiplayer_peer != null

func is_hosting() -> bool:
	return is_server

# -----------------------------------------------------------------------
# Intern
# -----------------------------------------------------------------------

func _connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer verbunden: %d" % id)
	client_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer getrennt: %d" % id)
	client_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("NetworkManager: Mit Server verbunden.")
	joined_server.emit()

func _on_connection_failed() -> void:
	push_warning("NetworkManager: Verbindung fehlgeschlagen.")
	is_client = false
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	push_warning("NetworkManager: Server-Verbindung verloren.")
	is_client = false
	multiplayer.multiplayer_peer = null
	left_server.emit()
