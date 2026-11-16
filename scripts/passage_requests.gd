extends Node

var session: Node
var dialog: AcceptDialog
var current: Dictionary = {}
var dismissed: Dictionary = {}
var choice_buttons: Array[Button] = []
var current_world := ""
var timer := 0.0

func setup(owner_session: Node) -> void:
    session = owner_session
    dialog = AcceptDialog.new()
    dialog.name = "ArmyPassageRequest"
    dialog.dialog_autowrap = true
    dialog.get_ok_button().text = "Decide later"
    dialog.confirmed.connect(snooze)
    dialog.canceled.connect(snooze)
    dialog.custom_action.connect(choose)
    add_child(dialog)

func key(item: Dictionary) -> String:
    return "%d:%d:%s" % [int(item.campaign), int(item.request), str(item.incoming)]

func snooze() -> void:
    if not current.is_empty(): dismissed[key(current)] = true
    current = {}
    dialog.hide()

func review() -> void:
    dismissed.clear()
    refresh()
    if current.is_empty(): session.world.feedback.text = "No passage requests or denials are awaiting your decision."

func choose(action: StringName) -> void:
    if current.is_empty(): return
    var args: Array = [int(current.campaign), int(current.request)]
    var command := "passage_wait"
    if action in [&"allow", &"deny"]:
        command = "passage_reply"
        args.append(action == &"allow")
    elif action == &"attack": command = "passage_attack"
    session.world.feedback.text = session.command(command, args)
    snooze()

func _process(delta: float) -> void:
    timer += delta
    if timer < 0.25: return
    timer = 0.0
    refresh()

func refresh() -> void:
    if not session.active or current_world != session.world_id:
        current_world = session.world_id
        dismissed.clear()
        current = {}
        dialog.hide()
    if not session.active: return
    var items: Array = session.cached_own.get("passage_requests", [])
    if not current.is_empty():
        for item in items:
            if key(item) == key(current): return
        current = {}
        dialog.hide()
    for item in items:
        if dismissed.has(key(item)): continue
        current = item
        for button in choice_buttons:
            dialog.remove_button(button)
            button.queue_free()
        choice_buttons.clear()
        if item.incoming:
            dialog.title = "Army passage request"
            dialog.dialog_text = "%s requests permission for %s (%d soldiers) to cross your land. No route around your territory is available.\n\nAllow grants passage to this expedition and its return. If you don't allow it, the army's owner may choose to attack your civilization." % [item.civilization, item.army, int(item.count)]
            choice_buttons.append(dialog.add_button("Allow", false, "allow"))
            choice_buttons.append(dialog.add_button("Don't allow", false, "deny"))
        else:
            dialog.title = "Passage denied"
            dialog.dialog_text = "%s denied passage to %s (%d soldiers). Your army remains stopped.\n\nYou can keep waiting or send orders to attack %s instead of its previous target. Attack orders travel by messenger; other civilizations' borders still apply." % [item.landowner, item.army, int(item.count), item.landowner]
            choice_buttons.append(dialog.add_button("Keep waiting", false, "wait"))
            choice_buttons.append(dialog.add_button("Attack civilization", false, "attack"))
        dialog.popup_centered(Vector2i(620, 260))
        return
