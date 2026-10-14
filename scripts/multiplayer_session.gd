extends Node

const AIOpponent = preload("res://scripts/ai_opponent.gd")
const Warfare = preload("res://scripts/warfare.gd")
var warfare = Warfare.new()
var visible_campaigns: Array = []

const Simulation = preload("res://scripts/simulation.gd")
const UpdateSupport = preload("res://scripts/update_support.gd")
var world_save_path := "user://multiplayer_world.json"
# Godot does not accept Array.size() calls in constant expressions.
# Keep this capacity aligned with the sixteen starting sites in Warfare.SITES.
const LIMIT: int = 16
const PROTOCOL_VERSION := 2
const AI_NAMES := ["Oakborn", "Stonevale", "Riverfolk", "Ashfield", "Pinewatch", "Sunmere", "Greycliff"]
var host_port := 24567
var share_address := ""
var world_id := ""
var expected_world_id := ""
var world: Node3D
var active := false
var connecting := false
var status := "Single-player · host or join a shared world."
var civilizations: Dictionary = {}
var peer_tokens: Dictionary = {}
var own_token := ""
var player_name := ""
var solo_sim
var world_day := 0.0
var clock_days := 90.0
var publish_timer := 0.0
var persist_timer := 0.0
var connect_timer := 0.0
var joining_address := ""
var joining_port := 24567
var transport_connected := false
var votes: Dictionary = {}
var last_commands: Dictionary = {}
var roster: Array = []
var cached_own: Dictionary = {}
var trade_offers: Array = []
var visible_trades: Array = []
var next_offer := 1

func setup(scene: Node3D) -> void:
    world = scene
    if "--guest-profile" in OS.get_cmdline_user_args(): world_save_path = "user://guest_multiplayer_world.json"
    var identity := ConfigFile.new()
    var identity_path := "user://guest_multiplayer_identity.cfg" if "--guest-profile" in OS.get_cmdline_user_args() else "user://multiplayer_identity.cfg"
    identity.load(identity_path)
    own_token = identity.get_value("player", "token", "")
    if own_token.is_empty():
        own_token = Crypto.new().generate_random_bytes(24).hex_encode()
        identity.set_value("player", "token", own_token)
        if "--capture" not in OS.get_cmdline_user_args(): identity.save(identity_path)
    multiplayer.connected_to_server.connect(connected)
    multiplayer.connection_failed.connect(func(): leave(connection_help()))
    multiplayer.server_disconnected.connect(func(): leave("Host disconnected. Your civilization remains in the host's world save."))
    multiplayer.peer_disconnected.connect(disconnected)

