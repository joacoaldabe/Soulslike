extends Node

enum StartMode { NONE, NEW_GAME, LOAD_GAME }

var start_mode := StartMode.NONE
var pending_save_data = null

func request_new_game() -> bool:
	if not SaveManager.delete_save():
		return false
	GameState.reset_runtime_state()
	Inventory.clear_all()
	pending_save_data = null
	start_mode = StartMode.NEW_GAME
	return true

func request_load_game() -> bool:
	var data = SaveManager.load_game()
	if data == null:
		return false
	GameState.reset_runtime_state()
	Inventory.clear_all()
	pending_save_data = data
	start_mode = StartMode.LOAD_GAME
	return true

func take_pending_save():
	var data = pending_save_data
	pending_save_data = null
	start_mode = StartMode.NONE
	return data

func finish_new_game_start():
	start_mode = StartMode.NONE
