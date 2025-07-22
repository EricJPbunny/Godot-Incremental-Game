extends Node
class_name Shop

# ===== CONSTANTS =====
# Button defaults
const DEFAULT_BUTTON_SIZE = Vector2(180, 30)
const DEFAULT_BUTTON_WIDTH = 180
const DEFAULT_BUTTON_HEIGHT = 30

# UI positioning defaults
const DEFAULT_START_X = 50
const DEFAULT_START_Y_OFFSET = 150  # Distance from bottom of screen
const DEFAULT_SPACING_X = 20
const DEFAULT_SPACING_Y = 0

# Color constants for button states
const COLOR_PURCHASED = Color(0.15, 0.6, 0.15)  # Green for purchased
const COLOR_AVAILABLE = Color(0.3, 0.3, 0.3)    # Gray for available
const COLOR_LOCKED = Color(0.2, 0.2, 0.2)       # Darker gray for locked

# Debug constants
const DEBUG_FIRE_UPGRADE_KEY = "Fire Upgrade"

# Add this constant at the top with other button/layout constants
const SHOP_ROW_OFFSET = 16  # Vertical offset between shop rows (can be overridden by JSON)

# ===== VARIABLES =====
var current_age: String = "Stone Age"
var buttons := []
var button_dict := {}
var button_config_state := {}
var main_node

func _init(p_main_node = null):
	main_node = p_main_node

func add_hover_tooltip(button: Button, config: Dictionary):
	if not button:
		print("ERROR: Cannot add tooltip to null button!")
		return
	if not config:
		print("ERROR: Cannot add tooltip with null config!")
		return
		
	var tooltip_text = "Cost: " + str(config.get("cost_amount", 0)) + " " + config.get("cost_key", "")
	if config.has("reward_key"):
		tooltip_text += "\nReward: +" + str(config.get("reward_amount", 0)) + " " + config.get("reward_key", "")
	if config.has("effect"):
		tooltip_text += "\nEffect: " + str(config["effect"])
	button.tooltip_text = tooltip_text

func add_button(button: Button, config: Dictionary):
	if not button:
		print("ERROR: Cannot add null button!")
		return
	if not config:
		print("ERROR: Cannot add button with null config!")
		return
		
	buttons.append(button)
	add_child(button)
	button.visible = false  # Start invisible
	button.disabled = true  # Start disabled
	button.size = DEFAULT_BUTTON_SIZE

	# Apply tech locking immediately on creation
	var key = config.get("button_label", "unknown")
	var tech_locked := false
	if main_node and main_node.tech_tree and main_node.tech_tree.tech_config_state.has(key):
		if not main_node.tech_tree.tech_config_state[key].get("purchased", false):
			tech_locked = true
			button.disabled = true
			if key == DEBUG_FIRE_UPGRADE_KEY:
				print("DEBUG: Fire Upgrade created and disabled due to tech lock")
		else:
			if key == DEBUG_FIRE_UPGRADE_KEY:
				print("DEBUG: Fire Upgrade created and enabled - tech already purchased")
	else:
		if key == DEBUG_FIRE_UPGRADE_KEY:
			print("DEBUG: Fire Upgrade created - no tech config found")

	if config.has("cooldown_time") and button.has_method("set_cooldown_time"):
		var cooldown_time = config["cooldown_time"]
		if cooldown_time is float or cooldown_time is int:
			button.set_cooldown_time(cooldown_time)
		else:
			print("WARNING: Invalid cooldown_time format: ", cooldown_time)

	button.pressed.connect(func(): handle_button_press(config, button))
	apply_button_style(button, config)
	add_hover_tooltip(button, config)

func clear_buttons():
	for value in button_dict.values():
		if value is Dictionary and value.has("button"):
			var button = value["button"]
			if is_instance_valid(button):
				button.queue_free()
	button_dict.clear()
	buttons.clear()

func parse_color(color_data) -> Color:
	if color_data is Array and color_data.size() >= 3:
		return Color(color_data[0], color_data[1], color_data[2])
	elif color_data is String:
		# Handle hex color strings like "#A0522D"
		if color_data.begins_with("#"):
			var hex = color_data.substr(1)  # Remove the #
			if hex.length() == 6:
				var r = hex.substr(0, 2).hex_to_int() / 255.0
				var g = hex.substr(2, 2).hex_to_int() / 255.0
				var b = hex.substr(4, 2).hex_to_int() / 255.0
				return Color(r, g, b)
		# Try to parse as a named color
		return Color(color_data)
	else:
		print("WARNING: Unsupported color format: ", color_data)
		return Color.WHITE  # Default fallback

