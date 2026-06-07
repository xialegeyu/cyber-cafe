extends Node2D

const SCENE_SIZE := Vector2(1448, 1086)
const CONTENT_OFFSET := Vector2(0, 110)
const BACKGROUND_PATH := "res://assets/cafe/front-cafe-scene-v3.png"
const TABLE_PATH := "res://assets/cafe/front-table-chair-v1.png"
const FOCUS_NOISE_PATH := "res://assets/audio/low-focus-noise.wav"
const WINDOW_RAIN_PATH := "res://assets/audio/window-rain.wav"
const ROOM_API_PATH := "/.netlify/functions/room"
const JSON_HEADERS := ["Content-Type: application/json"]
const NAME_TAG_OFFSET := Vector2(50, -28)
const MUSIC_VOLUME_DB := 12.0

const CATS := {
	"calico": {
		"label": "Calico cat",
		"texture": "res://assets/cafe/calico-cat-laptop-top-left-cutout-clean-v2.png",
		"hframes": 1,
		"vframes": 1,
		"frame": 0,
		"scale": Vector2(0.24, 0.24),
		"position": Vector2(72, 18),
	},
	"ragdoll": {
		"label": "Ragdoll cat",
		"texture": "res://assets/cafe/ragdoll-cat-laptop-cutout-v2.png",
		"hframes": 1,
		"vframes": 1,
		"frame": 0,
		"scale": Vector2(0.10, 0.10),
		"position": Vector2(76, 16),
	},
	"tabby": {
		"label": "Tabby cat",
		"texture": "res://assets/cafe/tabby-cat-laptop-cutout-v2.png",
		"hframes": 1,
		"vframes": 1,
		"frame": 0,
		"scale": Vector2(0.10, 0.10),
		"position": Vector2(76, 16),
	},
	"orange": {
		"label": "Orange cat",
		"texture": "res://assets/cafe/orange-cat-laptop-cutout-v2.png",
		"hframes": 1,
		"vframes": 1,
		"frame": 0,
		"scale": Vector2(0.10, 0.10),
		"position": Vector2(76, 16),
	},
}

const SEATS := [
	{"id": "table_1", "label": "Table 1", "position": Vector2(110, 500)},
	{"id": "table_2", "label": "Table 2", "position": Vector2(375, 500)},
	{"id": "table_3", "label": "Table 3", "position": Vector2(640, 500)},
	{"id": "table_4", "label": "Table 4", "position": Vector2(905, 500)},
]

@onready var cafe_background: Sprite2D = $CafeBackground
@onready var seats_root: Node2D = $Seats
@onready var seat_hotspots: Node2D = $SeatHotspots
@onready var ui_layer: CanvasLayer = $UI
@onready var top_bar: Panel = $UI/TopBar
@onready var title_label: Label = $UI/TopBar/TitleLabel
@onready var name_input: LineEdit = $UI/TopBar/NameInput
@onready var cat_selector: OptionButton = $UI/TopBar/CatSelector
@onready var music_selector: OptionButton = $UI/TopBar/MusicSelector
@onready var music_toggle: CheckButton = $UI/TopBar/MusicToggle
@onready var online_label: Label = $UI/TopBar/OnlineLabel
@onready var share_button: Button = $UI/TopBar/ShareButton
@onready var hint_label: Label = $UI/TopBar/HintLabel
@onready var seat_label: Label = $UI/SeatLabel
@onready var name_tag: Label = $UI/NameTag
@onready var debug_label: Label = $UI/DebugLabel
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var active_seat_id := ""
var hovered_seat_id := ""
var selected_cat_id := "calico"
var seat_by_id := {}
var seat_nodes := {}
var occupants := {}
var room_id := "local-dev"
var client_id := ""
var room_api_url := ""
var sync_enabled := false
var poll_request: HTTPRequest
var post_request: HTTPRequest
var poll_timer: Timer
var heartbeat_timer: Timer

func _ready() -> void:
	cafe_background.texture = load(BACKGROUND_PATH)
	cafe_background.position = CONTENT_OFFSET
	cafe_background.z_index = 0
	seats_root.position = CONTENT_OFFSET
	seat_hotspots.position = CONTENT_OFFSET
	music_player.volume_db = MUSIC_VOLUME_DB

	_style_ui()
	_populate_controls()
	_create_seats()
	_connect_ui()
	_setup_room_sync()
	_update_music()
	_update_room_status()
	_update_debug_label()

