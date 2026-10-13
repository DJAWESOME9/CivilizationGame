extends Node

const Support = preload("res://scripts/update_support.gd")

func _ready() -> void:
    # Mount signed game content before loading any scene or script from the game.
    # The tiny native bootstrap and trusted public key stay in the original app.
    if not OS.has_feature("editor") and FileAccess.file_exists(Support.INSTALLED_PATH):
        var base: Dictionary = Support.release_info()
        var public_key := FileAccess.get_file_as_string(Support.PUBLIC_KEY_PATH)
        var envelope = JSON.parse_string(FileAccess.get_file_as_string(Support.INSTALLED_PATH))
        if envelope is Dictionary:
            var data: Dictionary = Support.authenticate(envelope, public_key)
            var asset: Dictionary = Support.platform_release(data)
            if not asset.is_empty() and data.runtime == base.get("runtime", "") and int(data.build) > int(base.get("build", 0)):
                var path: String = Support.pack_path(int(data.build))
                if Support.pack_matches(path, asset):
                    if not ProjectSettings.load_resource_pack(path, true):
                        push_warning("The downloaded update could not be loaded. Using the bundled game.")
    get_tree().change_scene_to_file.call_deferred("res://main.tscn")