func host_game(nickname: String, port: int, days: float, resume: bool, ai_count: int = 0, ai_difficulty: String = "Normal", ai_mix: Dictionary = {}) -> String:
    if active or connecting: return "Leave the current session first."
    var levels: Array[String] = []
    if ai_mix.is_empty():
        if ai_count < 0 or ai_count >= LIMIT or ai_difficulty not in AIOpponent.DIFFICULTIES:
            return "Choose up to %d AI opponents with Easy, Medium or Hard difficulty." % (LIMIT - 1)
        for i in range(ai_count): levels.append(ai_difficulty)
    else:
        var total := 0
        for level in ai_mix:
            if level not in AIOpponent.DIFFICULTIES or not ai_mix[level] is int or ai_mix[level] < 0:
                return "Choose whole, nonnegative counts for Easy, Medium and Hard AI."
            total += int(ai_mix[level])
            if total >= LIMIT: return "Choose at most %d AI opponents total; reserve one slot for the host." % (LIMIT - 1)
        for level in ["Easy", "Normal", "Hard"]:
            for i in range(int(ai_mix.get(level, 0))): levels.append(level)
    if port < 1024 or port > 65535: return "Choose a port between 1024 and 65535."
    var resumed := resume and FileAccess.file_exists(world_save_path)
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(port, LIMIT - 1)
    if error != OK:
        return "Could not host on UDP port %d (%s). Another game may already be hosting there. In a second window, choose Join world; otherwise close the other host or choose a different port and copy a new invitation." % [port, error_string(error)]
    solo_sim = world.sim
    civilizations.clear()
    peer_tokens.clear()
    votes.clear()
    trade_offers.clear()
    next_offer = 1
    warfare.campaigns.clear()
    warfare.next_campaign = 1
    world_day = 0
    world_id = Crypto.new().generate_random_bytes(16).hex_encode()
    clock_days = 90.0 if days < 0 else days
    if resume and FileAccess.file_exists(world_save_path):
        var data = JSON.parse_string(FileAccess.get_file_as_string(world_save_path))
        if not data is Dictionary or data.get("version", 0) != 1 or not data.has_all(["day", "clock", "civilizations", "saved_at"]) or not data.civilizations is Dictionary:
            peer.close()
            solo_sim = null
            return "The multiplayer save could not be read. It has been preserved; choose a fresh world explicitly to replace it."
        if data is Dictionary and data.get("version", 0) == 1:
            world_day = float(data.day)
            world_id = str(data.get("world_id", world_id))
            clock_days = float(data.clock)
            trade_offers = data.get("trade_offers", [])
            next_offer = int(data.get("next_offer", 1))
            warfare.campaigns = data.get("campaigns", [])
            warfare.next_campaign = int(data.get("next_campaign", 1))
            for token in data.civilizations:
                var record: Dictionary = data.civilizations[token]
                var simulation = Simulation.new()
                simulation.save_path = ""
                simulation.restore_snapshot(record.state)
                simulation.shared_region = true
                var site: Vector2 = Warfare.SITES[int(record.slot)]
                simulation.world_origin = [site.x + 4.0, site.y]
                civilizations[token] = {"name": record.name, "sim": simulation, "slot": record.slot, "ai": record.get("ai", false), "difficulty": record.get("difficulty", "Normal"), "next_decision": record.get("next_decision", world_day), "next_raid": record.get("next_raid", world_day + 90), "next_trade": record.get("next_trade", world_day), "relationships": record.get("relationships", {})}
            var elapsed := maxf(0, Time.get_unix_time_from_system() - float(data.saved_at)) / 86400.0 * clock_days
            # Accelerated testing runs only while the host is open.
            # Do not simulate months of unintended catch-up after closing.
            if clock_days <= 360.0: advance_world(elapsed)
    if not civilizations.has(own_token) and civilizations.size() >= LIMIT:
        peer.close()
        solo_sim = null
        return "This world already has %d civilizations. Use its original host profile or create a new world." % LIMIT
    if days >= 0: clock_days = days
    for record in civilizations.values(): record.sim.days_per_real_day = clock_days
    multiplayer.multiplayer_peer = peer
    active = true
    player_name = nickname.strip_edges().left(24)
    peer_tokens[1] = own_token
    ensure_civilization(own_token, player_name)
    if not resumed:
        for i in range(levels.size()):
            var difficulty: String = levels[i]
            var token := "ai_%d" % i
            ensure_civilization(token, AI_NAMES[i % AI_NAMES.size()] + (" %d" % (floori(float(i) / AI_NAMES.size()) + 1) if i >= AI_NAMES.size() else ""))
            civilizations[token].merge({"ai": true, "difficulty": difficulty, "next_decision": world_day, "next_raid": AIOpponent.DIFFICULTIES[difficulty].peace_days})
    world.sim = civilizations[own_token].sim
    world.running = true
    var addresses := PackedStringArray()
    for address in IP.get_local_addresses():
        if ":" not in address and not address.begins_with("127.") and not address.begins_with("169.254."):
            addresses.append(address)
    status = "Hosting · %s · UDP %d" % [", ".join(addresses) if not addresses.is_empty() else "127.0.0.1", port]
    host_port = port
    share_address = addresses[0] if not addresses.is_empty() else "127.0.0.1"
    world_changed()
    update_world_intel()
    publish()
    persist()
    return status

func join_game(nickname: String, address: String, port: int) -> String:
    if active or connecting: return "Leave the current session first."
    if address.strip_edges().is_empty(): return "Enter the host's address."
    expected_world_id = ""
    address = address.strip_edges()
    if address.begins_with("civilization://"):
        var invitation := parse_invitation(address)
        if invitation.has("error"): return invitation.error
        address = invitation.address
        port = invitation.port
        expected_world_id = invitation.world
    if port < 1024 or port > 65535: return "Choose a port between 1024 and 65535."
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address.strip_edges(), port)
    if error != OK: return "Could not connect: " + error_string(error)
    solo_sim = world.sim
    player_name = nickname.strip_edges().left(24)
    multiplayer.multiplayer_peer = peer
    connecting = true
    connect_timer = 0
    joining_address = address
    joining_port = port
    transport_connected = false
    status = "Connecting to %s:%d…" % [address, port]
    return status

func connected() -> void:
    transport_connected = true
    connect_timer = 0
    register_player.rpc_id(1, own_token, player_name, PROTOCOL_VERSION, expected_world_id, int(UpdateSupport.release_info().get("build", 0)))
    status = "Connected · waiting for your civilization…"

func connection_help() -> String:
    if transport_connected:
        return "Reached %s:%d, but the host did not finish loading your civilization. Use the same game build on both computers and ask the host to check its game log." % [joining_address, joining_port]
    return "Could not reach %s on UDP port %d. The host must choose Host world and stay open. On this Mac use Multiplayer Guest.command and join 127.0.0.1. On the same Wi-Fi use the host's LAN address and allow the game through its firewall; guest Wi-Fi may block players. Over the Internet use a public address with UDP port forwarding; a local invitation alone cannot connect across networks." % [joining_address, joining_port]

func ensure_civilization(token: String, nickname: String) -> void:
    if civilizations.has(token): return
    var simulation = Simulation.new()
    simulation.save_path = ""
    var site: Vector2 = Warfare.SITES[civilizations.size()]
    simulation.world_origin = [site.x + 4.0, site.y]
    simulation.shared_region = true
    # Late arrivals start fresh at the shared date, without simulating missed years.
    simulation.day = world_day
    simulation.days_per_real_day = clock_days
    simulation.tick(0)
    civilizations[token] = {"name": nickname if not nickname.is_empty() else "Civilization %d" % (civilizations.size() + 1), "sim": simulation, "slot": civilizations.size()}