func apply_button_style(button: Button, config: Dictionary):
	if not button:
		print("ERROR: Cannot apply style to null button!")
		return
	if not config:
		print("ERROR: Cannot apply style with null config!")
		return
		
	if config.has("button_width") and config.has("button_height"):
		var width = config["button_width"]
		var height = config["button_height"]
		if width is int or width is float and height is int or height is float:
			button.size = Vector2(width, height)
		else:
			print("WARNING: Invalid button dimensions: ", width, "x", height)
			
	if config.has("button_color"):
		var color_data = config["button_color"]
		var color = parse_color(color_data)
		var style = StyleBoxFlat.new()
		style.bg_color = color
		button.add_theme_stylebox_override("normal", style)

func handle_button_press(config: Dictionary, button: Button):
	if not config:
		print("ERROR: Button pressed with null config!")
		return
	if not button:
		print("ERROR: Button press with null button!")
		return
	
	print("Pressed:", button.text)

	# Special logic for advancing to Iron Age
	if config.get("requires_all_bronze_techs", false):
		if not main_node or not main_node.tech_tree:
			print("ERROR: Main node or tech tree not found!")
			return
		var all_bronze_techs_researched = true
		for tech_key in main_node.tech_tree.tech_config_state.keys():
			var tech = main_node.tech_tree.tech_config_state[tech_key]
			if tech.has("config") and tech["config"].has("cost_key") and tech["config"].get("cost_key") == "effort":
				# Only check Bronze Age techs (skip Stone Age, etc.)
				if tech["config"].has("tooltip") and tech["config"]["tooltip"].find("Bronze") != -1:
					if not tech.get("purchased", false):
						all_bronze_techs_researched = false
						print("Cannot advance: tech not researched:", tech_key)
						break
		if not all_bronze_techs_researched:
			print("Cannot advance: not all Bronze Age techs researched.")
			return
		# Check all three resources
		var cost_key = config.get("cost_key", null)
		var cost_amount = config.get("cost_amount", 0)
		var cost_key_2 = config.get("cost_key_2", null)
		var cost_amount_2 = config.get("cost_amount_2", 0)
		var cost_key_3 = config.get("cost_key_3", null)
		var cost_amount_3 = config.get("cost_amount_3", 0)
		if not main_node.resources.has(cost_key) or main_node.resources[cost_key] < cost_amount:
			print("Not enough ", cost_key, " to advance!")
			return
		if not main_node.resources.has(cost_key_2) or main_node.resources[cost_key_2] < cost_amount_2:
			print("Not enough ", cost_key_2, " to advance!")
			return
		if not main_node.resources.has(cost_key_3) or main_node.resources[cost_key_3] < cost_amount_3:
			print("Not enough ", cost_key_3, " to advance!")
			return
		# Deduct all resources
		main_node.resources[cost_key] -= cost_amount
		main_node.resources[cost_key_2] -= cost_amount_2
		main_node.resources[cost_key_3] -= cost_amount_3
		print("Advancing to Iron Age!")
		if config.get("effect") == "advance_age":
			var target_age = config.get("advance_to_age", null)
			if target_age != null:
				main_node.advance_to_next_age(target_age)
			else:
				print("WARNING: advance_age effect missing advance_to_age!")
		return

	# Enforce 'requires' dependencies for shop buttons
	if config.has("requires") and main_node and main_node.tech_tree:
		for req in config["requires"]:
			if not main_node.tech_tree.tech_config_state.has(req) or not main_node.tech_tree.tech_config_state[req].get("purchased", false):
				print("Cannot purchase", config.get("button_label", "unknown"), "- required tech", req, "not purchased yet.")
				return

	var cost_key = config.get("cost_key", null)
	var reward_key = config.get("reward_key", null)
	var cost_amount = config.get("cost_amount", 0)
	var reward_amount = config.get("reward_amount", 0)
	var cost_scale = config.get("cost_scale", 1.0)

	if main_node == null:
		print("ERROR: Main node not found!")
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

	if not main_node.resources.has(cost_key):
		print("ERROR: Cost resource not found: ", cost_key)
		return
	
	if main_node.resources.get(cost_key, 0) >= cost_amount:
		main_node.resources[cost_key] -= cost_amount
		if reward_key:
			if main_node.resources.has(reward_key):
				main_node.resources[reward_key] += reward_amount
				print("Reward granted: ", reward_amount)
			else:
				print("WARNING: Reward resource not found: ", reward_key)

		# Apply effects
		if config.has("effect"):
			match config["effect"]:
				"increase_click_bonus":
					if config.has("bonus_amount"):
						main_node.effort_press_bonus += config["bonus_amount"]
						main_node.fire_unlocked = true
						print("Click bonus increased by ", config["bonus_amount"])
					else:
						print("WARNING: increase_click_bonus effect missing bonus_amount!")
				"enable_autoclick":
					main_node.autoclick_enabled = true
					print("Autoclick feature enabled!")
				"advance_age":
					var target_age = config.get("advance_to_age", null)
					if target_age != null:
						main_node.advance_to_next_age(target_age)
					else:
						print("WARNING: advance_age effect missing advance_to_age!")
				"boost_manpower_productivity":
					if config.has("bonus_multiplier"):
						main_node.effort_press_multiplier += config["bonus_multiplier"]
						print("Manpower productivity boosted by ", config["bonus_multiplier"] * 100, "%!")
					else:
						print("WARNING: boost_manpower_productivity effect missing bonus_multiplier!")
				_:
					print("WARNING: Unknown effect: ", config["effect"])

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
					"logloglog":
						new_cost = int(cost_amount + log(log(log(cost_amount + 10) + 1) + 1) * 2)
					_:
						print("WARNING: Unknown scaling_type: ", config["scaling_type"])
			else:
				new_cost = int(cost_amount * cost_scale)

			config["cost_amount"] = new_cost
			var raw_name = config.get("button_label", "Upgrade")
			var nice_name = raw_name.capitalize().replace("_", " ")
			button.text = "Buy %s (%d)" % [nice_name, new_cost]

		if reward_key == "manpower":
			if main_node.resource_labels.has("manpower"):
				main_node.resource_labels["manpower"].visible = true
			if main_node.auto_timer and main_node.auto_timer.is_stopped():
				main_node.auto_timer.start()
	else:
		print("Not enough ", cost_key, " to buy!")
		return

	# After any purchase, refresh tech tree visibility
	if main_node.tech_tree and main_node.ui_config and main_node.ui_config.has("tech_tree_configs"):
		main_node.tech_tree.update_tech_buttons(main_node.ui_config["tech_tree_configs"])

