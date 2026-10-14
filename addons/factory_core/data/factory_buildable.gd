class_name FactoryBuildable
extends Resource
## Data for one placeable thing (palette entry). Lite has no build mode; use it
## as data for your own builder. Pro's FactoryBuilder turns it into a node.
## kind: &"source", &"belt", &"splitter", &"merger", &"machine", &"sink".

@export var id: StringName
@export var display_name: String = ""
@export var kind: StringName = &"belt"
## Cost, e.g. {&"credits": 10} (Pro: paid through FactoryBuilder's cost hook).
@export var cost: Dictionary[StringName, int] = {}
## Hotbar position (lower first). -1 hides it from the hotbar.
@export var hotbar_slot: int = 0
## Fallback draw colour (debug/fallback renderer and when a skin has no sprite).
@export var color: Color = Color(0.6, 0.6, 0.65)
## machine: recipe id (default).
@export var recipe: StringName = &""
## source: produced item, interval and power.
@export var item: StringName = &""
@export var interval_ticks: int = 30
@export var power_w: int = 0
## belt: speed in sub-units/tick.
@export var speed: int = 8

static func make(p_id: StringName, p_kind: StringName, p_cost: Dictionary[StringName, int], p_slot: int, p_color: Color) -> FactoryBuildable:
	var b: FactoryBuildable = FactoryBuildable.new()
	b.id = p_id
	b.kind = p_kind
	b.cost = p_cost
	b.hotbar_slot = p_slot
	b.color = p_color
	b.display_name = String(p_id).capitalize()
	return b

## Recipe ids this buildable can run (Lite: the single `recipe`).
func recipe_options() -> Array[StringName]:
	return [recipe] as Array[StringName] if recipe != &"" else ([] as Array[StringName])

## Builds a buildable from a JSON dictionary (see examples/data/content.json).
static func from_dict(d: Dictionary) -> FactoryBuildable:
	var b: FactoryBuildable = FactoryBuildable.new()
	b.id = StringName(str(d.get("id", "")))
	b.display_name = str(d.get("name", String(b.id).capitalize()))
	b.kind = StringName(str(d.get("kind", "belt")))
	b.cost = FactoryNode.counts_from_json(d.get("cost", {}))
	b.hotbar_slot = int(d.get("slot", 0))
	b.color = Color(str(d.get("color", "#999aa5")))
	b.item = StringName(str(d.get("item", "")))
	b.interval_ticks = int(d.get("interval_ticks", 30))
	b.power_w = int(d.get("power_w", 0))
	b.speed = int(d.get("speed", 8))
	b.recipe = StringName(str(d.get("recipe", "")))
	return b
