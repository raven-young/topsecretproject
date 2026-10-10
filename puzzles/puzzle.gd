class_name Puzzle
extends Node3D
## Base for anything that can be "solved" once per playthrough. Chests sealed
## by a puzzle connect to `solved`.

signal solved

var puzzle_id := ""
var is_solved := false


func _ready() -> void:
	is_solved = GameState.solved_puzzles.has(puzzle_id)


func mark_solved() -> void:
	if is_solved:
		return
	is_solved = true
	GameState.solved_puzzles[puzzle_id] = true
	Events.puzzle_solved.emit(puzzle_id)
	Events.toast.emit("Puzzle solved!")
	solved.emit()