@rpc("any_peer", "call_remote", "reliable")
func register_player(token: String, nickname: String, protocol: int = -1, invited_world: String = "", build: int = -1) -> void:
    if not active or not multiplayer.is_server(): return
    var sender := multiplayer.get_remote_sender_id()
    if peer_tokens.has(sender): return
    if protocol != PROTOCOL_VERSION:
        reject_join.rpc_id(sender, "Different multiplayer versions. Update both games to the same build.")
        return
    if build != int(UpdateSupport.release_info().get("build", 0)):
        reject_join.rpc_id(sender, "Different game builds. Open Settings and update both games before joining.")
        return
    if not invited_world.is_empty() and invited_world != world_id:
        reject_join.rpc_id(sender, "This invitation belongs to another world. Ask the host for a new invitation.")
        return
    if token.length() != 48 or not token.is_valid_hex_number(false):
        reject_join.rpc_id(sender, "Invalid player identity.")
        return
    if civilizations.has(token) and civilizations[token].get("ai", false):
        reject_join.rpc_id(sender, "This civilization is controlled by AI.")
        return
    if token in peer_tokens.values():
        reject_join.rpc_id(sender, "That player profile is already connected.")
        return
    if not civilizations.has(token) and civilizations.size() >= LIMIT:
        reject_join.rpc_id(sender, "This world already contains %d civilizations. Disconnected civilizations still occupy their saved slots." % LIMIT)
        return
    ensure_civilization(token, nickname.strip_edges().left(24))
    peer_tokens[sender] = token
    votes.clear()
    update_world_intel()
    publish()
    persist()

@rpc("authority", "call_remote", "reliable")
func reject_join(reason: String) -> void:
    leave(reason)

func disconnected(peer_id: int) -> void:
    if not active or not multiplayer.is_server(): return
    peer_tokens.erase(peer_id)
    last_commands.erase(peer_id)
    votes.clear()
    publish()
    persist()

func advance_world(days: float) -> void:
    # All civilizations consume, produce, age and research over the same elapsed interval.
    var remaining := days
    while remaining > 0:
        var step := minf(remaining, 1.0)
        for token in civilizations:
            if civilizations[token].get("ai", false): AIOpponent.decide(self, token)
        for record in civilizations.values(): record.sim.advance(step)
        world_day += step
        advance_trades()
        warfare.advance(self, step)
        update_world_intel()
        remaining -= step

func command(action: String, args: Array = []) -> String:
    if connecting: return "Wait for the shared world to connect."
    if not active: return apply_command(world.sim, action, args)
    if multiplayer.is_server():
        var response := player_command(own_token, action, args)
        publish()
        return response
    submit_command.rpc_id(1, action, args)
    return "Order sent to the host."

@rpc("any_peer", "call_remote", "reliable")
func submit_command(action: String, args: Array) -> void:
    if not active or not multiplayer.is_server(): return
    var sender := multiplayer.get_remote_sender_id()
    if not peer_tokens.has(sender): return
    var now := Time.get_ticks_msec()
    var rate: Dictionary = last_commands.get(sender, {"start": now, "count": 0})
    if now - int(rate.start) >= 1000: rate = {"start": now, "count": 0}
    rate.count += 1
    last_commands[sender] = rate
    if rate.count > 100:
        command_result.rpc_id(sender, "Too many orders at once. Please try again.")
        return
    var response := player_command(peer_tokens[sender], action, args)
    command_result.rpc_id(sender, response)
    publish()

func apply_command(simulation, action: String, args: Array) -> String:
    if action in ["recruit", "army_plan", "disband", "defense", "appoint", "create_army", "rename_army", "assign_defense", "reserve_army", "resize_army", "form_army", "compose_army"]:
        return Warfare.army_order(simulation, action, args)
    if action in ["raid", "attack", "raze", "recall", "messenger"]: return "Join a shared world to launch an expedition."
    match action:
        "assign":
            if args.size() != 2 or args[0] not in simulation.JOBS or not args[1] is int: return "Invalid workforce order."
            simulation.assign(args[0], args[1])
        "target":
            if args.size() != 3 or args[0] not in simulation.JOBS or not args[1] is int or not args[2] is bool: return "Invalid priority order."
            simulation.set_target(args[0], args[1], args[2])
        "research":
            if args.size() != 2 or args[0] not in simulation.TECHNOLOGIES or not args[1] is bool: return "Unknown technology."
            return simulation.choose_research(args[0], args[1])
        "dismantle":
            if args.size() != 1 or not args[0] is String or not simulation.STARTING_OBJECTS.has(args[0]): return "Invalid dismantling order."
            return simulation.order_dismantle(args[0])
        "build":
            if args.size() != 3 or args[0] not in simulation.BUILDINGS or not args[1] is int or not args[2] is int: return "Invalid building order."
            return simulation.order_build(args[0], args[1], args[2])
        "scout":
            if args.size() != 1 or not args[0] is Vector2 or not args[0].is_finite(): return "Invalid scout destination."
            return simulation.send_scouts(args[0])
        "train":
            if args.size() != 1 or args[0] not in simulation.JOBS: return "Invalid profession."
            return simulation.start_training(args[0])
        "civic":
            if args.size() != 2 or not args[0] is String: return "Invalid civic order."
            return simulation.enact_civic(args[0], args[1])
        "policy":
            if args.size() != 2 or args[0] not in ["allow_migration", "allow_births", "automatic_workforce", "emergency_food"] or not args[1] is bool: return "Invalid policy."
            if args[0] == "allow_births": return "Use the Town Hall birth policy."
            simulation.set(args[0], args[1])
            if args[0] == "automatic_workforce" and args[1]: simulation.apply_targets()
        "rations":
            if args.size() != 1 or args[0] not in [0.5, 1.0, 1.25]: return "Invalid ration policy."
            simulation.ration_level = args[0]
            simulation.announce("Ration policy changed.")
        _: return "Unknown order."
    simulation.tick(0)
    simulation.prepare_roster(simulation.effective_assignments())
    return "Order applied."

