extends ScrollContainer

const IDLE_SECONDS := 3.0
const FADE_SECONDS := 0.2
var idle_seconds := 0.0
var last_pointer := Vector2.INF
var scrollbar: HScrollBar

func _ready() -> void:
    scrollbar = get_h_scroll_bar()
    scrollbar.value_changed.connect(func(_value: float): reveal_scrollbar())

func reveal_scrollbar() -> void:
    idle_seconds = 0.0
    scrollbar.self_modulate.a = 1.0

func _process(delta: float) -> void:
    var pointer := get_global_mouse_position()
    if not is_visible_in_tree():
        last_pointer = pointer
        return
    var over_row := get_global_rect().has_point(pointer)
    var dragging := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and scrollbar.get_global_rect().has_point(pointer)
    if (over_row and pointer != last_pointer) or dragging or scrollbar.has_focus():
        reveal_scrollbar()
    else:
        idle_seconds += delta
        # Keep the scrollbar's layout space and input region, so the row never jumps
        # and a hidden bar can still be revealed and dragged immediately.
        scrollbar.self_modulate.a = clampf(1.0 - (idle_seconds - IDLE_SECONDS) / FADE_SECONDS, 0.0, 1.0)
    last_pointer = pointer
