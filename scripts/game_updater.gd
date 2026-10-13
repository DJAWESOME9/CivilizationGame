extends Node

signal changed
const Support = preload("res://scripts/update_support.gd")
var current: Dictionary = {}
var available: Dictionary = {}
var signed_envelope: Dictionary = {}
var public_key := ""
var status := ""
var busy := false
var checking := false
var ready_to_restart := false
var automatic := true
var request: HTTPRequest
var temporary_path := "user://updates/download.pck.part"
var world: Node3D

func setup(scene: Node3D) -> void:
    world = scene
    current = Support.release_info()
    public_key = FileAccess.get_file_as_string(Support.PUBLIC_KEY_PATH)
    var preferences := ConfigFile.new()
    if preferences.load("user://update_preferences.cfg") == OK:
        automatic = bool(preferences.get_value("updates", "automatic", true))
    request = HTTPRequest.new()
    request.use_threads = true
    request.request_completed.connect(completed)
    add_child(request)
    status = "Version %s" % current.get("version", "unknown")
    if OS.has_feature("editor"):
        status += " · updates apply to packaged games"
    elif automatic:
        check_updates.call_deferred()

func set_automatic(value: bool) -> void:
    automatic = value
    var preferences := ConfigFile.new()
    preferences.set_value("updates", "automatic", automatic)
    preferences.save("user://update_preferences.cfg")
    changed.emit()
    if automatic and not busy and not ready_to_restart: check_updates()

func fail(message: String) -> void:
    busy = false
    checking = false
    status = message
    changed.emit()

func check_updates() -> void:
    if busy or ready_to_restart: return
    if OS.has_feature("editor"):
        fail("Updates apply to packaged games; rebuild this source project to share changes.")
        return
    var url: String = current.get("feed_url", "")
    if not url.begins_with("https://"):
        fail("The update service has not been configured.")
        return
    busy = true
    checking = true
    status = "Checking for updates…"
    request.download_file = ""
    request.timeout = 30
    request.body_size_limit = 128 * 1024
    changed.emit()
    if request.request(url) != OK: fail("Could not check for updates. Try again later.")

func completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        fail("Update check failed. Your current game is still available; try again later." if checking else "Download failed. Your current game is unchanged; try again later.")
        return
    if checking:
        checking = false
        busy = false
        var envelope = JSON.parse_string(body.get_string_from_utf8())
        if not envelope is Dictionary:
            fail("The update service returned invalid release information.")
            return
        var data: Dictionary = Support.authenticate(envelope, public_key)
        if data.is_empty() or Support.platform_release(data).is_empty():
            fail("The update could not be authenticated. Your current game is unchanged.")
            return
        if int(data.build) <= int(current.get("build", 0)):
            fail("You have the latest version · %s" % current.get("version", "unknown"))
            return
        if data.runtime != current.get("runtime", ""):
            fail("This release needs a new app download. See the game's GitHub Releases page.")
            return
        available = data
        signed_envelope = envelope
        status = "Version %s is available." % available.version
        changed.emit()
        if automatic: download_update.call_deferred()
        return
    var asset: Dictionary = Support.platform_release(available)
    if not Support.pack_matches(temporary_path, asset):
        fail("The download did not match the signed release. Your current game is unchanged.")
        return
    var destination: String = Support.pack_path(int(available.build))
    if DirAccess.rename_absolute(temporary_path, destination) != OK:
        fail("Could not store the update. Check available disk space and try again.")
        return
    var manifest := FileAccess.open(Support.INSTALLED_PATH + ".part", FileAccess.WRITE)
    if manifest == null:
        fail("Could not save update information. Your current game is unchanged.")
        return
    manifest.store_string(JSON.stringify(signed_envelope))
    manifest.close()
    if DirAccess.rename_absolute(Support.INSTALLED_PATH + ".part", Support.INSTALLED_PATH) != OK:
        fail("Could not activate the update. Your current game is unchanged.")
        return
    busy = false
    ready_to_restart = true
    status = "Version %s is downloaded. Restart to apply it." % available.version
    world.feedback.text = status + " Open Settings when you are ready."
    changed.emit()

func download_update() -> void:
    if busy or available.is_empty() or ready_to_restart: return
    if DirAccess.make_dir_recursive_absolute("user://updates") != OK:
        fail("Could not create the update folder.")
        return
    busy = true
    checking = false
    status = "Downloading version %s…" % available.version
    request.download_file = temporary_path
    request.timeout = 300
    request.body_size_limit = Support.MAX_PACK_SIZE
    changed.emit()
    var asset: Dictionary = Support.platform_release(available)
    if request.request(asset.url) != OK: fail("Could not start the update download.")

func restart() -> void:
    if not ready_to_restart: return
    if world.session.active or world.session.connecting:
        fail("Leave the shared world before restarting. Hosts should let their friends know.")
        return
    world.sim.save_game()
    var arguments := PackedStringArray(["--"])
    arguments.append_array(OS.get_cmdline_user_args())
    if OS.create_process(OS.get_executable_path(), arguments) < 0:
        fail("Could not restart automatically. Close and reopen the game to apply the update.")
        return
    get_tree().quit()

func _process(_delta: float) -> void:
    if busy and not checking:
        var total := request.get_body_size()
        if total > 0:
            status = "Downloading update · %d%%" % int(100.0 * request.get_downloaded_bytes() / total)
            changed.emit()