@rpc("authority", "call_remote", "reliable")
func command_result(message: String) -> void:
    world.feedback.text = message
    if world.research_screen.visible: world.research_screen.result.text = message
    if world.population_screen.visible: world.population_screen.response.text = message
    if world.object_panel.visible: world.object_panel.field_response.text = message
    if world.multiplayer_screen.visible:
        world.multiplayer_screen.trade_result.text = message
        world.multiplayer_screen.warfare_page.response.text = message

func vote_fast_forward() -> String:
    if not active: return "Join a world first."
    if multiplayer.is_server(): record_vote(1)
    else: request_vote.rpc_id(1)
    return "Vote recorded for a one-season advance."

@rpc("any_peer", "call_remote", "reliable")
func request_vote() -> void:
    if active and multiplayer.is_server(): record_vote(multiplayer.get_remote_sender_id())

func record_vote(peer_id: int) -> void:
    if not peer_tokens.has(peer_id): return
    votes[peer_tokens[peer_id]] = true
    # Disconnected human owners must reconnect and agree too.
    var human_count := 0
    for record in civilizations.values():
        if not record.get("ai", false): human_count += 1
    if votes.size() == human_count and peer_tokens.size() == human_count:
        for i in range(90):
            var stop := false
            for record in civilizations.values():
                if record.sim.resources.food <= 0.001: stop = true
            if stop: break
            var previous_reports: Array = []
            var previous_conditions: Array = []
            for record in civilizations.values():
                previous_reports.append(record.sim.report_revision)
                previous_conditions.append(record.sim.conditions.duplicate())
            var previous_war: int = warfare.revision
            advance_world(1)
            if warfare.revision != previous_war: stop = true
            var index := 0
            for record in civilizations.values():
                if record.sim.report_revision != previous_reports[index] or record.sim.conditions != previous_conditions[index]: stop = true
                index += 1
            if stop: break
        for record in civilizations.values(): record.sim.announce("Agreed world advance completed; important events can stop the jump early.")
        votes.clear()
        persist()
    publish()

func publish() -> void:
    if not active or not multiplayer.is_server(): return
    roster.clear()
    for token in civilizations:
        var record: Dictionary = civilizations[token]
        roster.append({"name": record.name, "slot": record.slot, "online": token in peer_tokens.values(), "voted": votes.has(token), "ai": record.get("ai", false), "difficulty": record.get("difficulty", "Normal")})
    for peer_id in peer_tokens:
        var token: String = peer_tokens[peer_id]
        var state: Dictionary = civilizations[token].sim.snapshot()
        state["slot"] = civilizations[token].slot
        state["civilization_name"] = civilizations[token].name
        state["trade_offers"] = offers_for(token)
        state["relationships"] = relationships_for(token)
        state["visiting_scouts"] = visiting_scouts(token)
        state["campaigns"] = warfare.public_campaigns(self, token)
        state["food_ledger"] = civilizations[token].sim.food_ledger
        state["daily_food_change"] = civilizations[token].sim.daily_food_change
        if peer_id == 1:
            cached_own = state
            visible_trades = state.trade_offers
            visible_campaigns = state.campaigns
        else: receive_world.rpc_id(peer_id, state, roster, world_day, clock_days)
    world.running = true

@rpc("authority", "call_remote", "reliable")
func receive_world(state: Dictionary, players: Array, day: float, days: float) -> void:
    var first_connection := not active
    if not active:
        active = true
        connecting = false
        world.sim = Simulation.new()
        world.sim.save_path = ""
    world.sim.restore_snapshot(state)
    world.sim.food_ledger = state.get("food_ledger", world.sim.food_ledger)
    world.sim.daily_food_change = state.get("daily_food_change", 0.0)
    roster = players
    world_day = day
    clock_days = days
    world.running = true
    cached_own = state
    visible_trades = state.get("trade_offers", [])
    visible_campaigns = state.get("campaigns", [])
    status = "Connected · your civilization · world running"
    if first_connection:
        world_changed()
        world.feedback.text = "Connected to the shared world. Manage your civilization here; Multiplayer opens warfare, barter and world players."
        world.multiplayer_screen.hide()

func world_changed() -> void:
    world.build_choice = ""
    world.visual_revision = -1
    world.configure_world_map()
    world.exploration.invalidate()
    world.citizens.sync_people()
    world.refresh_game()