func update_button_properties(button: Button, config: Dictionary):
	if not button:
		print("ERROR: Cannot update properties of null button!")
		return
	if not config:
		print("ERROR: Cannot update button with null config!")
		return
		
	# Update text
	var raw_name = config.get("button_label", "Upgrade")
	var nice_name = raw_name.capitalize().replace("_", " ")
	var cost = config.get("cost_amount", 0)
	button.text = "Buy %s (%d)" % [nice_name, cost]
	# Update style and tooltip
	apply_button_style(button, config)
	add_hover_tooltip(button, config)
	# Update cooldown if needed
	if config.has("cooldown_time") and button.has_method("set_cooldown_time"):
		var cooldown_time = config["cooldown_time"]
		if cooldown_time is float or cooldown_time is int:
			button.set_cooldown_time(cooldown_time)
		else:
			print("WARNING: Invalid cooldown_time format: ", cooldown_time)

func update_buttons(config_list: Array):
	if not config_list:
		print("WARNING: Empty config_list provided to update_buttons")
		return
		
	if current_age != main_node.current_age:
		return

	var config_keys := []
	for config in config_list:
		if not config is Dictionary:
			print("WARNING: Invalid config format in config_list")
			continue
			
		var key = config.get("button_label", "unknown")
		config_keys.append(key)

		var local_config: Dictionary
		if button_config_state.has(key):
			local_config = button_config_state[key]
		else:
			local_config = config.duplicate(true)
			button_config_state[key] = local_config

		var b: Button
		if not button_dict.has(key):
			b = Button.new()
			if not b:
				print("ERROR: Failed to create button for key: ", key)
				continue
			add_button(b, local_config)
			button_dict[key] = {
				"button": b,
				"config": local_config,
				"unlocked": false
			}
		else:
			b = button_dict[key]["button"]
			if b:
				update_button_properties(b, local_config)
			else:
				print("ERROR: Button is null for key: ", key)
				continue

		# Unlock/lock logic
		var tech_locked := false
		if main_node.tech_tree and main_node.tech_tree.tech_config_state.has(key):
			if not main_node.tech_tree.tech_config_state[key].get("purchased", false):
				tech_locked = true

		if local_config.get("one_time", false) and local_config.get("purchased", false):
			tech_locked = true

		# Handle visibility based on resource unlock conditions
		if config.has("unlock_key") and config.has("unlock_amount"):
			var unlock_key = config["unlock_key"]
			var unlock_amount = config["unlock_amount"]
			if main_node.resources.has(unlock_key) and main_node.resources.get(unlock_key, 0) >= unlock_amount:
				button_dict[key]["unlocked"] = true
				b.visible = true  # Only set visible=true, never false
		else:
			# No resource unlock condition = always visible
			button_dict[key]["unlocked"] = true
			b.visible = true

	# === Re-apply tech gating ===
	for key in button_dict.keys():
		var btn_data = button_dict[key]
		if not btn_data is Dictionary or not btn_data.has("button"):
			continue
		var b = btn_data["button"]
		if not b:
			continue
		# Check if this button is tech-locked by finding the tech that unlocks it
		var tech_locked := false
		if main_node.tech_tree:
			# Find the tech that unlocks this button
			for tech_key in main_node.tech_tree.tech_config_state.keys():
				var tech_config = main_node.tech_tree.tech_config_state[tech_key]
				if tech_config.has("config") and tech_config["config"].has("unlocks"):
					if tech_config["config"]["unlocks"] == key:  # This tech unlocks our button
						if not tech_config.get("purchased", false):
							tech_locked = true
						break

		# Check if one-time upgrade is already purchased
		var local_config = btn_data.get("config", {})
		if local_config.get("one_time", false) and local_config.get("purchased", false):
			tech_locked = true
			
		var should_disable = (tech_locked or not btn_data["unlocked"])
		
		if b.disabled != should_disable:
			b.disabled = should_disable
				
	position_buttons()

