extends Node
class_name TechTree

# ===== CONSTANTS =====
# Button defaults
const DEFAULT_BUTTON_SIZE = Vector2(200, 40)
const DEFAULT_BUTTON_WIDTH = 200
const DEFAULT_BUTTON_HEIGHT = 40

# UI positioning defaults
const DEFAULT_START_X_OFFSET = 270  # Distance from right edge of screen
const DEFAULT_START_Y = 100
const DEFAULT_SPACING_Y = 50

# Color constants for button states
const COLOR_PURCHASED = Color(0.15, 0.6, 0.15)  # Green for purchased
const COLOR_AVAILABLE = Color(0.3, 0.3, 0.3)    # Gray for available
const COLOR_LOCKED = Color(0.2, 0.2, 0.2)       # Darker gray for locked

# ===== VARIABLES =====
var main_node
var tech_buttons := {}
var tech_config_state := {}

func _init(p_main_node = null):
	main_node = p_main_node

# Add this method to control tech button visibility
func set_tree_visible(visible: bool):
	for b in tech_buttons.values():
		if b:
			b.visible = visible

# In add_tech_button, parent to TechTreeWindow if it exists
func add_tech_button(button: Button, config: Dictionary):
	if not button:
		print("ERROR: Cannot add null tech button!")
		return
	if not config:
		print("ERROR: Cannot add tech button with null config!")
		return
	
	# Parent to TechTreeWindow if it exists
	var win = get_node_or_null("../TechTreeWindow")
	if win:
		win.add_child(button)
	else:
		add_child(button)
	button.visible = true
	button.size = DEFAULT_BUTTON_SIZE

	# Set initial text
	button.text = config.get("tech_label", "Tech")

	# Color by vibe (placeholder logic)
	var style = StyleBoxFlat.new()
	var label = config.get("tech_label", "").to_lower()
	if label.find("fire") != -1:
		style.bg_color = Color(0.8, 0.2, 0.1) # red
	elif label.find("tool") != -1:
		style.bg_color = Color(0.4, 0.4, 0.4) # gray
	elif label.find("bronze") != -1:
		style.bg_color = Color(0.8, 0.5, 0.2) # bronze
	elif label.find("tin") != -1:
		style.bg_color = Color(0.7, 0.7, 0.8) # tin/silver
	elif label.find("copper") != -1:
		style.bg_color = Color(0.8, 0.4, 0.2) # copper
	else:
		style.bg_color = COLOR_AVAILABLE
	button.add_theme_stylebox_override("normal", style)

	button.disabled = false

	# Tooltip
	var unlocks_val = ""
	if config.has("unlocks") and config["unlocks"] != null:
		unlocks_val = str(config["unlocks"])
	var tooltip = ""
	if unlocks_val != "":
		tooltip += "Unlocks: " + unlocks_val + "\n"
	tooltip += "Cost: " + str(config.get("cost_amount", 0)) + " " + config.get("cost_key", "")
	if config.has("requires"):
		var reqs = config["requires"]
		if typeof(reqs) == TYPE_ARRAY:
			tooltip += "\nRequires: " + ", ".join(reqs)
		else:
			tooltip += "\nRequires: " + str(reqs)
	if config.has("tooltip"):
		tooltip += "\n" + str(config["tooltip"])
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
	
	# Check prerequisites
	var prerequisites_met = true
	if config.has("requires"):
		var reqs = config["requires"]
		if typeof(reqs) == TYPE_ARRAY:
			for req in reqs:
				if not tech_config_state.has(req) or not tech_config_state[req].get("purchased", false):
					prerequisites_met = false
					break
		else:
			if not tech_config_state.has(reqs) or not tech_config_state[reqs].get("purchased", false):
				prerequisites_met = false
	
	# Update tooltip
	var tooltip = "Unlocks: " + config.get("unlocks", "unknown")
	tooltip += "\nCost: " + str(config.get("cost_amount", 0)) + " " + config.get("cost_key", "")
	if config.has("requires"):
		tooltip += "\nRequires: " + config["requires"]
	button.tooltip_text = tooltip
	
	# Update style based on purchase state and prerequisites
	var style = StyleBoxFlat.new()
	var key = config.get("tech_label", "unknown")
	if tech_config_state.get(key, {}).get("purchased", false):
		style.bg_color = COLOR_PURCHASED  # Green for purchased
		button.disabled = true
	else:
		if prerequisites_met:
			style.bg_color = COLOR_AVAILABLE  # Gray for available
			button.disabled = false
		else:
			style.bg_color = COLOR_LOCKED  # Darker gray for locked
			button.disabled = true
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

	# Check prerequisites
	if config.has("requires"):
		var reqs = config["requires"]
		if typeof(reqs) == TYPE_ARRAY:
			for req in reqs:
				if not tech_config_state.has(req):
					print("Cannot purchase ", key, " - required tech ", req, " not found")
					return
				if not tech_config_state[req].get("purchased", false):
					print("Cannot purchase ", key, " - required tech ", req, " not purchased yet")
					return
		else:
			if not tech_config_state.has(reqs):
				print("Cannot purchase ", key, " - required tech ", reqs, " not found")
				return
			if not tech_config_state[reqs].get("purchased", false):
				print("Cannot purchase ", key, " - required tech ", reqs, " not purchased yet")
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
	style.bg_color = COLOR_PURCHASED
	button.add_theme_stylebox_override("normal", style)

	# Unlock shop button
	if config.has("unlocks") and config["unlocks"] != null and str(config["unlocks"]).strip_edges() != "":
		var unlock_key = str(config["unlocks"])
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
	
	var start_x = ProjectSettings.get_setting("display/window/size/viewport_width") - DEFAULT_START_X_OFFSET
	var start_y = DEFAULT_START_Y
	var spacing_y = DEFAULT_SPACING_Y

	var config_keys := []

	# First pass: register all techs in tech_config_state
	for i in range(config_list.size()):
		var config = config_list[i]
		if not config is Dictionary:
			print("WARNING: Invalid config format in tech config_list at index: ", i)
			continue
		var key = config.get("tech_label", "unknown")
		config_keys.append(key)
		if not tech_config_state.has(key):
			tech_config_state[key] = {
				"config": config.duplicate(true),
				"purchased": false,
				"button": null
			}

	# Second pass: create buttons and set up properties
	for i in range(config_list.size()):
		var config = config_list[i]
		var key = config.get("tech_label", "unknown")
		var b: Button
		if not tech_buttons.has(key):
			b = Button.new()
			if not b:
				print("ERROR: Failed to create tech button for key: ", key)
				continue
			tech_config_state[key]["button"] = b
			tech_buttons[key] = b
			add_tech_button(b, config)
		else:
			b = tech_buttons[key]
			if b:
				update_tech_button_properties(b, config)
			else:
				print("ERROR: Tech button is null for key: ", key)
				continue
		# Position relative to window if parented to it
		if b.get_parent() and b.get_parent().name == "TechTreeWindow":
			b.position = Vector2(20, 40 + i * DEFAULT_SPACING_Y)
		else:
			b.position = Vector2(start_x, start_y + i * spacing_y)

	# Hide buttons not in current config
	for key in tech_buttons.keys():
		if key not in config_keys:
			var button = tech_buttons[key]
			if button:
				button.visible = false
