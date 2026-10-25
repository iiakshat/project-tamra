class_name Sfx
extends RefCounted
## Gameplay code plays sounds through here, never through the Audio autoload directly,
## so the game still runs (silently) if audio is missing or disabled.


static func play(id: String, pos: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var audio := _audio()
	if audio != null:
		audio.play(id, pos, volume_db, pitch)


static func scene(name: String) -> void:
	var audio := _audio()
	if audio != null and audio.has_method("set_scene_audio"):
		audio.set_scene_audio(name)


static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Audio")
