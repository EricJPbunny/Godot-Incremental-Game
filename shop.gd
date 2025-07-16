extends Node
class_name Shop

var current_age: String = "Stone Age"
var buttons := []
var button_dict := {}
var button_config_state := {}
var main_node

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
	buttons.append(button)
	add_child(button)
	button.visible = false
	button.size = Vector2(180, 30)

	if config.has("cooldown_time") and button.has_method("set_cooldown_time"):
		button.set_cooldown_time(config["cooldown_time"])

	button.pressed.connect(func(): handle_button_press(config, button))
	apply_button_style(button, config)
	add_hover_tooltip(button, config)

func clear_buttons():
	for value in button_dict.values():
		if is_instance_valid(value["button"]):
			value["button"].queue_free()
	button_dict.clear()
	buttons.clear()

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
		if main_node.resources[cost_key] < 0:
			main_node.resources[cost_key] = 0

		if reward_key != null:
			main_node.resources[reward_key] += reward_amount
			print("Reward granted: ", reward_amount)

		# --- Scaling cost ---
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

		var raw_name = config.get("button_label", "Upgrade")
		var nice_name = raw_name.capitalize().replace("_", " ")
		button.text = "Buy %s (%d)" % [nice_name, new_cost]

		if reward_key == "manpower":
			main_node.resource_labels["manpower"].visible = true
			if main_node.auto_timer.is_stopped():
				main_node.auto_timer.start()
	else:
		print("Not enough ", cost_key, " to buy!")
		return

	# --- Special Effects ---
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
			"advance_age":
				var target_age = config.get("advance_to_age", null)
				if target_age != null:
					main_node.advance_to_next_age(target_age)
					button.disabled = true

func update_buttons(config_list: Array):
	if current_age != main_node.current_age:
		return  # Don't update buttons from a different age!
	for config in config_list:
		var key = config.get("button_label", "unknown")

		# Retrieve the mutated config or make a deep copy
		var local_config: Dictionary
		if button_config_state.has(key):
			local_config = button_config_state[key]
		else:
			local_config = config.duplicate(true)
			button_config_state[key] = local_config

		# Create the button only if it doesn't exist
		if not button_dict.has(key):
			var b = Button.new()

			# Set label ONLY when creating new button
			var raw_name = config.get("button_label", "Upgrade")
			var nice_name = raw_name.capitalize().replace("_", " ")
			var cost = local_config.get("cost_amount", 0)
			b.text = "Buy %s (%d)" % [nice_name, cost]

			add_button(b, local_config)

			button_dict[key] = {
				"button": b,
				"config": local_config,
				"unlocked": false
		}

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
	var start_x = 50
	var start_y = ProjectSettings.get_setting("display/window/size/viewport_height") - 150
	var spacing_x = 20
	var spacing_y = 0

	if main_node.ui_config.has("global_ui"):
		start_x = main_node.ui_config["global_ui"].get("start_x", start_x)
		start_y = main_node.ui_config["global_ui"].get("start_y", start_y)
		spacing_x = main_node.ui_config["global_ui"].get("button_spacing_x", spacing_x)

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
		var width = config.get("button_width", 180)
		var height = config.get("button_height", 30)

		button.position = Vector2(current_x, start_y)
		button.size = Vector2(width, height)
		current_x += width + spacing_x

func transition_to_age(new_age: String):
	if new_age != current_age:
		clear_buttons()
		current_age = new_age