func persist() -> void:
    if not active or not multiplayer.is_server(): return
    var records: Dictionary = {}
    for token in civilizations:
        var record: Dictionary = civilizations[token]
        records[token] = {"name": record.name, "slot": record.slot, "state": record.sim.snapshot(), "ai": record.get("ai", false), "difficulty": record.get("difficulty", "Normal"), "next_decision": record.get("next_decision", world_day), "next_raid": record.get("next_raid", world_day), "next_trade": record.get("next_trade", world_day), "relationships": record.get("relationships", {})}
    var file := FileAccess.open(world_save_path, FileAccess.WRITE)
    if file: file.store_string(JSON.stringify({"version": 1, "world_id": world_id, "day": world_day, "clock": clock_days, "civilizations": records, "trade_offers": trade_offers, "next_offer": next_offer, "campaigns": warfare.campaigns, "next_campaign": warfare.next_campaign, "saved_at": Time.get_unix_time_from_system()}))

func invitation(address: String) -> String:
    if not active or not multiplayer.is_server(): return ""
    address = address.strip_edges()
    if address.is_empty() or "/" in address or " " in address: return ""
    return "civilization://join?address=%s&port=%d&protocol=%d&world=%s" % [address.uri_encode(), host_port, PROTOCOL_VERSION, world_id]

static func parse_invitation(value: String) -> Dictionary:
    if not value.begins_with("civilization://join?"): return {"error": "Paste a complete Civilization invitation or enter a host address."}
    var fields: Dictionary = {}
    for pair in value.trim_prefix("civilization://join?").split("&"):
        var parts := pair.split("=", true, 1)
        if parts.size() != 2 or fields.has(parts[0]): return {"error": "This invitation is incomplete or invalid."}
        fields[parts[0]] = parts[1].uri_decode()
    if not fields.has_all(["address", "port", "protocol", "world"]): return {"error": "This invitation is incomplete."}
    if fields.protocol != str(PROTOCOL_VERSION): return {"error": "This invitation uses a different multiplayer version. Update both games."}
    if not fields.port.is_valid_int() or int(fields.port) < 1024 or int(fields.port) > 65535: return {"error": "This invitation has an invalid port."}
    if fields.address.is_empty() or "/" in fields.address or " " in fields.address: return {"error": "This invitation has an invalid host address."}
    if fields.world.length() != 32 or not fields.world.is_valid_hex_number(false): return {"error": "This invitation has an invalid world identity."}
    return {"address": fields.address, "port": int(fields.port), "world": fields.world}

func leave(message: String = "Left the world. Returned to single-player.") -> void:
    persist()
    if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    active = false
    connecting = false
    transport_connected = false
    civilizations.clear()
    peer_tokens.clear()
    roster.clear()
    votes.clear()
    trade_offers.clear()
    visible_trades.clear()
    warfare.campaigns.clear()
    visible_campaigns.clear()
    if solo_sim != null:
        world.sim = solo_sim
        solo_sim = null
    world.running = false
    status = message
    world_changed()

func _process(delta: float) -> void:
    if connecting:
        connect_timer += delta
        if connect_timer > 15: leave(connection_help())
    if not active or not multiplayer.is_server(): return
    advance_world(delta / 86400.0 * clock_days)
    publish_timer += delta
    persist_timer += delta
    if publish_timer >= 0.5:
        publish_timer = 0
        publish()
    if persist_timer >= 15:
        persist_timer = 0
        persist()

# Relationships are each AI's opinion of a specific civilization, never global reputation.
func relationship(ai_token: String, other: String) -> Dictionary:
    var records: Dictionary = civilizations[ai_token].get("relationships", {})
    var score := int(records.get(other, {}).get("score", 0))
    var label := "Neutral"
    var chance := 60
    if score <= -60:
        label = "Hostile"
        chance = 15
    elif score <= -20:
        label = "Unfriendly"
        chance = 35
    elif score >= 60:
        label = "Trusted"
        chance = 95
    elif score >= 20:
        label = "Friendly"
        chance = 80
    return {"score": score, "status": label, "chance": chance}

func relationships_for(token: String) -> Dictionary:
    var result: Dictionary = {}
    var known: Dictionary = civilizations[token].sim.known_civilizations
    for other in civilizations:
        var record: Dictionary = civilizations[other]
        if other != token and known.has(str(int(record.slot))):
            var opinion := relationship(other, token)
            opinion.erase("chance")
            result[str(int(record.slot))] = opinion
    return result

func change_relationship(ai_token: String, other: String, amount: int, trade: bool = false) -> void:
    var records: Dictionary = civilizations[ai_token].get("relationships", {})
    var entry: Dictionary = records.get(other, {"score": 0, "last_trade_day": -1})
    # Several tiny offers in one day cannot build unlimited trust.
    if trade:
        if int(entry.get("last_trade_day", -1)) == floori(world_day): return
        entry["last_trade_day"] = floori(world_day)
    entry["score"] = clampi(int(entry.get("score", 0)) + amount, -100, 100)
    records[other] = entry
    civilizations[ai_token]["relationships"] = records

