extends Node

# Original project audio; presentation only, never sent over the network.
const SOUNDS = {
    "click": preload("res://assets/audio/click.wav"),
    "build": preload("res://assets/audio/build.wav"),
    "complete": preload("res://assets/audio/complete.wav"),
    "research": preload("res://assets/audio/research.wav"),
    "scout": preload("res://assets/audio/scout.wav"),
    "alert": preload("res://assets/audio/alert.wav"),
    "season": preload("res://assets/audio/season.wav")
}
var world: Node3D
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var previous_events: Array = []
var observed_sim: RefCounted
var poll_time := 0.0
var effect_cooldown := 0.0
var click_cooldown := 0.0

func setup(scene: Node3D) -> void:
    world = scene
    for bus_name in ["Music", "Ambience", "Effects"]:
        if AudioServer.get_bus_index(bus_name) < 0:
            AudioServer.add_bus()
            var index := AudioServer.bus_count - 1
            AudioServer.set_bus_name(index, bus_name)
            AudioServer.set_bus_send(index, "Master")
    music = loop_player(preload("res://assets/audio/settlement_music.wav"), "Music")
    ambience = loop_player(preload("res://assets/audio/woodland_ambience.wav"), "Ambience")
    for i in range(6):
        var voice := AudioStreamPlayer.new()
        voice.bus = "Effects"
        add_child(voice)
        voices.append(voice)
    observed_sim = world.sim
    previous_events = world.sim.events.duplicate()
    hook_buttons(world)
    get_tree().node_added.connect(func(node: Node): hook_button.call_deferred(node))
    world.apply_audio_volume()
    music.play()
    ambience.play()

func loop_player(source: AudioStreamWAV, bus_name: String) -> AudioStreamPlayer:
    var stream := source.duplicate() as AudioStreamWAV
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.bus = bus_name
    add_child(player)
    return player

func hook_buttons(node: Node) -> void:
    hook_button(node)
    for child in node.get_children(): hook_buttons(child)

func hook_button(node: Node) -> void:
    if not is_instance_valid(node): return
    if node is BaseButton and not node.has_meta("audio_hooked"):
        node.set_meta("audio_hooked", true)
        node.pressed.connect(play_click)

func play_click() -> void:
    if click_cooldown > 0: return
    click_cooldown = 0.07
    play_effect("click")

func play_effect(kind: String) -> void:
    if not SOUNDS.has(kind): return
    for voice in voices:
        if not voice.playing:
            voice.stream = SOUNDS[kind]
            voice.play()
            return

func event_sound(message: String) -> String:
    var text := message.to_lower()
    if "under attack" in text or "battle joined" in text or "starvation" in text or "food needs attention" in text: return "alert"
    if "learned." in text: return "research"
    if "completed" in text or "harvest" in text: return "complete"
    if "scouts" in text or "scouting expedition" in text: return "scout"
    if "commissioned" in text: return "build"
    if "arrived." in text: return "season"
    return ""

func _process(delta: float) -> void:
    click_cooldown = maxf(0, click_cooldown - delta)
    effect_cooldown = maxf(0, effect_cooldown - delta)
    poll_time += delta
    if poll_time < 0.2 or not is_instance_valid(world): return
    poll_time = 0
    if observed_sim != world.sim:
        observed_sim = world.sim
        previous_events = world.sim.events.duplicate()
        return
    var current: Array = world.sim.events
    if current == previous_events: return
    # Find the retained tail, including repeated messages, rather than replaying
    # loaded history. Snapshot updates work for guests as well as the host.
    var new_count := current.size()
    for offset in range(current.size()):
        var remaining := current.size() - offset
        if remaining <= previous_events.size() and current.slice(offset) == previous_events.slice(0, remaining):
            new_count = offset
            break
    var cue := ""
    for i in range(new_count):
        var candidate := event_sound(str(current[i]))
        if candidate == "alert":
            cue = candidate
            break
        if cue.is_empty(): cue = candidate
    previous_events = current.duplicate()
    # Coalesce fast-forward bursts; never build a backlog of sounds.
    if not cue.is_empty() and effect_cooldown <= 0:
        play_effect(cue)
        effect_cooldown = 0.9
