extends Node3D
class_name GothicChurchLevel

const PLAYABLE_AREA := 7808.0

var enemy_spawns := [
	{"enemy_id":"hollow_sword", "position":Vector3(-6,0,-14)},
	{"enemy_id":"hollow_sword", "position":Vector3(7,0,-22)},
	{"enemy_id":"ash_hound", "position":Vector3(-5,0,-41)},
	{"enemy_id":"spear_guard", "position":Vector3(-5,0,-50)},
	{"enemy_id":"hollow_sword", "position":Vector3(6,0,-62)},
	{"enemy_id":"axe_brute", "position":Vector3(0,0,-75)},
	{"enemy_id":"spear_guard", "position":Vector3(-19,0,-86)},
	{"enemy_id":"ash_hound", "position":Vector3(18,0,-86)},
	{"enemy_id":"hollow_sword", "position":Vector3(-8,0,-96)},
	{"enemy_id":"axe_brute", "position":Vector3(9,0,-99)},
	{"enemy_id":"ash_hound", "position":Vector3(24,0,-107)},
	{"enemy_id":"hollow_sword", "position":Vector3(39,0,-121)},
	{"enemy_id":"spear_guard", "position":Vector3(28,0,-131)},
	{"enemy_id":"hollow_sword", "position":Vector3(4,0,-143)},
	{"enemy_id":"ash_hound", "position":Vector3(-5,0,-151)},
	{"enemy_id":"axe_brute", "position":Vector3(5,0,-162)},
	{"enemy_id":"spear_guard", "position":Vector3(-7,0,-180)},
	{"enemy_id":"hollow_sword", "position":Vector3(7,0,-189)},
	{"enemy_id":"axe_brute", "position":Vector3(-7,0,-194)},
	{"enemy_id":"spear_guard", "position":Vector3(-8,0,-218)},
	{"enemy_id":"ash_hound", "position":Vector3(8,0,-224)},
]

var chest_spawns := [
	{"id":"atrium_offering", "position":Vector3(-10,0,-22), "rotation":20.0, "loot":{"green_estus":2}},
	{"id":"chapel_armory", "position":Vector3(-22,0,-88), "rotation":-90.0, "loot":{"mace":1,"knight_set":1}},
	{"id":"library_archive", "position":Vector3(40,0,-128), "rotation":180.0, "loot":{"stamina_ring":1,"soul_shard":2}},
	{"id":"crypt_reliquary", "position":Vector3(-9,0,-160), "rotation":0.0, "loot":{"winged_spear":1,"life_ring":1}},
	{"id":"sanctuary_tithe", "position":Vector3(11,0,-220), "rotation":-35.0, "loot":{"battle_axe":1,"leather_set":1,"soul_shard":3}},
]

func build() -> void:
	name = "NeoGothicChurch"
	_build_atrium()
	_build_nave()
	_build_transepts()
	_build_cloister_and_library()
	_build_crypt()
	_build_ceremonial_hall()
	_build_sanctuary()
	_build_connectors()

func _floor_room(room_name: String, center: Vector3, size: Vector2) -> void:
	var body = StaticBody3D.new()
	body.name = room_name
	body.position = center
	body.add_to_group("level_room")
	body.set_meta("floor_area", size.x * size.y)
	add_child(body)
	var mesh = VisualLibrary.box(Vector3(size.x,0.22,size.y),VisualLibrary.material("wet_stone"),"Floor")
	VisualLibrary.add_part(body,mesh,Vector3(0,-0.11,0))
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(size.x,0.22,size.y)
	collision.shape = shape
	collision.position.y = -0.11
	body.add_child(collision)
	# Alternating inset slabs preserve the handmade paving language at large scale.
	for x in range(int(-size.x * 0.5) + 2, int(size.x * 0.5) - 1, 4):
		var strip = VisualLibrary.box(Vector3(0.055,0.018,size.y-1.0),VisualLibrary.material("stone_dark"),"PavingJoint")
		VisualLibrary.add_part(body,strip,Vector3(x,0.012,0))

