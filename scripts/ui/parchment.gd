extends RefCounted
## Shared, immutable theme resource. New UI also inherits it from gui/theme/custom.
const INK := Color("39251b")
const EDGE := Color("906238")
const CREAM := Color("fff1cf")
const THEME := preload("res://scripts/ui/parchment_theme.tres")

static func make_theme() -> Theme:
	return THEME

static func tag() -> StyleBox:
	return THEME.get_stylebox(&"panel", &"PaperTag")