func _style_ui() -> void:
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.13, 0.08, 0.055, 0.96)
	bar_style.border_color = Color(0.43, 0.25, 0.15, 1.0)
	bar_style.set_border_width_all(2)
	bar_style.set_corner_radius_all(16)
	top_bar.add_theme_stylebox_override("panel", bar_style)

	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.56))
	title_label.add_theme_font_size_override("font_size", 24)
	online_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.76))
	hint_label.add_theme_color_override("font_color", Color(0.86, 0.70, 0.50))
	seat_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	name_tag.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))

func _populate_controls() -> void:
	for cat_id in CATS.keys():
		cat_selector.add_item(CATS[cat_id]["label"])
		cat_selector.set_item_metadata(cat_selector.item_count - 1, cat_id)
	cat_selector.select(0)

	music_selector.add_item("Focus noise")
	music_selector.set_item_metadata(0, FOCUS_NOISE_PATH)
	music_selector.add_item("Window rain")
	music_selector.set_item_metadata(1, WINDOW_RAIN_PATH)
	music_selector.select(0)

func _connect_ui() -> void:
	cat_selector.item_selected.connect(_on_cat_selected)
	music_selector.item_selected.connect(_on_music_selected)
	music_toggle.toggled.connect(_on_music_toggled)
	name_input.text_changed.connect(_on_name_changed)
	share_button.pressed.connect(_on_share_pressed)

func _create_seats() -> void:
	var table_texture := load(TABLE_PATH)

	for seat in SEATS:
		seat_by_id[seat["id"]] = seat

		var seat_root := Node2D.new()
		seat_root.name = "%sRoot" % seat["id"].capitalize()
		seat_root.position = seat["position"]
		seats_root.add_child(seat_root)

		var table := Sprite2D.new()
		table.name = "TableChair"
		table.texture = table_texture
		table.centered = false
		table.z_index = 10
		seat_root.add_child(table)

		var cat := Sprite2D.new()
		cat.name = "Cat"
		cat.centered = false
		cat.z_index = 20
		cat.visible = false
		seat_root.add_child(cat)

		var tag := Label.new()
		tag.name = "%sNameTag" % seat["id"].capitalize()
		tag.visible = false
		tag.size = Vector2(160, 28)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
		tag.add_theme_font_size_override("font_size", 18)
		ui_layer.add_child(tag)

		seat_nodes[seat["id"]] = {"root": seat_root, "table": table, "cat": cat, "tag": tag}

		var area := Area2D.new()
		area.name = "%sHotspot" % seat["id"].capitalize()
		area.position = seat["position"] + Vector2(120, 135)
		area.input_pickable = true
		area.mouse_entered.connect(_on_seat_mouse_entered.bind(seat["id"]))
		area.mouse_exited.connect(_on_seat_mouse_exited.bind(seat["id"]))
		area.input_event.connect(_on_seat_input_event.bind(seat["id"]))

		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(240, 273)
		shape.shape = rectangle
		area.add_child(shape)
		seat_hotspots.add_child(area)

func _on_cat_selected(index: int) -> void:
	selected_cat_id = cat_selector.get_item_metadata(index)
	if active_seat_id != "":
		_post_seat_update(active_seat_id, "sit")
	_update_debug_label()

func _on_name_changed(_new_text: String) -> void:
	if active_seat_id != "":
		_post_seat_update(active_seat_id, "sit")
	else:
		_render_occupants()
	_update_debug_label()

func _on_music_selected(_index: int) -> void:
	_update_music()

func _on_music_toggled(_pressed: bool) -> void:
	_update_music()

func _on_share_pressed() -> void:
	if OS.has_feature("web"):
		var copied_url = JavaScriptBridge.eval("""
			(function () {
				const url = new URL(window.location.href);
				if (!url.searchParams.get("room")) url.searchParams.set("room", "default");
				history.replaceState(null, "", url.toString());
				if (navigator.clipboard) navigator.clipboard.writeText(url.toString());
				return url.toString();
			})()
		""", true)
		hint_label.text = "Room link copied. Friends will see occupied tables in this shared room."
		debug_label.text = "Shared URL: %s" % str(copied_url)
	else:
		hint_label.text = "Export to Web and deploy on Netlify to share a live room link."
	_update_debug_label()