func offers_for(token: String) -> Array:
    var offers: Array = []
    for offer in trade_offers:
        if offer.from == token or offer.to == token:
            offers.append({"id": offer.id, "incoming": offer.to == token, "from_name": civilizations[offer.from].name, "to_name": civilizations[offer.to].name, "give": offer.give, "give_amount": offer.give_amount, "ask": offer.ask, "ask_amount": offer.ask_amount, "stage": offer.get("stage", "Awaiting decision")})
    return offers

func ready_scout_guard(token: String, army_id: int = -1) -> Dictionary:
    for army in civilizations[token].sim.armies:
        if army_id >= 0 and int(army.id) != army_id: continue
        if army.status == "Ready" and not army.get("reserve", false) and not army.soldiers.is_empty(): return army
    return {}

func visiting_scouts(token: String) -> Array:
    var result: Array = []
    var home = civilizations[token].sim
    var origin := Vector2(home.world_origin[0], home.world_origin[1])
    for other in civilizations:
        if other == token: continue
        var sender = civilizations[other].sim
        var offset := Vector2(sender.world_origin[0], sender.world_origin[1]) - origin
        for mission in sender.scout_missions:
            if not home.has_home_influence(sender.mission_position(mission) + offset): continue
            result.append({"slot": int(civilizations[other].slot), "name": civilizations[other].name, "started": mission.started, "units": mission.units.duplicate(), "trade": mission.has("trade_id")})
    return result

func kill_visiting_scouts(token: String, slot: int, started: float, units: Array, army_id: int = -1) -> String:
    var guard := ready_scout_guard(token, army_id)
    if guard.is_empty(): return "Choose a ready, formed army at home to attack visiting scouts."
    var home = civilizations[token].sim
    for other in civilizations:
        if other == token or int(civilizations[other].slot) != slot: continue
        var sender = civilizations[other].sim
        var offset := Vector2(sender.world_origin[0], sender.world_origin[1]) - Vector2(home.world_origin[0], home.world_origin[1])
        for mission in sender.scout_missions:
            if float(mission.started) != started or mission.units != units: continue
            if not home.has_home_influence(sender.mission_position(mission) + offset): return "These scouts have left your civilization's influence."
            deposit_trade_cargo(home, mission.get("cargo", {}))
            for person in sender.people.duplicate():
                if int(person.id) in mission.units: sender.people.erase(person)
            sender.population = sender.people.size()
            sender.scout_missions.erase(mission)
            sender.scout_mission = sender.scout_missions[0] if not sender.scout_missions.is_empty() else {}
            sender.clamp_assignments()
            for offer in trade_offers.duplicate():
                if offer.from == other and int(offer.id) == int(mission.get("trade_id", -1)): trade_offers.erase(offer)
            change_relationship(other, token, -40)
            change_relationship(token, other, -40)
            sender.announce(civilizations[token].name + " used an army to kill your visiting scouts.")
            home.announce(str(guard.name) + " killed visiting scouts from " + civilizations[other].name + ". Cargo seized within storage capacity; relations deteriorated.")
            persist()
            return "Visiting scouts killed by " + str(guard.name) + "; relations damaged."
    return "This scouting party is no longer present."

