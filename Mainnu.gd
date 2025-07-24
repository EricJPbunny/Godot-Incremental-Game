extends Node2D

# ===== CONSTANTS =====
# Resource management
const DEFAULT_EFFORT_INCOME_PER_SECOND = 0.0
const DEFAULT_EFFORT_PRESS_STRENGTH_BASE = 1
const DEFAULT_EFFORT_PRESS_MULTIPLIER = 1.0
const DEFAULT_EFFORT_PRESS_BONUS = 0
const DEFAULT_AUTO_INTERVAL = 0.2  # Seconds between autoclick ticks

# Manpower settings
const DEFAULT_MANPOWER_STRENGTH = 1

# Game state
const DEFAULT_TOTAL_CLICKS = 0
const DEFAULT_AUTOCLICK_ENABLED = false
const DEFAULT_CURRENT_AGE = "Stone Age"

# Resource defaults
const DEFAULT_RESOURCES = {
	"effort": 29000,
	"manpower": 100,
	"think": 2000,
	"materials": 2000,
}

# File paths
const UI_CONFIG_PATH = "res://config/ui_config.json"

# ===== AGE PALETTES =====
const AGE_PALETTES = {
	"Stone Age": {
		"background": Color(0.85, 0.72, 0.55),
		"resource_text": Color(0.2, 0.2, 0.2),
		"work_button": Color("#C68642"),
		"tech_tree_window": Color(0.8, 0.8, 0.7, 0.4),
		"click_sound": "res://sounds/stone_click.wav"
	},
	"Bronze Age": {
		"background": Color(0.8, 0.6, 0.3),
		"resource_text": Color(0.3, 0.2, 0.1),
		"work_button": Color("#CD7F32"),
		"tech_tree_window": Color(0.9, 0.8, 0.6, 0.4),
		"click_sound": "res://sounds/bronze_click.wav"
	},
	"Iron Age": {
		"background": Color(0.7, 0.7, 0.7),
		"resource_text": Color(0.1, 0.1, 0.1),
		"work_button": Color("#888888"),
		"tech_tree_window": Color(0.7, 0.7, 0.8, 0.4),
		"click_sound": "res://sounds/iron_click.wav"
	}
}

# ===== APPLY AGE PALETTE =====
func apply_age_palette(age: String):
	if not AGE_PALETTES.has(age):
		print("[PALETTE] No palette for age:", age)
		return
	var palette = AGE_PALETTES[age]
	# Background
	var bg = get_node_or_null("ColorRect")
	if not bg:
		for child in get_children():
			if child is ColorRect:
				bg = child
				break
	if bg:
		bg.color = palette["background"]
	# Resource labels
	for label in resource_labels.values():
		if label:
			label.add_theme_color_override("default_color", palette["resource_text"])
	# Work button
	var work_button = get_node_or_null("ButtonWork")
	if work_button:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = palette["work_button"]
		var new_theme = Theme.new()
		new_theme.set_stylebox("normal", "Button", stylebox)
		new_theme.set_stylebox("hover", "Button", stylebox)
		new_theme.set_stylebox("pressed", "Button", stylebox)
		work_button.theme = new_theme
	# Tech tree window background (ColorRect)
	var tech_tree_bg = get_node_or_null("TechTreePanel/TechTreeBG")
	if tech_tree_bg:
		tech_tree_bg.color = palette["tech_tree_window"]
	# Update click sound for this age
	if ui_click_player and palette.has("click_sound"):
		ui_click_player.stream = load(palette["click_sound"])

# ===== VARIABLES =====
var shop: Shop
var tech_tree: TechTree
var auto_timer: Timer

var resources = DEFAULT_RESOURCES.duplicate()

var total_clicks := DEFAULT_TOTAL_CLICKS
var effort_income_per_second := DEFAULT_EFFORT_INCOME_PER_SECOND
var effort_press_strength_base := DEFAULT_EFFORT_PRESS_STRENGTH_BASE
var effort_press_multiplier := DEFAULT_EFFORT_PRESS_MULTIPLIER
var effort_press_bonus := DEFAULT_EFFORT_PRESS_BONUS
var auto_interval := DEFAULT_AUTO_INTERVAL

