extends Node
class_name TechTree

var main_node
var tech_buttons := {}
var tech_config_state := {}

func _init(p_main_node = null):
	main_node = p_main_node

func add_tech_button(button: Button, config: Dictionary):
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

func handle_tech_press(config: Dictionary, button: Button):
	var key = config.get("tech_label", "unknown")
	var cost_key = config.get("cost_key", null)
	var cost_amount = config.get("cost_amount", 0)

	if tech_config_state.get(key, {})["purchased"]:
		return

	if main_node.resources.get(cost_key, 0) < cost_amount:
		print("Not enough ", cost_key)
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
		if main_node.shop.button_dict.has(unlock_key):
			main_node.shop.button_dict[unlock_key]["button"].disabled = false
			print("Unlocked shop button:", unlock_key)

func update_tech_buttons(config_list: Array):
	var start_x = ProjectSettings.get_setting("display/window/size/viewport_width") - 270
	var start_y = 100
	var spacing_y = 50

	for i in range(config_list.size()):
		var config = config_list[i]
		var key = config.get("tech_label", "unknown")

		var b = Button.new()
		b.text = config.get("tech_label", "Tech")

		var local_config = config.duplicate(true)
		tech_config_state[key] = {
			"config": local_config,
			"purchased": false,
			"button": b
		}
		tech_buttons[key] = b
		add_tech_button(b, local_config)
		b.position = Vector2(start_x, start_y + i * spacing_y)