func player_command(token: String, action: String, args: Array) -> String:
    if action == "attack_scouts":
        if args.size() != 4 or not args[0] is int or not (args[1] is float or args[1] is int) or not args[2] is Array or not args[3] is int or int(args[3]) < 0: return "Choose visiting scouts and a ready army."
        return kill_visiting_scouts(token, args[0], float(args[1]), args[2], args[3])
    if action == "army_plan" and args.size() in [5, 7] and args[0] is int:
        var army := Warfare.find_army(civilizations[token].sim, args[0])
        if army.get("status", "") in ["Marching", "Holding", "Returning", "Fighting", "Raiding"]:
            var response := warfare.send_messenger(self, token, args[0], "Plan", args.slice(1))
            persist()
            return response
    if action == "messenger":
        if args.size() != 3 or not args[0] is int or not args[1] is String or not args[2] is Array: return "Invalid messenger order."
        var response := warfare.send_messenger(self, token, args[0], args[1], args[2])
        persist()
        return response
    if action in ["raid", "attack", "raze"]:
        if args.size() not in [2, 3] or not args[0] is int or not args[1] is int: return "Choose an army and target."
        if action == "raze" and (args.size() != 3 or not args[2] is bool): return "Choose whether to destroy buildings."
        var response := warfare.launch(self, token, args[0], args[1], "Attack" if action == "attack" else "Raze" if action == "raze" else "Raid", bool(args[2]) if args.size() == 3 else false)
        votes.clear()
        persist()
        return response
    if action == "recall":
        if args.size() != 1 or not args[0] is int: return "Choose an army to recall."
        var response := warfare.send_messenger(self, token, args[0], "Return")
        persist()
        return response
    if action == "offer_trade":
        if args.size() != 5 or not args[0] is int or args[1] not in ["food", "wood", "stone"] or args[3] not in ["food", "wood", "stone"] or not args[2] is int or not args[4] is int: return "Invalid barter offer."
        if args[2] <= 0 or args[4] <= 0 or args[2] > 10000 or args[4] > 10000: return "Choose positive trade amounts."
        var target := ""
        for candidate in civilizations:
            if civilizations[candidate].slot == args[0]: target = candidate
        if target.is_empty() or target == token: return "Choose another civilization."
        if not civilizations[token].sim.known_civilizations.has(str(args[0])): return "Send scouts to discover that civilization before offering barter."
        var own_offers := 0
        for offer in trade_offers:
            if offer.from == token: own_offers += 1
        if own_offers >= 4: return "You already have four pending offers. Cancel one first."
        if civilizations[token].sim.resources[args[1]] < args[2]: return "You do not have the offered resources."
        var sender = civilizations[token].sim
        var destination: Vector2 = Warfare.SITES[int(civilizations[target].slot)] - Vector2(sender.world_origin[0], sender.world_origin[1])
        var blocked: String = sender.scouting_block(destination)
        if not blocked.is_empty(): return blocked
        var provisions: int = sender.scout_food_cost(destination)
        if args[1] == "food" and sender.resources.food < args[2] + provisions: return "Not enough food for both cargo and the scouting party."
        sender.send_scouts(destination)
        var mission: Dictionary = sender.scout_missions.back()
        mission["trade_id"] = next_offer
        mission["trade_waiting"] = true
        mission["cargo"] = {str(args[1]): int(args[2])}
        sender.resources[args[1]] -= args[2]
        trade_offers.append({"id": next_offer, "from": token, "to": target, "give": args[1], "give_amount": args[2], "ask": args[3], "ask_amount": args[4], "stage": "Traveling"})
        next_offer += 1
        persist()
        return "Three settlers departed with the offered cargo. The recipient decides when they arrive."
    if action in ["accept_trade", "decline_trade", "seize_trade"]:
        if args.size() != 1 or not args[0] is int: return "Choose a pending offer."
        for offer in trade_offers:
            if offer.id != args[0]: continue
            if token not in [offer.from, offer.to]: return "This offer belongs to another civilization."
            var sender = civilizations[offer.from].sim
            var receiver = civilizations[offer.to].sim
            var mission := trade_mission(offer)
            if token == offer.from and action != "decline_trade": return "Only the receiving civilization can decide."
            if token == offer.to and offer.get("stage", "Awaiting decision") != "Awaiting decision": return "The scouting party has not arrived."
            if action == "seize_trade":
                if mission.is_empty(): return "No trade party is present."
                return kill_visiting_scouts(token, int(civilizations[offer.from].slot), float(mission.started), mission.units)
            elif action == "accept_trade":
                if receiver.resources[offer.ask] < offer.ask_amount: return "Not enough resources to pay for this trade."
                var total: float = receiver.resources.food + receiver.resources.wood + receiver.resources.stone - offer.ask_amount + offer.give_amount
                if total > receiver.capacity(): return "Not enough storage for the offered cargo."
                if mission.is_empty():
                    # Pending offers from older saves have no reserved cargo or traveling party.
                    trade_offers.erase(offer)
                    return "Legacy offer expired. Please send a new scouting party."
                receiver.resources[offer.ask] -= offer.ask_amount
                receiver.resources[offer.give] += offer.give_amount
                mission.cargo = {str(offer.ask): offer.ask_amount}
                release_trade_party(mission)
                if offer.give != offer.ask:
                    change_relationship(offer.to, offer.from, 5, true)
                    change_relationship(offer.from, offer.to, 5, true)
                sender.announce(civilizations[offer.to].name + " accepted your trade. Scouts are bringing payment home.")
                receiver.announce("Trade accepted. Relations improve.")
            else:
                if not mission.is_empty(): release_trade_party(mission)
                sender.announce("Trade declined or canceled; scouts return with their cargo.")
            trade_offers.erase(offer)
            persist()
            return "Trade scouts killed; cargo seized and relations damaged." if action == "seize_trade" else "Trade resolved. Scouts return home with their cargo."
        return "This offer is no longer available."
    return apply_command(civilizations[token].sim, action, args)