func _wall(position: Vector3, size: Vector3, material := "stone") -> void:
	var body = StaticBody3D.new()
	body.position = position
	add_child(body)
	var mesh = VisualLibrary.tapered(Vector2(size.x*0.48,size.z*0.48),Vector2(size.x*0.51,size.z*0.51),size.y,VisualLibrary.material(material),"GothicWall")
	body.add_child(mesh)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _room_walls(center: Vector3, size: Vector2, openings: Dictionary = {}) -> void:
	var h := 7.0
	var t := 0.8
	# Openings are full wall gaps centered on a side; segmented walls keep navigation explicit.
	_side_walls(center,size,"north",float(openings.get("north",0.0)),h,t)
	_side_walls(center,size,"south",float(openings.get("south",0.0)),h,t)
	_side_walls(center,size,"west",float(openings.get("west",0.0)),h,t)
	_side_walls(center,size,"east",float(openings.get("east",0.0)),h,t)

func _side_walls(center: Vector3, size: Vector2, side: String, gap: float, h: float, t: float) -> void:
	var horizontal := side in ["north","south"]
	var length := size.x if horizontal else size.y
	var offset := Vector3(0, h*0.5, (-size.y if side=="north" else size.y)*0.5) if horizontal else Vector3((-size.x if side=="west" else size.x)*0.5,h*0.5,0)
	if gap <= 0.0:
		_wall(center+offset,Vector3(length,h,t) if horizontal else Vector3(t,h,length))
		return
	var segment := (length-gap)*0.5
	if horizontal:
		_wall(center+offset+Vector3(-(gap+segment)*0.5,0,0),Vector3(segment,h,t))
		_wall(center+offset+Vector3((gap+segment)*0.5,0,0),Vector3(segment,h,t))
	else:
		_wall(center+offset+Vector3(0,0,-(gap+segment)*0.5),Vector3(t,h,segment))
		_wall(center+offset+Vector3(0,0,(gap+segment)*0.5),Vector3(t,h,segment))

func _build_atrium() -> void:
	_floor_room("Atrium",Vector3(0,0,-14),Vector2(28,28))
	_room_walls(Vector3(0,0,-14),Vector2(28,28),{"south":8.0,"north":8.0})
	for x in [-10.5,-3.5,3.5,10.5]: _column(Vector3(x,0,-8),5.2,false)
	for p in [Vector3(-10,0,-19),Vector3(9,0,-7),Vector3(8,0,-24)]: _rubble(p)
	_arch(Vector3(0,0,-28),8.0)

func _build_nave() -> void:
	_floor_room("Nave",Vector3(0,0,-59),Vector2(24,62))
	_room_walls(Vector3(0,0,-59),Vector2(24,62),{"south":8.0,"north":9.0})
	for z in range(-38,-84,-9):
		_column(Vector3(-9,0,z),6.2,false); _column(Vector3(9,0,z),6.2,z==-74)
		_bench(Vector3(-4.5,0,z-3)); _bench(Vector3(4.5,0,z-3))
	for z in [-44,-62,-78]: _chandelier(Vector3(0,5.7,z))

func _build_transepts() -> void:
	_floor_room("Transepts",Vector3(0,0,-92),Vector2(60,24))
	_room_walls(Vector3(0,0,-92),Vector2(60,24),{"south":9.0,"north":8.0,"east":7.0})
	for x in [-24,-16,16,24]: _column(Vector3(x,0,-92),5.5,false)
	_statue(Vector3(-24,0,-98),0.0); _statue(Vector3(24,0,-98),0.0)
	_small_altar(Vector3(-25,0,-84)); _small_altar(Vector3(25,0,-84))

func _build_cloister_and_library() -> void:
	_floor_room("Cloister",Vector3(32,0,-119),Vector2(32,32))
	_room_walls(Vector3(32,0,-119),Vector2(32,32),{"south":7.0,"north":7.0,"west":7.0})
	for x in [21.0,27.0,37.0,43.0]:
		_column(Vector3(x,0,-108),4.6,false); _column(Vector3(x,0,-130),4.6,false)
	_floor_room("Library",Vector3(32,0,-143),Vector2(28,16))
	_room_walls(Vector3(32,0,-143),Vector2(28,16),{"south":7.0})
	for x in [22.0,27.0,37.0,42.0]: _bookshelf(Vector3(x,0,-145))

func _build_crypt() -> void:
	_floor_room("Crypt",Vector3(0,-0.8,-151),Vector2(28,38))
	_room_walls(Vector3(0,-0.8,-151),Vector2(28,38),{"south":8.0,"north":8.0})
	for z in [-140,-150,-160]:
		_sarcophagus(Vector3(-8,-0.8,z)); _sarcophagus(Vector3(8,-0.8,z))
	for p in [Vector3(-11,-0.8,-136),Vector3(11,-0.8,-136),Vector3(-11,-0.8,-166),Vector3(11,-0.8,-166)]: _candelabrum(p)

