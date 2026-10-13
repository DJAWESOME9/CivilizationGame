extends Control

var sim

func _ready() -> void:
    custom_minimum_size = Vector2(64, 54)
    mouse_filter = Control.MOUSE_FILTER_PASS

func refresh(state) -> void:
    sim = state
    var hours: Vector2 = sim.daylight_hours()
    tooltip_text = "World time %s · %s\nSunrise %02d:%02d · Sunset %02d:%02d\nOne rotation per game day. Pausing freezes the cycle." % [sim.time_of_day(), "Night" if sim.is_night() else "Day", int(hours.x), int(fmod(hours.x, 1) * 60), int(hours.y), int(fmod(hours.y, 1) * 60)]
    queue_redraw()

func _draw() -> void:
    if sim == null: return
    var center := Vector2(size.x * 0.5, 22)
    var radius := 19.0
    draw_circle(center, radius + 2, Color("131f2c"))
    draw_arc(center, radius, 0, TAU, 64, Color("49617d"), 3, true)
    var hours: Vector2 = sim.daylight_hours()
    draw_arc(center, radius, hours.x / 24.0 * TAU + PI / 2, hours.y / 24.0 * TAU + PI / 2, 48, Color("d6b779"), 3, true)
    for hour in range(0, 24, 3):
        var angle := hour / 24.0 * TAU + PI / 2
        var direction := Vector2(cos(angle), sin(angle))
        draw_line(center + direction * 13, center + direction * 16, Color("8b9c9d"), 1, true)
    var angle: float = sim.day_phase() * TAU + PI / 2
    var point := center + Vector2(cos(angle), sin(angle)) * radius
    draw_line(center, point, Color("f1e0b1"), 1, true)
    draw_circle(point, 4, Color("bbcfe7") if sim.is_night() else Color("ffe2a0"))
    if sim.is_night(): draw_circle(point + Vector2(2, -1), 3, Color("131f2c"))
    var font := ThemeDB.fallback_font
    var text: String = sim.time_of_day()
    draw_string(font, Vector2(center.x - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x / 2, 53), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e5dfc9"))