func _on_seat_mouse_entered(seat_id: String) -> void:
	hovered_seat_id = seat_id
	_show_seat_label(seat_id)
	_update_debug_label()

func _on_seat_mouse_exited(seat_id: String) -> void:
	if hovered_seat_id == seat_id:
		hovered_seat_id = ""
	seat_label.visible = false
	_update_debug_label()

func _on_seat_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, seat_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_sit_at(seat_id)

func _sit_at(seat_id: String) -> void:
	if _is_seat_taken_by_other(seat_id):
		_show_seat_label(seat_id)
		hint_label.text = "%s is already occupied. Pick another table." % seat_by_id[seat_id]["label"]
		_update_debug_label()
		return

	if sync_enabled:
		_post_seat_update(seat_id, "sit")
	else:
		active_seat_id = seat_id
		occupants.clear()
		occupants[seat_id] = _local_occupant(seat_id)
		_render_occupants()

	_show_seat_label(seat_id)
	_update_room_status()
	_update_debug_label()

func _apply_cat_style(cat: Sprite2D, cat_id: String) -> void:
	var safe_cat_id := cat_id if CATS.has(cat_id) else "calico"
	var cat_config = CATS[safe_cat_id]
	cat.texture = load(cat_config["texture"])
	cat.hframes = cat_config["hframes"]
	cat.vframes = cat_config["vframes"]
	cat.frame = cat_config["frame"]
	cat.scale = cat_config["scale"]
	cat.position = cat_config["position"]

func _show_seat_label(seat_id: String) -> void:
	var seat = seat_by_id[seat_id]
	seat_label.text = _seat_label_text(seat_id)
	seat_label.position = CONTENT_OFFSET + seat["position"] + Vector2(0, -36)
	seat_label.visible = true

func _seat_label_text(seat_id: String) -> String:
	if occupants.has(seat_id):
		var occupant = occupants[seat_id]
		if occupant.get("client_id", "") == client_id:
			return "%s · occupied by you" % seat_by_id[seat_id]["label"]
		return "%s · occupied by %s" % [seat_by_id[seat_id]["label"], occupant.get("name", "another cat")]
	if active_seat_id == seat_id:
		return "%s · occupied by you" % seat_by_id[seat_id]["label"]
	return "%s · open, click to sit" % seat_by_id[seat_id]["label"]

func _render_occupants() -> void:
	name_tag.visible = false

	for id in seat_nodes.keys():
		var cat: Sprite2D = seat_nodes[id]["cat"]
		var tag: Label = seat_nodes[id]["tag"]
		cat.visible = false
		tag.visible = false

	for seat_id in occupants.keys():
		if not seat_nodes.has(seat_id):
			continue

		var occupant = occupants[seat_id]
		var cat: Sprite2D = seat_nodes[seat_id]["cat"]
		var tag: Label = seat_nodes[seat_id]["tag"]
		var seat = seat_by_id[seat_id]
		_apply_cat_style(cat, occupant.get("cat_id", "calico"))
		cat.visible = true
		tag.text = occupant.get("name", "Guest cat")
		tag.position = CONTENT_OFFSET + seat["position"] + NAME_TAG_OFFSET
		tag.visible = true

func _update_room_status() -> void:
	var open_seats := SEATS.size() - occupants.size()
	var online_count := occupants.size()
	if active_seat_id == "" or not _has_self_occupant():
		online_count += 1
	online_count = max(1, online_count)
	online_label.text = "%s online · %s open seats" % [online_count, open_seats]

