class_name StaminaRing
extends TextureProgressBar

const FULL_VISIBILITY_EPSILON := 0.001

func set_stamina(current: float, maximum: float) -> void:
	var normalized_value: float = 0.0
	if maximum > 0.0:
		normalized_value = clampf(current / maximum, 0.0, 1.0)

	value = normalized_value
	visible = normalized_value < 1.0 - FULL_VISIBILITY_EPSILON
