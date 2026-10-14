extends Node3D

# Bake eight irregular oaks once; every tree shares these meshes and materials.
# Two mesh instances per oak keep a large forest affordable without billboards.
static var models: Array = []
static var bark: Array[ShaderMaterial] = []
static var leaves: Array[ShaderMaterial] = []
var palette := 0
var trunk: MeshInstance3D
var canopy: MeshInstance3D

static func branch(tool: SurfaceTool, a: Vector3, b: Vector3, bottom: float, top: float) -> void:
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = bottom
    mesh.top_radius = top
    mesh.height = a.distance_to(b)
    mesh.radial_segments = 7
    var basis := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
    tool.append_from(mesh, 0, Transform3D(basis, (a + b) * 0.5))

static func prepare_models() -> void:
    if not models.is_empty(): return
    for sight in range(2):
        var timber_material := ShaderMaterial.new()
        timber_material.shader = load("res://scripts/tree_bark.gdshader")
        timber_material.set_shader_parameter("sight_strength", 1.0 if sight == 0 else 0.62)
        bark.append(timber_material)
        for color in range(8):
            var leaf_material := ShaderMaterial.new()
            leaf_material.shader = load("res://scripts/tree_leaves.gdshader")
            leaf_material.set_shader_parameter("sight_strength", 1.0 if sight == 0 else 0.62)
            leaf_material.set_shader_parameter("variation", color / 7.0)
            leaves.append(leaf_material)
    var leaf_mesh := SphereMesh.new()
    leaf_mesh.radius = 1
    leaf_mesh.height = 2
    leaf_mesh.radial_segments = 16
    leaf_mesh.rings = 9
    for variant in range(8):
        var random := RandomNumberGenerator.new()
        random.seed = 9017 + variant * 137
        var timber := SurfaceTool.new()
        var crown := SurfaceTool.new()
        timber.begin(Mesh.PRIMITIVE_TRIANGLES)
        crown.begin(Mesh.PRIMITIVE_TRIANGLES)
        var fork := Vector3(random.randf_range(-0.18, 0.18), 2.0, random.randf_range(-0.18, 0.18))
        branch(timber, Vector3(0, -0.12, 0), fork, 0.25, 0.14)
        # Root flares anchor the trunk; limbs spread in all directions.
        for i in range(5):
            var angle := i * TAU / 5.0
            branch(timber, Vector3(cos(angle) * 0.55, 0.01, sin(angle) * 0.55), Vector3(0, 0.65, 0), 0.055, 0.14)
        for i in range(9):
            var angle := i * TAU / 9.0 + random.randf_range(-0.25, 0.25)
            var reach := random.randf_range(0.9, 1.8)
            var elbow := fork + Vector3(cos(angle) * reach * 0.52, random.randf_range(0.35, 0.95), sin(angle) * reach * 0.52)
            var tip := Vector3(cos(angle) * reach, random.randf_range(2.85, 3.75), sin(angle) * reach)
            branch(timber, fork - Vector3(0, random.randf_range(0, 0.55), 0), elbow, 0.11, 0.065)
            branch(timber, elbow, tip, 0.065, 0.025)
            var scale_value := Vector3(random.randf_range(0.8, 1.15), random.randf_range(0.7, 1.05), random.randf_range(0.8, 1.15))
            var basis := Basis.from_euler(Vector3(random.randf_range(-0.3, 0.3), angle, random.randf_range(-0.3, 0.3))).scaled(scale_value * Vector3(0.76, 0.72, 0.76))
            # Three overlapping leaf clusters per branch create an irregular, layered crown.
            crown.append_from(leaf_mesh, 0, Transform3D(basis, tip))
            var outer := tip + Vector3(cos(angle) * 0.62, random.randf_range(-0.3, 0.12), sin(angle) * 0.62)
            crown.append_from(leaf_mesh, 0, Transform3D(Basis.from_euler(Vector3(0.15, angle + 0.6, -0.12)).scaled(scale_value * 0.58), outer))
            var inner := fork.lerp(tip, 0.62) + Vector3(cos(angle + 0.8) * 0.38, 0.15, sin(angle + 0.8) * 0.38)
            crown.append_from(leaf_mesh, 0, Transform3D(Basis.from_euler(Vector3(-0.12, angle, 0.1)).scaled(scale_value * 0.52), inner))
        crown.append_from(leaf_mesh, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.92, 0.82, 0.92)), Vector3(0, 3.5, 0)))
        models.append([timber.commit(), crown.commit()])

func setup(location: Vector3, size_value: float, seed_value: int) -> void:
    prepare_models()
    position = location
    scale = Vector3.ONE * size_value
    var random := RandomNumberGenerator.new()
    random.seed = seed_value
    rotation.y = random.randf_range(0, TAU)
    set_meta("explorable", true)
    var model: Array = models[random.randi_range(0, models.size() - 1)]
    trunk = MeshInstance3D.new()
    trunk.mesh = model[0]
    trunk.material_override = bark[0]
    add_child(trunk)
    canopy = MeshInstance3D.new()
    canopy.mesh = model[1]
    palette = random.randi_range(0, 7)
    canopy.material_override = leaves[palette]
    add_child(canopy)

func set_live_sight(live: bool) -> void:
    trunk.material_override = bark[0 if live else 1]
    canopy.material_override = leaves[palette + (0 if live else 8)]

static func set_season(season: int, next_season: int, blend: float) -> void:
    prepare_models()
    for material in leaves:
        material.set_shader_parameter("season", season)
        material.set_shader_parameter("next_season", next_season)
        material.set_shader_parameter("season_blend", blend)