func _build_ceremonial_hall() -> void:
	_floor_room("CeremonialHall",Vector3(0,0,-184),Vector2(30,30))
	_room_walls(Vector3(0,0,-184),Vector2(30,30),{"south":8.0,"north":10.0})
	for x in [-11.0,11.0]:
		for z in [-175.0,-184.0,-193.0]: _column(Vector3(x,0,z),6.5,false)
	_arch(Vector3(0,0,-199),10.0)

func _build_sanctuary() -> void:
	_floor_room("GrandSanctuary",Vector3(0,0,-218),Vector2(34,34))
	_room_walls(Vector3(0,0,-218),Vector2(34,34),{"south":10.0})
	for x in [-13.0,-7.0,7.0,13.0]: _column(Vector3(x,0,-213),7.5,false)
	_rose_window(Vector3(0,7.0,-235.4))
	for x in [-9.0,9.0]: _statue(Vector3(x,0,-230),180.0)

func _build_connectors() -> void:
	_corridor("AtriumToNave",Vector3(0,0,-29),Vector2(8,4))
	_corridor("TranseptToCloister",Vector3(31,0,-102),Vector2(7,8))
	_corridor("CloisterToCrypt",Vector3(16,0,-135),Vector2(32,7))
	_corridor("CryptToHall",Vector3(0,-0.4,-170),Vector2(8,8))
	_corridor("HallToSanctuary",Vector3(0,0,-201),Vector2(10,4))

func _corridor(label: String, center: Vector3, size: Vector2) -> void:
	_floor_room(label,center,size)
	# Only long sides are closed so connected rooms remain open.
	if size.x >= size.y:
		_wall(center+Vector3(-size.x*0.5,3,0),Vector3(0.7,6,size.y)); _wall(center+Vector3(size.x*0.5,3,0),Vector3(0.7,6,size.y))
	else:
		_wall(center+Vector3(0,3.0,-size.y*0.5),Vector3(size.x,6,0.7)); _wall(center+Vector3(0,3.0,size.y*0.5),Vector3(size.x,6,0.7))

func _column(position: Vector3, height: float, broken: bool) -> void:
	var actual := height*(0.62 if broken else 1.0)
	var body = StaticBody3D.new(); body.position=position+Vector3.UP*actual*0.5; add_child(body)
	body.add_child(VisualLibrary.cylinder(0.48,actual,VisualLibrary.material("stone_light"),8,"Column"))
	for y in [-actual*0.48,actual*0.48]: VisualLibrary.add_part(body,VisualLibrary.tapered(Vector2(0.42,0.42),Vector2(0.65,0.65),0.24,VisualLibrary.material("stone"),"Capital"),Vector3(0,y,0))
	var collision=CollisionShape3D.new(); var shape=CylinderShape3D.new(); shape.radius=0.52; shape.height=actual; collision.shape=shape; body.add_child(collision)

func _arch(position: Vector3, width: float) -> void:
	for i in range(9):
		var angle=lerp(18.0,162.0,float(i)/8.0); var rad=deg_to_rad(angle)
		var part=VisualLibrary.tapered(Vector2(0.38,0.55),Vector2(0.48,0.65),0.9,VisualLibrary.material("stone_light"),"PointedArch")
		VisualLibrary.add_part(self,part,position+Vector3(cos(rad)*width*0.48,3.0+sin(rad)*3.6,0),Vector3(90,0,-angle+90))

func _bench(position: Vector3) -> void:
	var root=Node3D.new(); root.position=position; add_child(root)
	VisualLibrary.add_part(root,VisualLibrary.box(Vector3(3.3,0.16,0.85),VisualLibrary.material("wood"),"PewSeat"),Vector3(0,0.65,0))
	VisualLibrary.add_part(root,VisualLibrary.box(Vector3(3.3,1.1,0.14),VisualLibrary.material("wood"),"PewBack"),Vector3(0,1.05,0.38),Vector3(-8,0,0))
	for x in [-1.45,1.45]: VisualLibrary.add_part(root,VisualLibrary.box(Vector3(0.16,0.72,0.72),VisualLibrary.material("dark_metal"),"PewLeg"),Vector3(x,0.35,0))

