extends Node2D

const SCENE_SIZE := Vector2(1448, 1086)
const CONTENT_OFFSET := Vector2(0, 110)
const BACKGROUND_PATH := "res://assets/cafe/front-cafe-scene-v3.png"
const TABLE_PATH := "res://assets/cafe/front-table-chair-v1.png"
const WHITE_NOISE_PATH := "res://assets/audio/white_noise.wav"
const RAIN_PATH := "res://assets/audio/rain.wav"

const CATS := {
	"orange": {
		"label": "Orange cat",
		"texture": "res://assets/Neko Cafe Asset Pack/Characters/cat-orange-front.png",
	},
	"black": {
		"label": "Black cat",
		"texture": "res://assets/Neko Cafe Asset Pack/Characters/cat-black-front.png",
	},
	"waiter": {
		"label": "Waiter cat",
		"texture": "res://assets/Neko Cafe Asset Pack/Characters/cat-waiter-front.png",
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
var selected_cat_id := "orange"
var seat_by_id := {}
var seat_nodes := {}

func _ready() -> void:
	cafe_background.texture = load(BACKGROUND_PATH)
	cafe_background.position = CONTENT_OFFSET
	cafe_background.z_index = 0
	seats_root.position = CONTENT_OFFSET
	seat_hotspots.position = CONTENT_OFFSET
	music_player.volume_db = 4.0

	_populate_controls()
	_create_seats()
	_connect_ui()
	_update_music()
	_update_room_status()
	_update_debug_label()

func _populate_controls() -> void:
	for cat_id in CATS.keys():
		cat_selector.add_item(CATS[cat_id]["label"])
		cat_selector.set_item_metadata(cat_selector.item_count - 1, cat_id)
	cat_selector.select(0)

	music_selector.add_item("White noise")
	music_selector.set_item_metadata(0, WHITE_NOISE_PATH)
	music_selector.add_item("Rain")
	music_selector.set_item_metadata(1, RAIN_PATH)
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
		cat.hframes = 4
		cat.vframes = 2
		cat.frame = 0
		cat.scale = Vector2(4.6, 4.6)
		cat.position = Vector2(86, 28)
		cat.z_index = 20
		cat.visible = false
		seat_root.add_child(cat)

		seat_nodes[seat["id"]] = {"root": seat_root, "table": table, "cat": cat}

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
		_sit_at(active_seat_id)
	_update_debug_label()

func _on_name_changed(_new_text: String) -> void:
	_update_name_tag()
	_update_debug_label()

func _on_music_selected(_index: int) -> void:
	_update_music()

func _on_music_toggled(_pressed: bool) -> void:
	_update_music()

func _on_share_pressed() -> void:
	hint_label.text = "Share this room link after Web export; friends can join, pick an open table, and study with you."
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
	active_seat_id = seat_id

	for id in seat_nodes.keys():
		var cat: Sprite2D = seat_nodes[id]["cat"]
		cat.visible = id == seat_id
		if id == seat_id:
			cat.texture = load(CATS[selected_cat_id]["texture"])

	_update_name_tag()
	_show_seat_label(seat_id)
	_update_room_status()
	_update_debug_label()

func _show_seat_label(seat_id: String) -> void:
	var seat = seat_by_id[seat_id]
	seat_label.text = _seat_label_text(seat_id)
	seat_label.position = CONTENT_OFFSET + seat["position"] + Vector2(0, -36)
	seat_label.visible = true

func _seat_label_text(seat_id: String) -> String:
	if active_seat_id == seat_id:
		return "%s · occupied by you" % seat_by_id[seat_id]["label"]
	return "%s · open, click to sit" % seat_by_id[seat_id]["label"]

func _update_name_tag() -> void:
	if active_seat_id == "":
		name_tag.visible = false
		return

	var seat = seat_by_id[active_seat_id]
	var nickname := name_input.text.strip_edges()
	name_tag.text = nickname if nickname != "" else "Guest cat"
	name_tag.position = CONTENT_OFFSET + seat["position"] + Vector2(50, 22)
	name_tag.visible = true

func _update_room_status() -> void:
	var open_seats := SEATS.size() - (1 if active_seat_id != "" else 0)
	var online_count := 1 if active_seat_id == "" else 2
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
	music_player.volume_db = 4.0
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
