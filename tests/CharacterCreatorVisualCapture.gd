extends SceneTree

func _initialize():
	call_deferred("_run")

func _run():
	var ui = load("res://scenes/UI.tscn").instantiate()
	root.add_child(ui)
	ui.show_character_creator()
	ui._refresh_class_details(4)
	for capture in [
		[Vector2i(1280, 720), "res://docs/screenshots/character_creator_1280x720.png"],
		[Vector2i(1920, 1080), "res://docs/screenshots/character_creator_1920x1080.png"],
		[Vector2i(2560, 1080), "res://docs/screenshots/character_creator_ultrawide.png"]
	]:
		root.size = capture[0]
		await process_frame
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var texture := root.get_texture()
		if texture == null or texture.get_image().save_png(capture[1]) != OK:
			push_error("CharacterCreatorVisualCapture: no se pudo guardar %s." % capture[1])
			quit(1)
			return
	print("CHARACTER_CREATOR_CAPTURES_OK")
	quit(0)
