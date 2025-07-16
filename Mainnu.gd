extends Node2D

var shop: Shop
var auto_timer: Timer

var resources = {
	"effort": 150,
	"manpower": 0,
	"think": 0,
	"materials": 0,
}

var total_clicks := 0
var effort_income_per_second := 0.0
var effort_press_strength_base := 1
var effort_press_multiplier := 1.0
var effort_press_bonus := 0
var auto_interval := 0.2  # The value that can later be updated by upgrades

var manpower_strength = 1
var fire_unlocked = false
var active_configs = []
var autoclick_enabled := false
var current_age := "Stone Age"

var shop_configs = {}
var ui_config = {}
var resource_labels = {}

func update_age(new_age: String):
	active_configs.clear()

	if shop_configs.has(new_age):
		# Don't re-fetch base config; reuse current ones in shop.button_dict
		if shop.current_age != new_age:
			shop.clear_buttons() # Clear old buttons only on actual age change

		var age_configs = shop_configs[new_age]
		for key in age_configs.keys():
			var config = age_configs[key]
			if config.has("unlock_key") and config.has("unlock_amount"):
				if resources[config["unlock_key"]] >= config["unlock_amount"]:
					active_configs.append(config)
			else:
				active_configs.append(config)

		# Only call update_buttons if the age has changed or new unlocks appeared
		shop.update_buttons(active_configs)

func advance_to_next_age(new_age: String):
	print("Advancing to:", new_age)
	current_age = new_age
	shop.transition_to_age(new_age)  # Tell Shop to clear previous buttons
	update_age(new_age)

func update_all_labels() -> void:
	for key in resources.keys():
		if key == "effort":
			var effort_str = "%.2f" % effort_income_per_second
			resource_labels[key].text = "[b]" + key.capitalize() + ":[/b] " + str(resources[key]) + " (+" + effort_str + "/s)"
		else:
			resource_labels[key].text = "[b]" + key.capitalize() + ":[/b] " + str(resources[key])
	# Finally, update total clicks label
	resource_labels["total_clicks"].text = "[b]Total Clicks:[/b] " + str(total_clicks)

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
				if config not in active_configs and resources[unlock_key] >= unlock_amount:
					active_configs.append(config)
			else:
				if config not in active_configs:
					active_configs.append(config)
		shop.update_buttons(active_configs)

func load_ui_config():
	var file = FileAccess.open("res://config/ui_config.json", FileAccess.READ)
	if file:
		var data = file.get_as_text()
		var json = JSON.parse_string(data)
		if json != null:
			ui_config = sanitize_json_numbers(json)
			print("UI config loaded successfully!")

			if ui_config.has("shop_configs"):
				shop_configs = ui_config["shop_configs"]
			else:
				print("Warning: shop_configs not found in ui_config!")
		else:
			print("Error parsing ui_config JSON!")
		file.close()
	else:
		print("Could not open ui_config JSON file!")

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

func _ready() -> void:
	load_ui_config()
	var start_x = 50
	var start_y = 100
	var spacing_x = 40
	var spacing_y = 0

	if ui_config.has("global_ui"):
		start_x = ui_config["global_ui"].get("start_x", 50)
		start_y = ui_config["global_ui"].get("start_y", 100)
		spacing_x = ui_config["global_ui"].get("button_spacing_x", 40)
		spacing_y = ui_config["global_ui"].get("button_spacing_y", 0)
	else:
		print("Warning: global_ui missing in config, using defaults.")

	var i = 0

	shop = Shop.new(self)
	add_child(shop)
	update_age("Stone Age")


	var bg = ColorRect.new()
	bg.color = Color(0.85, 0.72, 0.55)
	bg.size = get_viewport_rect().size
	add_child(bg)
	move_child(bg, 0)

	auto_timer = Timer.new()
	auto_timer.wait_time = auto_interval
	auto_timer.one_shot = false
	auto_timer.autostart = false
	auto_timer.stop()
	print("On ready, is timer stopped? ", auto_timer.is_stopped())
	add_child(auto_timer)
	auto_timer.timeout.connect(_on_auto_timer_timeout)
	
	var work_button_config = ui_config.get("work_button", {})
	$ButtonWork.setup_from_config(work_button_config)

	var label_start_x = 50
	var label_start_y = 50
	var label_spacing_x = 200
	var label_spacing_y = 0


	if ui_config.has("resource_labels_ui"):
		var label_conf = ui_config["resource_labels_ui"]
		label_start_x = label_conf.get("start_x", 50)
		label_start_y = label_conf.get("start_y", 50)
		label_spacing_x = label_conf.get("spacing_x", 200)
		label_spacing_y = label_conf.get("spacing_y", 0)

	i = 0
	for key in resources:
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.text = "[b]" + key.capitalize() + ":[/b] 0"
		label.size = Vector2(180, 30)
		label.position = Vector2(label_start_x + i * label_spacing_x, label_start_y + i * label_spacing_y)

		add_child(label)
		resource_labels[key] = label
		i += 1
	var click_label = RichTextLabel.new()
	click_label.bbcode_enabled = true
	click_label.text = "[b]Total Clicks:[/b] 0"
	click_label.size = Vector2(250, 30)
	click_label.position = Vector2(label_start_x, label_start_y + 50 + i * label_spacing_y + 40) # offset below resources
	add_child(click_label)
	resource_labels["total_clicks"] = click_label



func _process(delta: float) -> void:
	effort_income_per_second = float(manpower_strength * resources["manpower"] * (1.0/auto_interval))
	update_all_labels()
