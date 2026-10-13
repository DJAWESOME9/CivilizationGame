extends Control

var world: Node3D
var nickname: LineEdit
var address: LineEdit
var port: SpinBox
var clock: OptionButton
var ai_count: SpinBox
var ai_difficulty: OptionButton
var ai_help: Label
var resume_world: CheckBox
var status_label: Label
var players_label: Label
var result: Label
var host_button: Button
var join_button: Button
var leave_button: Button
var vote_button: Button
var enter_button: Button
var warfare_page: Control
var timer := 0.0
var trade_partner: OptionButton
var offered_resource: OptionButton
var wanted_resource: OptionButton
var offered_amount: SpinBox
var wanted_amount: SpinBox
var offers_list: ItemList
var trade_result: Label
var send_offer: Button
var accept_offer: Button
var decline_offer: Button
var trade_signature := ""
var player_signature := ""
var pages: TabContainer
var sharing_row: VBoxContainer
var invite_address: LineEdit
var invite_text: LineEdit
var copy_invite: Button

func setup(scene: Node3D) -> void:
    world = scene
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("101b18")
    add_child(background)
    var panel := PanelContainer.new()
    panel.position = Vector2(240, 100)
    panel.size = Vector2(960, 700)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("192820")
    style.border_color = Color("968159")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(28)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var column := VBoxContainer.new()
    var panel_column := column
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)
    var header := HBoxContainer.new()
    column.add_child(header)
    var title: Label = world.label("Create or join an ancient world", 28, Color("eee1bf"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    world.game_button(header, "Back to civilization · Esc", func(): hide())
    column.add_child(world.label("Up to eight civilizations · play with friends · optional AI opponents", 15, Color("b7c9a9")))
    var tabs := TabContainer.new()
    pages = tabs
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(tabs)
    var world_scroll := ScrollContainer.new()
    world_scroll.name = "World"
    world_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(world_scroll)
    column = VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 12)
    world_scroll.add_child(column)
    make_trade_page(tabs)
    warfare_page = preload("res://scripts/warfare_screen.gd").new()
    tabs.add_child(warfare_page)
    warfare_page.setup(world)
    if "--warfare" in OS.get_cmdline_user_args(): tabs.current_tab = 2
    if "--barter" in OS.get_cmdline_user_args(): tabs.current_tab = 1
    column.add_child(HSeparator.new())
    var identity := HBoxContainer.new()
    column.add_child(identity)
    identity.add_child(world.label("Civilization name", 15, Color("ddd2b5")))
    nickname = LineEdit.new()
    nickname.text = "My civilization"
    nickname.max_length = 24
    nickname.custom_minimum_size.x = 240
    identity.add_child(nickname)
    identity.add_child(world.label("UDP port", 15, Color("ddd2b5")))
    port = SpinBox.new()
    port.min_value = 1024
    port.max_value = 65535
    port.value = 24567
    identity.add_child(port)
    var host_row := HBoxContainer.new()
    column.add_child(host_row)
    clock = OptionButton.new()
    clock.add_item("Saved clock / default")
    clock.add_item("1 real day / season")
    clock.add_item("1 real day / year")
    clock.add_item("Testing: day = 10 seconds")
    clock.add_item("Testing: day = 30 seconds")
    clock.tooltip_text = "Host chooses a shared speed, including when resuming. Testing worlds pause while the host is closed."
    host_row.add_child(clock)
    resume_world = CheckBox.new()
    resume_world.text = "Resume saved multiplayer world"
    resume_world.button_pressed = true
    host_row.add_child(resume_world)
    host_button = world.game_button(host_row, "Host world", func():
        if not resume_world.button_pressed and FileAccess.file_exists(world.session.world_save_path):
            var confirm := ConfirmationDialog.new()
            confirm.title = "Replace multiplayer world?"
            confirm.dialog_text = "Create a fresh shared world and replace the saved multiplayer world? Your single-player save is separate."
            confirm.confirmed.connect(func(): host_now(); confirm.queue_free())
            confirm.canceled.connect(func(): confirm.queue_free())
            add_child(confirm)
            confirm.popup_centered()
        else: host_now())
    var ai_row := HBoxContainer.new()
    column.add_child(ai_row)
    ai_row.add_child(world.label("AI opponents", 15, Color("ddd2b5")))
    ai_count = SpinBox.new()
    ai_count.min_value = 0
    ai_count.max_value = world.session.LIMIT - 1
    ai_count.value = 0
    ai_row.add_child(ai_count)
    ai_row.add_child(world.label("Difficulty", 15, Color("ddd2b5")))
    ai_difficulty = OptionButton.new()
    for level in ["Easy", "Normal", "Hard"]: ai_difficulty.add_item(level)
    ai_difficulty.select(1)
    ai_row.add_child(ai_difficulty)
    ai_help = world.label("", 13, Color("9fb398"))
    ai_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(ai_help)
    resume_world.toggled.connect(func(_pressed): refresh())
    ai_count.value_changed.connect(func(_value): refresh())
    ai_difficulty.item_selected.connect(func(_index): refresh())
    var join_row := HBoxContainer.new()
    column.add_child(join_row)
    address = LineEdit.new()
    address.placeholder_text = "Paste an invitation or enter the host address"
    address.custom_minimum_size.x = 520
    join_row.add_child(address)
    join_button = world.game_button(join_row, "Join world", func():
        result.text = world.session.join_game(nickname.text, address.text, int(port.value))
        refresh())
    world.game_button(join_row, "Paste", func(): address.text = DisplayServer.clipboard_get().strip_edges())
    sharing_row = VBoxContainer.new()
    sharing_row.add_theme_constant_override("separation", 8)
    column.add_child(sharing_row)
    sharing_row.add_child(world.label("Invite friends to this world", 18, Color("eee1bf")))
    var share_controls := HBoxContainer.new()
    sharing_row.add_child(share_controls)
    share_controls.add_child(world.label("Reachable host address", 14, Color("ddd2b5")))
    invite_address = LineEdit.new()
    invite_address.placeholder_text = "LAN IP, public IP, or hostname"
    invite_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    share_controls.add_child(invite_address)
    copy_invite = world.game_button(share_controls, "Copy invitation", func():
        var invitation: String = world.session.invitation(invite_address.text)
        if invitation.is_empty():
            result.text = "Enter a host IP address or hostname to share."
            return
        DisplayServer.clipboard_set(invitation)
        result.text = "Invitation copied. Send it to your friends; they paste it into Join world.")
    invite_text = LineEdit.new()
    invite_text.editable = false
    invite_text.tooltip_text = "Copy this invitation and send it to friends. Paste it into the game; it does not open a web page."
    sharing_row.add_child(invite_text)
    var share_help: Label = world.label("Same network: use the local IP below. Internet: enter your reachable public IP or hostname\nand forward this world's UDP port on your router. Keep the host game open.", 13, Color("9fb398"))
    share_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sharing_row.add_child(share_help)
    invite_address.text_changed.connect(func(_text): refresh_invitation())
    status_label = world.label("", 16, Color("d8bd7e"))
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel_column.add_child(status_label)
    column.add_child(HSeparator.new())
    players_label = world.label("", 16, Color("c5d3b8"))
    players_label.custom_minimum_size.y = 200
    column.add_child(players_label)
    var actions := HBoxContainer.new()
    column.add_child(actions)
    enter_button = world.game_button(actions, "Enter civilization", func(): hide())
    vote_button = world.game_button(actions, "Agree to advance up to one season", func(): result.text = world.session.vote_fast_forward())
    leave_button = world.game_button(actions, "Leave world", func(): world.session.leave(); refresh())
    result = world.label("", 14, Color("d9c59c"))
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel_column.add_child(result)
    var instructions: Label = world.label("Host: copy an invitation above and send it to friends. Join: paste it and choose Join world.\nFor a second window on this Mac, launch Multiplayer Guest.command and join 127.0.0.1.\nThe host must remain open for live play. Disconnected civilizations keep working.\nFast-forward needs every human owner's vote; AI opponents do not vote.\nDirect Internet play needs a reachable host/UDP port. Matchmaking is not available yet.", 13, Color("9fb398"))
    instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(instructions)
    visibility_changed.connect(func():
        if visible:
            world.dragging = false
            world.orbiting = false
            refresh())
    hide()
    refresh()

func host_now() -> void:
    result.text = world.session.host_game(nickname.text, int(port.value), [-1.0, 90.0, 360.0, 8640.0, 2880.0][clock.selected], resume_world.button_pressed, int(ai_count.value), ai_difficulty.get_item_text(ai_difficulty.selected))
    refresh()
    if world.session.active:
        invite_address.text = world.session.share_address
        refresh_invitation()
        world.feedback.text = "Shared world opened. Manage your civilization here; Multiplayer opens warfare, barter and world players."
        hide()

func open_warfare() -> void:
    pages.current_tab = 2
    show()

func refresh() -> void:
    var session = world.session
    var busy: bool = session.active or session.connecting
    host_button.disabled = busy
    join_button.disabled = busy
    leave_button.disabled = not busy
    vote_button.disabled = not session.active
    enter_button.disabled = not session.active
    nickname.editable = not busy
    address.editable = not busy
    port.editable = not busy
    clock.disabled = busy
    resume_world.disabled = busy
    sharing_row.visible = session.active and world.multiplayer.is_server()
    refresh_invitation()
    var resuming := resume_world.button_pressed and FileAccess.file_exists(session.world_save_path)
    ai_count.editable = not busy and not resuming
    ai_difficulty.disabled = busy or resuming or ai_count.value == 0
    ai_help.text = "Resuming keeps the saved AI opponents and difficulty. Uncheck Resume to create a new world." if resuming else "AI uses civilization slots. Play alone by hosting; remaining slots allow friends to join. " + ["Easy: slower decisions, cautious raids.", "Normal: balanced development and raids.", "Hard: frequent decisions, earlier and stronger raids."][ai_difficulty.selected]
    status_label.text = session.status
    if session.active:
        var speed_text: String = "Testing · 1 day / %d seconds" % int(86400.0 / session.clock_days) if session.clock_days > 360 else "1 real day / %s" % ("year" if session.clock_days == 360 else "season")
        status_label.text += "\nShared clock: " + speed_text
    refresh_trades()
    var lines := PackedStringArray()
    for player in session.roster:
        if player.get("ai", false):
            lines.append("%s · AI · %s" % [player.name, player.get("difficulty", "Normal")])
            continue
        lines.append("%s · %s · %s" % [player.name, "connected" if player.online else "offline · essential work continues", "agreed to advance" if player.voted else "not voted"])
    players_label.text = "WORLD CIVILIZATIONS · %d / %d slots\n" % [session.roster.size(), session.LIMIT] + ("\n".join(lines) if not lines.is_empty() else "Host a fresh world or resume it. Joining creates your civilization or restores your saved one.\nChoose zero AI opponents to leave all other slots for real people.")

func refresh_invitation() -> void:
    invite_text.text = world.session.invitation(invite_address.text)
    copy_invite.disabled = invite_text.text.is_empty()

func _process(delta: float) -> void:
    if not visible: return
    timer += delta
    if timer >= 0.5:
        timer = 0
        refresh()

func resource_selector(row: HBoxContainer) -> OptionButton:
    var selector := OptionButton.new()
    for resource in ["food", "wood", "stone"]: selector.add_item(resource.capitalize())
    row.add_child(selector)
    return selector

func amount_selector(row: HBoxContainer) -> SpinBox:
    var amount := SpinBox.new()
    amount.min_value = 1
    amount.max_value = 10000
    amount.value = 10
    amount.custom_minimum_size.x = 100
    row.add_child(amount)
    return amount

func make_trade_page(tabs: TabContainer) -> void:
    var page := VBoxContainer.new()
    page.name = "Barter"
    page.add_theme_constant_override("separation", 16)
    tabs.add_child(page)
    page.add_child(world.label("Trade with another civilization", 23, Color("eee1bf")))
    page.add_child(world.label("Offer materials in exchange for what you need. Both players must agree.", 15, Color("b7c9a9")))
    var partner_row := HBoxContainer.new()
    page.add_child(partner_row)
    partner_row.add_child(world.label("Trade partner", 15, Color("ddd2b5")))
    trade_partner = OptionButton.new()
    trade_partner.custom_minimum_size.x = 280
    partner_row.add_child(trade_partner)
    var give_row := HBoxContainer.new()
    page.add_child(give_row)
    give_row.add_child(world.label("You offer", 16, Color("ddd2b5")))
    offered_resource = resource_selector(give_row)
    offered_amount = amount_selector(give_row)
    give_row.add_child(world.label("You request", 16, Color("ddd2b5")))
    wanted_resource = resource_selector(give_row)
    wanted_resource.select(1)
    wanted_amount = amount_selector(give_row)
    send_offer = world.game_button(give_row, "Send offer", func():
        trade_result.text = world.order("offer_trade", [trade_partner.get_selected_id(), ["food", "wood", "stone"][offered_resource.selected], int(offered_amount.value), ["food", "wood", "stone"][wanted_resource.selected], int(wanted_amount.value)]))
    page.add_child(HSeparator.new())
    offers_list = ItemList.new()
    offers_list.custom_minimum_size.y = 220
    offers_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page.add_child(offers_list)
    var actions := HBoxContainer.new()
    page.add_child(actions)
    accept_offer = world.game_button(actions, "Accept selected offer", func(): trade_action("accept_trade"))
    decline_offer = world.game_button(actions, "Decline / cancel selected offer", func(): trade_action("decline_trade"))
    trade_result = world.label("Pending offers appear here. Nothing transfers until an offer is accepted.", 14, Color("d9c59c"))
    trade_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(trade_result)
    page.add_child(world.label("Acceptance checks both stockpiles and storage capacity.
Barter currently transfers directly; caravans, routes and diplomatic contact are future systems.", 13, Color("9fb398")))

func trade_action(action: String) -> void:
    var selected_items := offers_list.get_selected_items()
    if selected_items.is_empty():
        trade_result.text = "Select a pending offer first."
        return
    trade_result.text = world.order(action, [int(offers_list.get_item_metadata(selected_items[0]))])

func refresh_trades() -> void:
    var session = world.session
    var own_slot := int(session.cached_own.get("slot", -1))
    var signature := str(session.roster) + str(own_slot) + str(world.sim.known_civilizations.keys())
    if player_signature != signature:
        player_signature = signature
        var selected_id := trade_partner.get_selected_id()
        trade_partner.clear()
        for player in session.roster:
            if player.slot != own_slot and world.sim.known_civilizations.has(str(int(player.slot))): trade_partner.add_item(player.name, player.slot)
        var previous := trade_partner.get_item_index(selected_id)
        if previous >= 0: trade_partner.select(previous)
    var next_trades := str(session.visible_trades)
    if trade_signature != next_trades:
        trade_signature = next_trades
        var selected_id := -1
        var selected_items := offers_list.get_selected_items()
        if not selected_items.is_empty(): selected_id = int(offers_list.get_item_metadata(selected_items[0]))
        offers_list.clear()
        for offer in session.visible_trades:
            var text := "%s · %s → %s: %d %s for %d %s" % ["RECEIVED" if offer.incoming else "SENT", offer.from_name, offer.to_name, offer.give_amount, offer.give, offer.ask_amount, offer.ask]
            var index := offers_list.add_item(text)
            offers_list.set_item_metadata(index, offer.id)
            if offer.id == selected_id: offers_list.select(index)
    send_offer.disabled = not session.active or trade_partner.item_count == 0
    accept_offer.disabled = not session.active or offers_list.get_selected_items().is_empty()
    decline_offer.disabled = accept_offer.disabled