var manpower_strength = DEFAULT_MANPOWER_STRENGTH
var fire_unlocked = false
var active_configs = []
var autoclick_enabled := DEFAULT_AUTOCLICK_ENABLED
var current_age := DEFAULT_CURRENT_AGE

var shop_configs = {}
var ui_config = {}
var resource_labels = {}

# ===== UI SOUND MANAGER =====
var ui_click_player: AudioStreamPlayer
var ui_hover_player: AudioStreamPlayer

func setup_ui_sound_manager():
	ui_click_player = AudioStreamPlayer.new()
	ui_click_player.stream = preload("res://sounds/stone_click.wav") 
	add_child(ui_click_player)
	ui_hover_player = AudioStreamPlayer.new()
	ui_hover_player.stream = preload("res://sounds/button_hover.wav") 
	add_child(ui_hover_player)

func play_ui_click():
	if ui_click_player:
		ui_click_player.stop()
		ui_click_player.play()

func play_ui_hover():
	if ui_hover_player:
		ui_hover_player.stop()
		ui_hover_player.play()

func update_age(new_age: String):
	if not new_age or new_age.is_empty():
		print("ERROR: Invalid age provided to update_age: ", new_age)
		return
		
	active_configs.clear()

	if shop_configs.has(new_age):
		# Don't re-fetch base config; reuse current ones in shop.button_dict
		if shop and shop.current_age != new_age:
			shop.clear_buttons() # Clear old buttons only on actual age change

		var age_configs = shop_configs[new_age]
		if age_configs is Dictionary:
			for key in age_configs.keys():
				var config = age_configs[key]
				if config is Dictionary:
					# Add all buttons to active_configs - let the shop handle tech locking
					active_configs.append(config)
				else:
					print("WARNING: Invalid config format for key: ", key)
		else:
			print("WARNING: age_configs is not a dictionary for age: ", new_age)

		# Only call update_buttons if the age has changed or new unlocks appeared
		if shop:
			shop.update_buttons(active_configs)
	else:
		print("WARNING: No shop configs found for age: ", new_age)

func advance_to_next_age(new_age: String):
	if not new_age or new_age.is_empty():
		print("ERROR: Invalid age provided to advance_to_next_age: ", new_age)
		return
		
	print("Advancing to:", new_age)
	current_age = new_age
	apply_age_palette(new_age)
	if shop:
		shop.transition_to_age(new_age)  # Tell Shop to clear previous buttons
	update_age(new_age)

func update_all_labels() -> void:
	for key in resources.keys():
		if key == "effort":
			var effort_str = "%.2f" % effort_income_per_second
			resource_labels[key].text = "[b]" + key.capitalize() + ":[/b] " + str(resources[key]) + " (+" + effort_str + "/s)"
		else:
			resource_labels[key].text = "[b]" + key.capitalize() + ":[/b] " + str(resources[key])
		# Dynamically adjust height to fit content
		resource_labels[key].size.y = resource_labels[key].get_content_height()
	# Finally, update total clicks label
	resource_labels["total_clicks"].text = "[b]Total Clicks:[/b] " + str(total_clicks)
	resource_labels["total_clicks"].size.y = resource_labels["total_clicks"].get_content_height()

func _on_auto_timer_timeout() -> void:
	if resources["manpower"] > 0:
		resources["effort"] += manpower_strength * resources["manpower"]

func get_current_click_power() -> int:
	return int((effort_press_strength_base + effort_press_bonus) * effort_press_multiplier)

