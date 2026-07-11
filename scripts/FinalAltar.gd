extends Area3D

var activated := false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("final_altar")
	_build_visuals()

func interact(_player) -> void:
	if activated or GameState.church_completed:
		get_tree().call_group("ui","notify","El altar ya recibió tu juramento.")
		return
	activated = true
	GameState.complete_church()
	get_tree().call_group("ui","notify","IGLESIA COMPLETADA — Alcanzaste el Altar de la Luz Cenicienta.")

func _build_visuals() -> void:
	var shape=CollisionShape3D.new(); var box=BoxShape3D.new(); box.size=Vector3(5.5,2.6,3.8); shape.shape=box; shape.position.y=1.3; add_child(shape)
	var base=VisualLibrary.tapered(Vector2(2.25,1.15),Vector2(2.6,1.45),1.35,VisualLibrary.material("stone_light"),"HighAltar")
	VisualLibrary.add_part(self,base,Vector3(0,0.68,0))
	for x in [-1.65,1.65]:
		VisualLibrary.add_part(self,VisualLibrary.cylinder(0.18,2.8,VisualLibrary.material("dark_metal"),8,"AltarCandle"),Vector3(x,2.0,0))
		VisualLibrary.add_part(self,VisualLibrary.cylinder(0.10,0.38,VisualLibrary.material("fire"),7,"AltarFlame"),Vector3(x,3.5,0))
	var reliquary=VisualLibrary.tapered(Vector2(0.5,0.35),Vector2(0.8,0.55),1.65,VisualLibrary.material("metal"),"Reliquary")
	VisualLibrary.add_part(self,reliquary,Vector3(0,2.0,0))
