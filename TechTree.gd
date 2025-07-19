extends Node
class_name TechTree

var main_node
var tech_buttons := {}
var tech_config_state := {}

func _init(p_main_node = null):
	main_node = p_main_node

func add_tech_button(button: Button, config: Dictionary):
	if not button:
		print("ERROR: Cannot add null tech button!")
		return
	if not config:
		print("ERROR: Cannot add tech button with null config!")
		return
		
	# Add to scene
	add_child(button)
	button.visible = true
	button.size = Vector2(200, 40)

	# Initial style - grayed out
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3)
	button.add_theme_stylebox_override("normal", style)

	button.disabled = false

	# Tooltip
	var tooltip = "Unlocks: " + config.get("unlocks", "unknown")
	tooltip += "\nCost: " + str(config.get("cost_amount", 0)) + " " + config.get("cost_key", "")
	button.tooltip_text = tooltip

	# Connect
	button.pressed.connect(func(): handle_tech_press(config, button))

func update_tech_button_properties(button: Button, config: Dictionary):
	if not button:
		print("ERROR: Cannot update properties of null tech button!")
		return
	if not config:
		print("ERROR: Cannot update tech button with null config!")
		return
		
	# Update text
	button.text = config.get("tech_label", "Tech")
	# Update tooltip
	var tooltip = "Unlocks: " + config.get("unlocks", "unknown")
	tooltip += "\nCost: " + str(config.get("cost_amount", 0)) + " " + config.get("cost_key", "")
	button.tooltip_text = tooltip
	# Update style based on purchase state
	var style = StyleBoxFlat.new()
	var key = config.get("tech_label", "unknown")
	if tech_config_state.get(key, {}).get("purchased", false):
		style.bg_color = Color(0.15, 0.6, 0.15)  # Green for purchased
		button.disabled = true
	else:
		style.bg_color = Color(0.3, 0.3, 0.3)  # Gray for unpurchased
		button.disabled = false
	button.add_theme_stylebox_override("normal", style)

func handle_tech_press(config: Dictionary, button: Button):
	if not config:
		print("ERROR: Tech button pressed with null config!")
		return
	if not button:
		print("ERROR: Tech button press with null button!")
		return
		
	var key = config.get("tech_label", "unknown")
	var cost_key = config.get("cost_key", null)
	var cost_amount = config.get("cost_amount", 0)

	if not cost_key:
		print("ERROR: Tech config missing cost_key!")
		return

	if tech_config_state.get(key, {})["purchased"]:
		print("Tech already purchased: ", key)
		return

	if not main_node:
		print("ERROR: Main node not found in tech tree!")
		return
		
	if not main_node.resources.has(cost_key):
		print("ERROR: Cost resource not found: ", cost_key)
		return
		
	if main_node.resources.get(cost_key, 0) < cost_amount:
		print("Not enough ", cost_key, " to purchase tech: ", key)
		return

	main_node.resources[cost_key] -= cost_amount
	tech_config_state[key]["purchased"] = true
	tech_config_state[key]["button"] = button
	button.disabled = true

	# Re-style to show it's purchased
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.6, 0.15)
	button.add_theme_stylebox_override("normal", style)

	# Unlock shop button
	if config.has("unlocks"):
		var unlock_key = config["unlocks"]
		if main_node.shop and main_node.shop.button_dict.has(unlock_key):
			var shop_button_data = main_node.shop.button_dict[unlock_key]
			if shop_button_data is Dictionary and shop_button_data.has("button"):
				var shop_button = shop_button_data["button"]
				if shop_button:
					shop_button.disabled = false
					print("Unlocked shop button:", unlock_key)
				else:
					print("WARNING: Shop button is null for key: ", unlock_key)
			else:
				print("WARNING: Invalid shop button data for key: ", unlock_key)
		else:
			print("WARNING: Shop button not found for unlock key: ", unlock_key)

func update_tech_buttons(config_list: Array):
	if not config_list:
		print("WARNING: Empty config_list provided to update_tech_buttons")
		return
		
	var start_x = ProjectSettings.get_setting("display/window/size/viewport_width") - 270
	var start_y = 100
	var spacing_y = 50

	var config_keys := []
	for i in range(config_list.size()):
		var config = config_list[i]
		if not config is Dictionary:
			print("WARNING: Invalid config format in tech config_list at index: ", i)
			continue
			
		var key = config.get("tech_label", "unknown")
		config_keys.append(key)

		var b: Button
		if not tech_buttons.has(key):
			b = Button.new()
			if not b:
				print("ERROR: Failed to create tech button for key: ", key)
				continue
			var local_config = config.duplicate(true)
			tech_config_state[key] = {
				"config": local_config,
				"purchased": false,
				"button": b
			}
			tech_buttons[key] = b
			add_tech_button(b, local_config)
		else:
			b = tech_buttons[key]
			if b:
				update_tech_button_properties(b, config)
			else:
				print("ERROR: Tech button is null for key: ", key)
				continue

		b.position = Vector2(start_x, start_y + i * spacing_y)

	# Hide buttons not in current config
	for key in tech_buttons.keys():
		if key not in config_keys:
			var button = tech_buttons[key]
			if button:
				button.visible = false