func check_unlocks():
	if shop_configs.has(current_age):
		var age_configs = shop_configs[current_age]
		for key in age_configs.keys():
			var config = age_configs[key]
			if config.has("unlock_key") and config.has("unlock_amount"):
				var unlock_key = config["unlock_key"]
				var unlock_amount = config["unlock_amount"]
				# Add to active configs if resource conditions are met
				if config not in active_configs and resources[unlock_key] >= unlock_amount:
					active_configs.append(config)
			else:
				if config not in active_configs:
					active_configs.append(config)
		shop.update_buttons(active_configs)

func load_ui_config():
	var file = FileAccess.open(UI_CONFIG_PATH, FileAccess.READ)
	if not file:
		print("ERROR: Could not open config file at: ", UI_CONFIG_PATH)
		print("Make sure the file exists and is accessible.")
		# Set default config to prevent crashes
		ui_config = get_default_ui_config()
		return
	
	var data = file.get_as_text()
	file.close()
	
	if data.is_empty():
		print("ERROR: Config file is empty: ", UI_CONFIG_PATH)
		ui_config = get_default_ui_config()
		return
	
	var json = JSON.parse_string(data)
	if json == null:
		print("ERROR: Failed to parse JSON from config file: ", UI_CONFIG_PATH)
		print("Please check the JSON syntax.")
		ui_config = get_default_ui_config()
		return
	
	ui_config = sanitize_json_numbers(json)
	print("UI config loaded successfully!")

	if ui_config.has("shop_configs"):
		shop_configs = ui_config["shop_configs"]
	else:
		print("WARNING: shop_configs not found in ui_config! Using empty config.")
		shop_configs = {}

func get_default_ui_config() -> Dictionary:
	print("Using default UI configuration due to config loading failure.")
	return {
		"global_ui": {
			"start_x": 50,
			"start_y": 100,
			"button_spacing_x": 40,
			"button_spacing_y": 0
		},
		"resource_labels_ui": {
			"start_x": 50,
			"start_y": 50,
			"spacing_x": 200,
			"spacing_y": 0
		},
		"shop_configs": {},
		"tech_tree_configs": [],
		"work_button": {}
	}

func sanitize_json_numbers(data):
	if typeof(data) == TYPE_DICTIONARY:
		for key in data.keys():
			data[key] = sanitize_json_numbers(data[key])
		return data
	elif typeof(data) == TYPE_ARRAY:
		for i in range(data.size()):
			data[i] = sanitize_json_numbers(data[i])
		return data
	elif typeof(data) == TYPE_FLOAT:
		if int(data) == data:
			return int(data)
		else:
			return data
	else:
		return data

func setup_shop_and_tech_tree():
	if not ui_config:
		print("ERROR: UI config not loaded, cannot setup shop and tech tree!")
		return
	
	shop = Shop.new(self)
	if not shop:
		print("ERROR: Failed to create Shop instance!")
		return
	add_child(shop)
	
	tech_tree = TechTree.new(self)
	if not tech_tree:
		print("ERROR: Failed to create TechTree instance!")
		return
	add_child(tech_tree)

	if ui_config.has("tech_tree_configs"):
		var tech_configs = ui_config["tech_tree_configs"]
		if tech_configs is Array:
			tech_tree.update_tech_buttons(tech_configs)
		else:
			print("WARNING: tech_tree_configs is not an array, skipping tech tree setup.")
	else:
		print("INFO: No tech_tree_configs found in UI config.")

	update_age("Stone Age")
	if shop:
		shop.update_buttons(active_configs)  # Force sync after tech buttons exist

func setup_background():
	var bg = ColorRect.new()
	bg.color = Color(0.85, 0.72, 0.55)
	bg.size = get_viewport_rect().size
	add_child(bg)
	move_child(bg, 0)

func setup_timers():
	auto_timer = Timer.new()
	auto_timer.wait_time = auto_interval
	auto_timer.one_shot = false
	auto_timer.autostart = false
	auto_timer.stop()
	print("On ready, is timer stopped? ", auto_timer.is_stopped())
	add_child(auto_timer)
	auto_timer.timeout.connect(_on_auto_timer_timeout)