func position_buttons():
	var start_x = DEFAULT_START_X
	var start_y = ProjectSettings.get_setting("display/window/size/viewport_height") - DEFAULT_START_Y_OFFSET
	var spacing_x = DEFAULT_SPACING_X
	var spacing_y = DEFAULT_SPACING_Y
	var row_offset = SHOP_ROW_OFFSET

	if main_node.ui_config.has("global_ui"):
		start_x = main_node.ui_config["global_ui"].get("start_x", start_x)
		start_y = main_node.ui_config["global_ui"].get("start_y", start_y)
		spacing_x = main_node.ui_config["global_ui"].get("button_spacing_x", spacing_x)
		row_offset = main_node.ui_config["global_ui"].get("shop_row_offset", row_offset)

	var age_key = current_age + "_ui"
	if main_node.ui_config.has(age_key):
		var age_conf = main_node.ui_config[age_key]
		start_x = age_conf.get("start_x", start_x)
		start_y = age_conf.get("start_y", start_y)
		spacing_x = age_conf.get("button_spacing_x", spacing_x)
		row_offset = age_conf.get("shop_row_offset", row_offset)

	# --- Sort buttons by display_order ---
	var button_list = []
	for value in button_dict.values():
		if value.has("config") and value["config"].has("display_order"):
			button_list.append(value)
		else:
			button_list.append(value) # fallback for buttons without display_order
	button_list.sort_custom(func(a, b):
		return int(a["config"].get("display_order", 999)) < int(b["config"].get("display_order", 999))
	)

	# --- 2-row layout ---
	var max_top_row = 5
	var top_y = start_y
	var current_x_top = start_x
	var current_x_bottom = start_x

	# First, determine the tallest button in the top row
	var max_top_row_height = DEFAULT_BUTTON_HEIGHT
	for i in range(min(max_top_row, button_list.size())):
		var value = button_list[i]
		var config = value["config"]
		var height = config.get("button_height", DEFAULT_BUTTON_HEIGHT)
		if height > max_top_row_height:
			max_top_row_height = height

	var bottom_y = top_y + max_top_row_height + row_offset

	for i in range(button_list.size()):
		var value = button_list[i]
		var button = value["button"]
		var config = value["config"]
		var width = config.get("button_width", DEFAULT_BUTTON_WIDTH)
		var height = config.get("button_height", DEFAULT_BUTTON_HEIGHT)

		if i < max_top_row:
			button.position = Vector2(current_x_top, top_y)
			current_x_top += width + spacing_x
		else:
			button.position = Vector2(current_x_bottom, bottom_y)
			current_x_bottom += width + spacing_x
		button.size = Vector2(width, height)

func transition_to_age(new_age: String):
	if new_age != current_age:
		clear_buttons()
		current_age = new_age
