class_name FactoryItem
extends Resource
## An item type. Items on belts and in buffers are referenced by `id` only.

@export var id: StringName
@export var display_name: String = ""
## Fallback draw colour (debug/fallback renderer and when a skin has no sprite).
@export var color: Color = Color.WHITE

static func make(p_id: StringName, p_color: Color, p_name: String = "") -> FactoryItem:
	var it: FactoryItem = FactoryItem.new()
	it.id = p_id
	it.color = p_color
	it.display_name = p_name if p_name != "" else String(p_id).capitalize()
	return it
