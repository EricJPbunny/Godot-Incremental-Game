extends Node

class_name Shop

var current_age: String = "Stone Age"
var buttons := []
var button_dict := {}
var main_node
#variables for shop logic


func _init(p_main_node = null):
	main_node = p_main_node

func add_hover_tooltip(button: Button, config: Dictionary):
	var tooltip_text = "Cost: " + str(config.get("cost_amount", 0)) + " " + config.get("cost_key", "")
	if config.has("reward_key"):
		tooltip_text += "\nReward: +" + str(config.get("reward_amount", 0)) + " " + config.get("reward_key", "")
	if config.has("effect"):
		tooltip_text += "\nEffect: " + str(config["effect"])

	button.tooltip_text = tooltip_text

func add_button(button: Button, config: Dictionary):
	# Add button to internal list and scene
	buttons.append(button)
	add_child(button)
	button.visible = false
	button.size = Vector2(180, 30)

	# Set cooldown if present
	if config.has("cooldown_time") and button.has_method("set_cooldown_time"):
		button.set_cooldown_time(config["cooldown_time"])

	# Connect press signal to external handler
	button.pressed.connect(func(): handle_button_press(config, button))
	apply_button_style(button, config) # Calls the styling of button when in config
	add_hover_tooltip(button, config)
	
func apply_button_style(button: Button, config: Dictionary):
	if config.has("button_width") and config.has("button_height"):
		button.size = Vector2(config["button_width"], config["button_height"])
	if config.has("button_color"):
		var style = StyleBoxFlat.new()
		style.bg_color = Color(config["button_color"])
		button.add_theme_stylebox_override("normal", style)


func handle_button_press(config: Dictionary, button: Button):
	print("Pressed:", button.text)

	var cost_key = config.get("cost_key", null)
	var reward_key = config.get("reward_key", null)
	var cost_amount = config.get("cost_amount", 0)
	var reward_amount = config.get("reward_amount", 0)
	var cost_scale = config.get("cost_scale", 1.0)

	if main_node == null:
		print("Main node not found!")
		return

	if main_node.resources[cost_key] >= cost_amount:
		main_node.resources[cost_key] -= cost_amount

		# Sanity checker
		if main_node.resources[cost_key] < 0:
			main_node.resources[cost_key] = 0

		# Reward
		if config.has("reward_key") and reward_key != null:
			main_node.resources[reward_key] += reward_amount
			print("Reward granted: ", reward_amount)

		# Cost scaling
		var new_cost = cost_amount
		if config.has("scaling_type"):
			match config["scaling_type"]:
				"exponential":
					new_cost = int(cost_amount * cost_scale)
				"logarithmic":
					new_cost = int(cost_amount + log(cost_amount + 1) * 5)
		else:
			new_cost = int(cost_amount * cost_scale)
		config["cost_amount"] = new_cost
		print("New cost for ", reward_key, ": ", config["cost_amount"])
		# Update button text to show new cost
		if button != null:
			var raw_name = config.get("button_label", "Upgrade")
			var nice_name = raw_name.capitalize().replace("_", " ")
			button.text = "Buy %s (%d)" % [nice_name, new_cost]

		# Special handling for manpower
		if reward_key == "manpower":
			main_node.resource_labels["manpower"].visible = true
			if main_node.auto_timer.is_stopped():
				main_node.auto_timer.start()
	else:
		print("Not enough ", cost_key, " to buy!")
		return

	# Effects
	if config.has("effect"):
		match config["effect"]:
			"increase_click_bonus":
				main_node.effort_press_bonus += config["bonus_amount"]
				print("Click bonus increased by ", config["bonus_amount"])
				main_node.fire_unlocked = true
				button.disabled = true
			"enable_autoclick":
				main_node.autoclick_enabled = true
				print("Autoclick feature enabled!")
				button.disabled = true


func update_buttons(config_list: Array):
	# Create new buttons from configs
	for config in config_list:
		var key = config.get("button_label", "unknown")
		if not button_dict.has(key):
			var b = Button.new()
			var raw_name = config.get("button_label", "Upgrade")
			var nice_name = raw_name.capitalize().replace("_", " ")
			b.text = "Buy " + nice_name
			var local_config = config.duplicate() #prevent shared reference issues
			add_button(b, local_config)
			button_dict[key] = {
				"button": b,
				"config": local_config,
				"unlocked": false
			}
			b.visible = false
		if config.has("unlock_key") and config.has("unlock_amount"):
			var unlock_key = config["unlock_key"]
			var unlock_amount = config["unlock_amount"]
			if main_node.resources[unlock_key] >= unlock_amount:
				button_dict[key]["unlocked"] = true
				button_dict[key]["button"].visible = true
		else:
				button_dict[key]["unlocked"] = true
				button_dict[key]["button"].visible = true

	position_buttons()

func position_buttons():
	var start_x = 50 # Fallback default
	var start_y = ProjectSettings.get_setting("display/window/size/viewport_height") -150
	var spacing_x = 20 # Fallback default
	var spacing_y = 0 # Fallback default
	if main_node.ui_config.has("global_ui"):
		start_x = main_node.ui_config["global_ui"].get("start_x", 50)
		start_y = main_node.ui_config["global_ui"].get("start_y", ProjectSettings.get_setting("display/window/size/viewport_height") - 150)
		spacing_x = main_node.ui_config["global_ui"].get("button_spacing_x", 20)

	# Per-age overrides
	var age_key = current_age + "_ui"
	if main_node.ui_config.has(age_key):
		var age_conf = main_node.ui_config[age_key]
		start_x = age_conf.get("start_x", start_x)
		start_y = age_conf.get("start_y", start_y)
		spacing_x = age_conf.get("button_spacing_x", spacing_x)

	var current_x = start_x

	for value in button_dict.values():
		var button = value["button"]
		var config = value["config"]

		var width = config.get("button_width", main_node.ui_config["global_ui"].get("default_button_width", 180))
		var height = config.get("button_height", main_node.ui_config["global_ui"].get("default_button_height", 30))

		button.position = Vector2(current_x, start_y)
		button.size = Vector2(width, height)

		current_x += width + spacing_x

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	pass
