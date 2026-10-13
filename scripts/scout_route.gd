extends Control

var destination := Vector2.ZERO
var party := Vector2.ZERO
var direction := Vector2.ZERO
var return_point := Vector2.ZERO
var camp_radius := 12.0
var departure := Vector2(-4, 0)

func _init() -> void:
    custom_minimum_size = Vector2(556, 150)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_route(target: Vector2, current: Vector2, heading: Vector2, arrival: Vector2, radius: float, start: Vector2) -> void:
    destination = target
    party = current
    direction = heading
    return_point = arrival
    camp_radius = radius
    departure = start
    queue_redraw()

func _draw() -> void:
    var camp := Vector2(-4, 0)
    var lower := Vector2(minf(camp.x - camp_radius, destination.x), minf(camp.y - camp_radius, destination.y))
    var upper := Vector2(maxf(camp.x + camp_radius, destination.x), maxf(camp.y + camp_radius, destination.y))
    var span := upper - lower
    var scale_factor := minf((size.x - 120) / span.x, (size.y - 72) / span.y)
    var midpoint := (upper + lower) * 0.5
    var a := size * 0.5 + (camp - midpoint) * scale_factor
    var b := size * 0.5 + (destination - midpoint) * scale_factor
    var current := size * 0.5 + (party - midpoint) * scale_factor
    var arrival := size * 0.5 + (return_point - midpoint) * scale_factor
    var start := size * 0.5 + (departure - midpoint) * scale_factor
    draw_style_box(route_background(), Rect2(Vector2.ZERO, size))
    draw_circle(a, camp_radius * scale_factor, Color(0.3, 0.5, 0.3, 0.25))
    draw_line(start, b, Color("9d8b65"), 3.0, true)
    draw_circle(a, 6, Color("b6cf9a"))
    draw_circle(b, 6, Color("dec58f"))
    draw_circle(arrival, 5, Color("dec58f"))
    draw_circle(arrival, 3, Color("102018"))
    if not direction.is_zero_approx():
        var forward := direction.normalized()
        var side := Vector2(-forward.y, forward.x)
        var route_start := arrival if direction.dot(destination - camp) < 0 else start
        for fraction in [0.25, 0.75]:
            var tip: Vector2 = route_start.lerp(b, fraction)
            draw_line(tip - forward * 8 + side * 4, tip, Color("dec58f"), 2, true)
            draw_line(tip - forward * 8 - side * 4, tip, Color("dec58f"), 2, true)
    draw_circle(current, 10, Color("16271e"))
    draw_circle(current, 7, Color("8ccbdc"))
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(clampf(a.x - 18, 8, size.x - 50), a.y + 25), "Camp", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b6cf9a"))
    draw_string(font, Vector2(clampf(b.x - 32, 8, size.x - 82), b.y + 25), "Destination", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dec58f"))
    draw_string(font, Vector2(10, 18), "Blue: scouts · green: camp area · gold ring: return point", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8ccbdc"))

func route_background() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("102018")
    style.set_corner_radius_all(4)
    return style
