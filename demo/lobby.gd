extends Control

@onready var btn_create_server: Button = get_node("%BtnCreateServer")
@onready var btn_create_client: Button = get_node("%BtnCreateClient")
@onready var line_edit_address: LineEdit = get_node("%LineEditAddress")
@onready var progress_bar_upnp: ProgressBar = get_node("%ProgressBarUPnP")
@onready var container_server_connection: Container = get_node("%ContainerServerConnection")
@onready var player_list: ItemList = get_node("%PlayerList")


func _ready() -> void:
  await_upnp()
  line_edit_address.text = ENetMultiplayerService.server_ip
  btn_create_server.pressed.connect(_on_btn_create_server_pressed)
  btn_create_client.pressed.connect(_on_btn_create_client_pressed)
  ENetMultiplayerService.client_list_changed.connect(_on_player_list_changed)
  ENetMultiplayerService.client_connected.connect(_on_client_connected_to_server)


func await_upnp() -> void:
  if ENetMultiplayerService.use_upnp:
    ENetMultiplayerService.upnp_setup_completed.connect(_on_upnp_setup_completed)
    ENetMultiplayerService.upnp_setup_failed.connect(_on_upnp_setup_failed)
    line_edit_address.editable = false
    progress_bar_upnp.visible = true
    btn_create_server.disabled = true
    btn_create_client.disabled = true
  else:
    progress_bar_upnp.visible = false


func _refresh_player_list() -> void:
  var players := ENetMultiplayerService.client_list
  players.values().sort()
  print(players)
  player_list.clear()
  player_list.add_item("%d (you)" % multiplayer.get_unique_id())
  for key: int in players:
    player_list.add_item(str(players[key]))

func _show_player_list() -> void:
  player_list.visible = true
  container_server_connection.visible = false


#region Signal Callbacks
func _on_btn_create_server_pressed() -> void:
  var result := ENetMultiplayerService.create_server()
  if result == OK:
    _show_player_list()


func _on_btn_create_client_pressed() -> void:
  var result := ENetMultiplayerService.create_client(line_edit_address.text)
  if result == OK:
    _show_player_list()


func _on_upnp_setup_completed(ip: String) -> void:
  line_edit_address.editable = true
  line_edit_address.text = ip
  progress_bar_upnp.visible = false
  btn_create_client.disabled = false
  btn_create_server.disabled = false


func _on_upnp_setup_failed() -> void:
  line_edit_address.editable = true
  progress_bar_upnp.visible = false
  btn_create_client.disabled = false
  btn_create_server.disabled = false

func _on_client_connected_to_server(client_id: int) -> void:
  print("%d connected" % client_id)


func _on_player_list_changed() -> void:
  _refresh_player_list()
#endregion