func update_world_intel() -> void:
    for token in civilizations:
        var record: Dictionary = civilizations[token]
        var simulation = record.sim
        var origin := Vector2(simulation.world_origin[0], simulation.world_origin[1])
        simulation.army_sights.clear()
        for campaign in warfare.campaigns:
            if campaign.attacker == token:
                var point: Vector2 = warfare.campaign_point(campaign) - origin
                simulation.army_sights.append([point.x, point.y])
                simulation.reveal_land(point, 5)
        for campaign in warfare.campaigns:
            if campaign.phase != "Fighting" or not campaign.has("battle"): continue
            if campaign.attacker != token and campaign.defender != token: continue
            var home = civilizations[campaign.defender].sim
            var battle_offset := Vector2(home.world_origin[0], home.world_origin[1]) - origin
            var side := 0 if campaign.attacker == token else 1
            for fighter in campaign.battle.fighters:
                if int(fighter.side) != side or fighter.hp <= 0 or fighter.state == "Escaped": continue
                var sight := Vector2(fighter.point[0], fighter.point[1]) + battle_offset
                simulation.army_sights.append([sight.x, sight.y])
                simulation.reveal_land(sight, 5)
        for other in civilizations:
            if other == token: continue
            var target_record: Dictionary = civilizations[other]
            var point: Vector2 = Warfare.SITES[int(target_record.slot)] - origin
            if not simulation.has_live_sight(point): continue
            var key := str(int(target_record.slot))
            if not simulation.known_civilizations.has(key):
                simulation.announce("Scouts discovered " + target_record.name + ". Contact and military targeting are now available.")
                simulation.report_revision += 1
            simulation.known_civilizations[key] = {"name": target_record.name, "slot": target_record.slot, "point": [point.x, point.y], "last_seen": world_day, "population": target_record.sim.population, "buildings": target_record.sim.buildings.duplicate(true), "arrow_slits": "Arrow Slits" in target_record.sim.technologies, "inhabitants": visible_inhabitants(target_record.sim)}
        for campaign in warfare.campaigns:
            var point: Vector2 = warfare.campaign_point(campaign) - origin
            var key := str(int(campaign.id))
            if campaign.attacker == token or not simulation.has_live_sight(point): continue
            var observed: Dictionary = warfare.campaign_view(self, campaign, token)
            observed.point = [point.x, point.y]
            observed.last_seen = world_day
            if not simulation.known_armies.has(key):
                simulation.announce("Enemy army spotted near (%.0f, %.0f). Send scouts to identify its troops and commander." % [point.x, point.y])
                simulation.report_revision += 1
            observed.erase("scene")
            simulation.known_armies[key] = observed
        # A searched last-known position clears an enemy marker if the army has moved away.
        for key in simulation.known_armies.keys():
            var remembered: Dictionary = simulation.known_armies[key]
            var old_point := Vector2(remembered.point[0], remembered.point[1])
            if not simulation.has_live_sight(old_point): continue
            var present := false
            for campaign in warfare.campaigns:
                if int(campaign.id) == int(key) and simulation.has_live_sight(warfare.campaign_point(campaign) - origin): present = true
            if not present: simulation.known_armies.erase(key)

func visible_inhabitants(simulation) -> Array:
    var result: Array = []
    simulation.prepare_roster(simulation.effective_assignments())
    var roles: Dictionary = {}
    for job in simulation.JOBS:
        for person in simulation.job_roster[job]: roles[int(person.id)] = job
    for army in simulation.armies:
        if army.status not in ["Ready", "Training", "Recovering"]: continue
        for id in army.soldiers: roles[int(id)] = Warfare.soldier_unit(army, int(id))
    var absent: Array = simulation.scouting_units() + simulation.emergency_defenders
    for army in simulation.armies:
        if army.status not in ["Ready", "Training", "Recovering"]: absent.append_array(army.soldiers)
    # Show home troops even in large towns; representatives remain bounded.
    for person in simulation.people:
        if int(person.id) in absent or roles.get(int(person.id), "") not in ["Militia", "Spearmen", "Archers"]: continue
        result.append({"id": int(person.id), "job": roles[int(person.id)], "age": float(person.age)})
        if result.size() >= 24: break
    var army_figures := result.size()
    for person in simulation.people:
        if int(person.id) in absent or roles.get(int(person.id), "") in ["Militia", "Spearmen", "Archers"]: continue
        result.append({"id": int(person.id), "job": roles.get(int(person.id), "Resting"), "age": float(person.age)})
        if result.size() >= army_figures + 48: break
    return result

func trade_mission(offer: Dictionary) -> Dictionary:
    for mission in civilizations[offer.from].sim.scout_missions:
        if int(mission.get("trade_id", -1)) == int(offer.id): return mission
    return {}

func release_trade_party(mission: Dictionary) -> void:
    mission.trade_waiting = false
    mission.surveyed = true
    mission.survey_days = 0.0
    # Cancellation on the outward journey turns the party around at its current position.
    if float(mission.progress) < float(mission.travel):
        var simulation_position: Vector2 = Vector2(mission.origin[0], mission.origin[1]).lerp(Vector2(mission.destination[0], mission.destination[1]), float(mission.progress) / float(mission.travel))
        mission.destination = [simulation_position.x, simulation_position.y]
        mission.travel = maxf(0.001, float(mission.progress))
    mission.progress = mission.travel

func deposit_trade_cargo(simulation, cargo: Dictionary) -> void:
    for resource in cargo:
        var room: float = maxf(0, simulation.capacity() - simulation.resources.food - simulation.resources.wood - simulation.resources.stone)
        var stored: float = minf(room, float(cargo[resource]))
        simulation.resources[resource] += stored
        if stored < float(cargo[resource]): simulation.announce("Trade cargo exceeded storage; excess was lost.")

func advance_trades() -> void:
    for offer in trade_offers.duplicate():
        var mission := trade_mission(offer)
        if mission.is_empty():
            trade_offers.erase(offer)
            continue
        if offer.get("stage", "Traveling") == "Traveling" and float(mission.progress) >= float(mission.travel):
            offer.stage = "Awaiting decision"
            civilizations[offer.to].sim.announce("Trade scouts arrived from " + civilizations[offer.from].name + ". Open Barter to accept, decline or seize their cargo.")