func setup_work_button():
	if not ui_config:
		print("ERROR: UI config not loaded, cannot setup work button!")
		return
	
	var work_button = get_node_or_null("ButtonWork")
	if not work_button:
		print("ERROR: ButtonWork node not found in scene!")
		return
	
	var work_button_config = ui_config.get("work_button", {})
	if work_button.has_method("setup_from_config"):
		work_button.setup_from_config(work_button_config)
	else:
		print("ERROR: ButtonWork does not have setup_from_config method!")

func setup_resource_labels():
	if not ui_config:
		print("ERROR: UI config not loaded, cannot setup resource labels!")
		return
	
	var label_start_x = 50
	var label_start_y = 50
	var label_spacing_x = 200
	var label_spacing_y = 0

	if ui_config.has("resource_labels_ui"):
		var label_conf = ui_config["resource_labels_ui"]
		if label_conf is Dictionary:
			label_start_x = label_conf.get("start_x", 50)
			label_start_y = label_conf.get("start_y", 50)
			label_spacing_x = label_conf.get("spacing_x", 200)
			label_spacing_y = label_conf.get("spacing_y", 0)
		else:
			print("WARNING: resource_labels_ui is not a dictionary, using defaults.")

	var i = 0
	for key in resources:
		var label = RichTextLabel.new()
		if not label:
			print("ERROR: Failed to create RichTextLabel for resource: ", key)
			continue
			
		label.bbcode_enabled = true
		label.autowrap_mode = true
		label.text = "[b]" + key.capitalize() + ":[/b] 0"
		label.size = Vector2(180, 30)
		label.position = Vector2(label_start_x + i * label_spacing_x, label_start_y + i * label_spacing_y)

		add_child(label)
		resource_labels[key] = label
		i += 1
	
	var click_label = RichTextLabel.new()
	if click_label:
		click_label.bbcode_enabled = true
		click_label.text = "[b]Total Clicks:[/b] 0"
		click_label.size = Vector2(250, 30)
		click_label.position = Vector2(label_start_x, label_start_y + 50 + i * label_spacing_y + 40)
		add_child(click_label)
		resource_labels["total_clicks"] = click_label
	else:
		print("ERROR: Failed to create Total Clicks label!")

# ===== BRING UI TO FRONT =====
func bring_ui_to_front(node: Node):
	if node and node.get_parent():
		node.get_parent().move_child(node, node.get_parent().get_child_count() - 1)

func _ready() -> void:
	load_ui_config()
	setup_shop_and_tech_tree()
	setup_background()
	setup_timers()
	setup_work_button()
	setup_resource_labels()
	setup_ui_sound_manager()

	# Tech tree panel and toggle logic
	var tech_tree_panel = get_node_or_null("TechTreePanel")
	var tech_tree_toggle = get_node_or_null("TechTreeToggle")
	if tech_tree_panel and tech_tree_toggle:
		# Position panel at right side, vertically centered
		var screen_size = get_viewport_rect().size
		tech_tree_panel.size = Vector2(600, 400)
		tech_tree_panel.position = Vector2(screen_size.x - tech_tree_panel.size.x - 40, (screen_size.y - tech_tree_panel.size.y) / 2)
		tech_tree_toggle.position = Vector2(0, (screen_size.y - tech_tree_toggle.size.y) / 2)
		tech_tree_toggle.pressed.connect(func():
			tech_tree_panel.visible = not tech_tree_panel.visible
			if tech_tree_panel.visible:
				bring_ui_to_front(tech_tree_panel)
			if tech_tree:
				if ui_config.has("tech_tree_configs"):
					tech_tree.update_tech_buttons(ui_config["tech_tree_configs"])
				tech_tree.set_tree_visible(tech_tree_panel.visible)
		)

func _process(delta: float) -> void:
	effort_income_per_second = float(manpower_strength * resources["manpower"] * (1.0/auto_interval))
	update_all_labels()
	check_unlocks()  # Check for new unlocks when resources change
