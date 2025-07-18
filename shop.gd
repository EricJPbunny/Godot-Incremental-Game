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

	var tech_label = config.get("button_label", null)
	if tech_label and main_node.tech_tree:
		var tech_state = main_node.tech_tree.tech_config_state.get(tech_label, {})
		if tech_state.has("purchased") and tech_state["purchased"] == false:
			print("Cannot purchase", tech_label, "- tech not unlocked yet.")
			return

	if config.get("one_time", false) and config.get("purchased", false):
		print("Already purchased one-time upgrade:", tech_label)
		return

	if main_node.resources.get(cost_key, 0) >= cost_amount:
		main_node.resources[cost_key] -= cost_amount
		if reward_key:
			main_node.resources[reward_key] += reward_amount
			print("Reward granted: ", reward_amount)

		# Apply effects
		if config.has("effect"):
			match config["effect"]:
				"increase_click_bonus":
					main_node.effort_press_bonus += config["bonus_amount"]
					main_node.fire_unlocked = true
					print("Click bonus increased by ", config["bonus_amount"])
				"enable_autoclick":
					main_node.autoclick_enabled = true
					print("Autoclick feature enabled!")
				"advance_age":
					var target_age = config.get("advance_to_age", null)
					if target_age != null:
						main_node.advance_to_next_age(target_age)

		# Handle one-time upgrades
		if config.get("one_time", false):
			config["purchased"] = true
			button.disabled = true
			print("One-time upgrade purchased:", tech_label)

		# Update cost for next purchase if not one-time
		if not config.get("one_time", false):
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

func update_buttons(config_list: Array):
	if current_age != main_node.current_age:
		return

	for config in config_list:
		var key = config.get("button_label", "unknown")

		var local_config: Dictionary
		if button_config_state.has(key):
			local_config = button_config_state[key]
		else:
			local_config = config.duplicate(true)
			button_config_state[key] = local_config

		var b: Button

		if not button_dict.has(key):
			b = Button.new()
			var raw_name = local_config.get("button_label", "Upgrade")
			var nice_name = raw_name.capitalize().replace("_", " ")
			var cost = local_config.get("cost_amount", 0)
			b.text = "Buy %s (%d)" % [nice_name, cost]

			add_button(b, local_config)

			button_dict[key] = {
				"button": b,
				"config": local_config,
				"unlocked": false
			}

		else:
			b = button_dict[key]["button"]

		var tech_locked := false
		if main_node.tech_tree and main_node.tech_tree.tech_config_state.has(key):
			if not main_node.tech_tree.tech_config_state[key].get("purchased", false):
				b.disabled = true
				tech_locked = true

		if local_config.get("one_time", false) and local_config.get("purchased", false):
			b.disabled = true
			tech_locked = true

		if not tech_locked:
			if config.has("unlock_key") and config.has("unlock_amount"):
				var unlock_key = config["unlock_key"]
				var unlock_amount = config["unlock_amount"]
				if main_node.resources.get(unlock_key, 0) >= unlock_amount:
					button_dict[key]["unlocked"] = true
					b.visible = true
					b.disabled = false
			else:
				# No unlock condition = default visible,
				# but still honor tech lock
				button_dict[key]["unlocked"] = true
				b.visible = true
				# DON'T touch .disabled here — it's already correct
	# === Re-apply tech gating ===
	for key in button_dict.keys():
		var btn_data = button_dict[key]
		var b = btn_data["button"]
		var tech_locked := false

		if main_node.tech_tree and main_node.tech_tree.tech_config_state.has(key):
			if not main_node.tech_tree.tech_config_state[key].get("purchased", false):
				b.disabled = true
				tech_locked = true

		# Optional: disable again if unlock conditions not met
		if not btn_data["unlocked"] or tech_locked:
			b.disabled = true

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
