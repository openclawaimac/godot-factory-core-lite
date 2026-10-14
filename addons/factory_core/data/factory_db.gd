class_name FactoryDB
extends RefCounted
## Registry of item types and recipes, looked up by id (used by save/load).

var items: Dictionary[StringName, FactoryItem] = {}
var recipes: Dictionary[StringName, FactoryRecipe] = {}
var buildables: Dictionary[StringName, FactoryBuildable] = {}

func add_buildable(b: FactoryBuildable) -> void:
	buildables[b.id] = b

## Buildables with hotbar_slot >= 0, sorted by slot then id.
func hotbar() -> Array[FactoryBuildable]:
	var out: Array[FactoryBuildable] = []
	for k: StringName in buildables:
		if buildables[k].hotbar_slot >= 0:
			out.append(buildables[k])
	out.sort_custom(func(a: FactoryBuildable, b: FactoryBuildable) -> bool:
		return a.hotbar_slot < b.hotbar_slot or (a.hotbar_slot == b.hotbar_slot and String(a.id) < String(b.id)))
	return out

func add_item(it: FactoryItem) -> void:
	items[it.id] = it

func add_recipe(r: FactoryRecipe) -> void:
	recipes[r.id] = r

## Colour for an item id (magenta if unknown).
func color_of(id: StringName) -> Color:
	var it: FactoryItem = items.get(id)
	return it.color if it else Color.MAGENTA

## The loadable .tres name for a directory entry, or "" to skip it. Exported
## games list "x.tres.remap" instead of "x.tres" (web/desktop exports).
static func resource_file(f: String) -> String:
	if f.ends_with(".tres.remap"):
		return f.trim_suffix(".remap")
	return f if f.ends_with(".tres") else ""

## Loads every FactoryItem/FactoryRecipe .tres in `dir` (non-recursive).
func load_dir(dir: String) -> int:
	var n: int = 0
	for f: String in DirAccess.get_files_at(dir):
		var name_: String = resource_file(f)
		if name_ == "":
			continue
		var r: Resource = load(dir.path_join(name_))
		if r is FactoryItem:
			add_item(r); n += 1
		elif r is FactoryRecipe:
			add_recipe(r); n += 1
		elif r is FactoryBuildable:
			add_buildable(r); n += 1
	return n

## Loads items, recipes and buildables from a JSON file:
## {"items": [{"id", "name", "color"}], "recipes": [{"id", "in": {}, "out": {}, "ticks", "power_w"}],
##  "buildables": [{"id", "kind", "cost", "slot", ...}]}. Returns the number loaded (-1 on error).
func load_json(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var v: Variant = JSON.parse_string(f.get_as_text())
	if not (v is Dictionary):
		return -1
	return load_dict(v)

func load_dict(d: Dictionary) -> int:
	var n: int = 0
	for e: Variant in d.get("items", []):
		var ed: Dictionary = e
		add_item(FactoryItem.make(StringName(str(ed["id"])), Color(str(ed.get("color", "#ffffff"))), str(ed.get("name", ""))))
		n += 1
	for e: Variant in d.get("recipes", []):
		var ed: Dictionary = e
		add_recipe(FactoryRecipe.make(StringName(str(ed["id"])), FactoryNode.counts_from_json(ed.get("in", {})),
			FactoryNode.counts_from_json(ed.get("out", {})), int(ed.get("ticks", 60)), int(ed.get("power_w", 100))))
		n += 1
	for e: Variant in d.get("buildables", []):
		add_buildable(FactoryBuildable.from_dict(e))
		n += 1
	return n

## Problems in the loaded data (unknown recipe/item references). Empty = consistent.
func validate() -> Array[String]:
	var errs: Array[String] = []
	for r: FactoryRecipe in recipes.values():
		for k: StringName in r.inputs.keys() + r.outputs.keys():
			if not items.has(k):
				errs.append("recipe %s uses unknown item %s" % [r.id, k])
	for b: FactoryBuildable in buildables.values():
		for r: StringName in b.recipe_options():
			if not recipes.has(r):
				errs.append("buildable %s uses unknown recipe %s" % [b.id, r])
		if b.kind == &"source" and not items.has(b.item):
			errs.append("source %s mines unknown item %s" % [b.id, b.item])
	return errs
