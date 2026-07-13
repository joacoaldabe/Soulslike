extends SceneTree

func _initialize():
	call_deferred("_run")

func _run():
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	for capture in [
		[Vector2i(1280, 720), "res://docs/screenshots/main_menu_1280x720.png"],
		[Vector2i(1920, 1080), "res://docs/screenshots/main_menu_1920x1080.png"],
		[Vector2i(2560, 1080), "res://docs/screenshots/main_menu_ultrawide.png"]
	]:
		root.size = capture[0]
		await process_frame
		await RenderingServer.frame_post_draw
		var texture := root.get_texture()
		if texture == null:
			push_error("MainMenuVisualCapture: el renderer no permite capturas.")
			quit(1)
			return
		var error := texture.get_image().save_png(capture[1])
		if error != OK:
			push_error("MainMenuVisualCapture: no se pudo guardar %s." % capture[1])
			quit(1)
			return
	print("MAIN_MENU_CAPTURES_OK")
	quit(0)