func _update_music() -> void:
	if not music_toggle.button_pressed:
		music_player.stop()
		_update_debug_label()
		return

	var selected_index := music_selector.selected
	if selected_index < 0:
		selected_index = 0
		music_selector.select(0)

	var stream_path: String = music_selector.get_item_metadata(selected_index)
	var stream = load(stream_path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if music_player.stream != stream:
		music_player.stream = stream
	music_player.volume_db = MUSIC_VOLUME_DB
	music_player.play()
	_update_debug_label()

func _update_debug_label() -> void:
	debug_label.text = "Cat: %s | Name: %s | Hover: %s | Seated: %s | Music: %s" % [
		selected_cat_id,
		name_input.text.strip_edges(),
		hovered_seat_id if hovered_seat_id != "" else "none",
		active_seat_id if active_seat_id != "" else "none",
		"playing" if music_player.playing else "off",
	]

func _setup_room_sync() -> void:
	client_id = _resolve_client_id()
	room_id = _resolve_room_id()
	room_api_url = _resolve_room_api_url()

	if room_api_url == "":
		sync_enabled = false
		hint_label.text = "Local preview: deploy on Netlify to sync occupied tables with friends."
		return

	sync_enabled = true

	poll_request = HTTPRequest.new()
	poll_request.request_completed.connect(_on_poll_completed)
	add_child(poll_request)

	post_request = HTTPRequest.new()
	post_request.request_completed.connect(_on_post_completed)
	add_child(post_request)

	poll_timer = Timer.new()
	poll_timer.wait_time = 3.0
	poll_timer.timeout.connect(_poll_room)
	poll_timer.autostart = true
	add_child(poll_timer)

	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = 20.0
	heartbeat_timer.timeout.connect(_send_heartbeat)
	heartbeat_timer.autostart = true
	add_child(heartbeat_timer)

	_poll_room()

func _resolve_client_id() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("""
			(function () {
				let id = localStorage.getItem("nekoCafeClientId");
				if (!id) {
					id = "cat-" + (crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2));
					localStorage.setItem("nekoCafeClientId", id);
				}
				return id;
			})()
		""", true))
	return "local-%s" % Time.get_unix_time_from_system()

func _resolve_room_id() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("""
			(function () {
				const url = new URL(window.location.href);
				let room = url.searchParams.get("room");
				if (!room) {
					room = "room-" + Math.random().toString(36).slice(2, 10);
					url.searchParams.set("room", room);
					history.replaceState(null, "", url.toString());
				}
				return room;
			})()
		""", true)).replace(" ", "-")
	return "local-dev"

func _resolve_room_api_url() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.origin", true)) + ROOM_API_PATH
	return ""

func _poll_room() -> void:
	if not sync_enabled or poll_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	poll_request.request("%s?room=%s" % [room_api_url, room_id])

func _post_seat_update(seat_id: String, action: String) -> void:
	if not sync_enabled:
		active_seat_id = seat_id
		occupants.clear()
		occupants[seat_id] = _local_occupant(seat_id)
		_render_occupants()
		_update_room_status()
		return

	if post_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var body := JSON.stringify({
		"action": action,
		"client_id": client_id,
		"seat_id": seat_id,
		"cat_id": selected_cat_id,
		"name": _current_name(),
	})
	post_request.request("%s?room=%s" % [room_api_url, room_id], JSON_HEADERS, HTTPClient.METHOD_POST, body)

func _send_heartbeat() -> void:
	if active_seat_id != "":
		_post_seat_update(active_seat_id, "heartbeat")

func _on_poll_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code >= 200 and response_code < 300:
		_apply_room_state(body)

func _on_post_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 409:
		hint_label.text = "That table was just taken. Pick another open table."
	if response_code >= 200 and response_code < 500:
		_apply_room_state(body)

func _apply_room_state(body: PackedByteArray) -> void:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var remote_occupants = parsed.get("occupants", {})
	occupants.clear()
	active_seat_id = ""

	for seat_id in remote_occupants.keys():
		if not seat_by_id.has(seat_id):
			continue
		var occupant = remote_occupants[seat_id]
		occupants[seat_id] = occupant
		if occupant.get("client_id", "") == client_id:
			active_seat_id = seat_id

	_render_occupants()
	_update_room_status()
	if hovered_seat_id != "":
		_show_seat_label(hovered_seat_id)
	_update_debug_label()

func _local_occupant(seat_id: String) -> Dictionary:
	return {
		"client_id": client_id,
		"seat_id": seat_id,
		"cat_id": selected_cat_id,
		"name": _current_name(),
	}

func _current_name() -> String:
	var nickname := name_input.text.strip_edges()
	return nickname if nickname != "" else "Guest cat"

func _has_self_occupant() -> bool:
	for occupant in occupants.values():
		if occupant.get("client_id", "") == client_id:
			return true
	return false

func _is_seat_taken_by_other(seat_id: String) -> bool:
	if not occupants.has(seat_id):
		return false
	return occupants[seat_id].get("client_id", "") != client_id
