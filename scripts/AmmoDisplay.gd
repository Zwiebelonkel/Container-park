extends PanelContainer

@onready var ammo_value: Label = $MarginContainer/VBoxContainer/AmmoValue
@onready var ammo_bar: ProgressBar = $MarginContainer/VBoxContainer/AmmoBar

func set_ammo(current: int, max_ammo: int) -> void:
	var safe_max := max(max_ammo, 1)
	ammo_value.text = "%d / %d" % [clamp(current, 0, safe_max), safe_max]
	ammo_bar.max_value = safe_max
	ammo_bar.value = clamp(current, 0, safe_max)