func _statue(position: Vector3, yaw: float) -> void:
	var root=Node3D.new(); root.position=position; root.rotation_degrees.y=yaw; add_child(root)
	VisualLibrary.add_part(root,VisualLibrary.tapered(Vector2(0.6,0.5),Vector2(0.9,0.7),0.55,VisualLibrary.material("stone_dark"),"Plinth"),Vector3(0,0.28,0))
	VisualLibrary.add_part(root,VisualLibrary.tapered(Vector2(0.38,0.25),Vector2(0.65,0.45),1.8,VisualLibrary.material("stone_light"),"SaintRobe"),Vector3(0,1.42,0))
	VisualLibrary.add_part(root,VisualLibrary.cylinder(0.30,0.52,VisualLibrary.material("stone_light"),8,"SaintHead"),Vector3(0,2.52,0))

func _small_altar(position: Vector3) -> void:
	VisualLibrary.add_part(self,VisualLibrary.tapered(Vector2(1.5,0.65),Vector2(1.7,0.8),1.25,VisualLibrary.material("stone_light"),"SideAltar"),position+Vector3.UP*0.63)

func _bookshelf(position: Vector3) -> void:
	var root=Node3D.new(); root.position=position; add_child(root)
	VisualLibrary.add_part(root,VisualLibrary.box(Vector3(3.4,3.2,0.55),VisualLibrary.material("wood"),"Bookcase"),Vector3(0,1.6,0))
	for y in [0.65,1.45,2.25]: VisualLibrary.add_part(root,VisualLibrary.box(Vector3(3.1,0.09,0.68),VisualLibrary.material("dark_metal"),"Shelf"),Vector3(0,y,0))

func _sarcophagus(position: Vector3) -> void:
	VisualLibrary.add_part(self,VisualLibrary.tapered(Vector2(0.75,1.35),Vector2(0.95,1.55),0.72,VisualLibrary.material("stone_dark"),"Sarcophagus"),position+Vector3.UP*0.36)
	VisualLibrary.add_part(self,VisualLibrary.tapered(Vector2(0.7,1.3),Vector2(0.82,1.42),0.22,VisualLibrary.material("stone_light"),"SarcophagusLid"),position+Vector3.UP*0.82)

func _candelabrum(position: Vector3) -> void:
	VisualLibrary.add_part(self,VisualLibrary.cylinder(0.06,1.8,VisualLibrary.material("dark_metal"),7,"Candelabrum"),position+Vector3.UP*0.9)
	for x in [-0.35,0.0,0.35]: VisualLibrary.add_part(self,VisualLibrary.cylinder(0.055,0.35,VisualLibrary.material("fire"),6,"Candle"),position+Vector3(x,1.75,0))

func _chandelier(position: Vector3) -> void:
	VisualLibrary.add_part(self,VisualLibrary.cylinder(0.75,0.10,VisualLibrary.material("dark_metal"),10,"Chandelier"),position,Vector3(90,0,0))
	VisualLibrary.add_part(self,VisualLibrary.cylinder(0.025,1.6,VisualLibrary.material("dark_metal"),6,"Chain"),position+Vector3.UP*0.8)

func _rose_window(position: Vector3) -> void:
	var glass=StandardMaterial3D.new(); glass.albedo_color=Color("354657"); glass.emission_enabled=true; glass.emission=Color("243746"); glass.emission_energy_multiplier=0.5
	VisualLibrary.add_part(self,VisualLibrary.cylinder(3.6,0.18,VisualLibrary.material("stone_dark"),12,"RoseFrame"),position,Vector3(90,0,0))
	VisualLibrary.add_part(self,VisualLibrary.cylinder(3.0,0.20,glass,12,"RoseGlass"),position+Vector3(0,0,0.1),Vector3(90,0,0))
	for angle in range(0,180,30): VisualLibrary.add_part(self,VisualLibrary.box(Vector3(0.12,6.0,0.24),VisualLibrary.material("dark_metal"),"RoseMullion"),position+Vector3(0,0,0.22),Vector3(0,0,angle))

func _rubble(position: Vector3) -> void:
	for i in range(5):
		var size=Vector3(0.35+i*0.07,0.24+(i%2)*0.12,0.42)
		VisualLibrary.add_part(self,VisualLibrary.tapered(Vector2(size.x*0.42,size.z*0.42),Vector2(size.x*0.55,size.z*0.55),size.y,VisualLibrary.material("stone_dark"),"Rubble"),position+Vector3((i-2)*0.34,size.y*0.5,(i%2)*0.3),Vector3(8*i,17*i,9*i))
