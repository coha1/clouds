@tool
## Procedural heightmap island terrain.
## Runs in-editor (@tool) so islands are visible in the main scene viewport.
## Change any export property in the inspector to regenerate instantly.
## Extends StaticBody3D — collision is built from the same mesh (backface-safe).
extends StaticBody3D
class_name IslandTerrain


enum Profile {
	DOME,    ## Bell-curve hill — Cove, Grove
	PLATEAU, ## Flat top, sheer edges — Mesa, Bluffs
	PEAK,    ## Sharp central spike — Aerie, Spire
	ATOLL,   ## Raised ring, sunken centre — Lagoon
}


@export_group("Shape")
@export var size: float = 200.0:
	set(v): size = v; _generate()
@export var resolution: int = 48:
	set(v): resolution = v; _generate()
@export var max_height: float = 60.0:
	set(v): max_height = v; _generate()
@export var profile: Profile = Profile.DOME:
	set(v): profile = v; _generate()
@export var shore_falloff: float = 2.0:
	set(v): shore_falloff = v; _generate()
@export var stretch: Vector2 = Vector2(1.0, 1.0):
	set(v): stretch = v; _generate()

@export_group("Noise")
@export var noise_seed: int = 0:
	set(v): noise_seed = v; _generate()
@export var noise_scale: float = 0.006:
	set(v): noise_scale = v; _generate()
@export var noise_strength: float = 0.35:
	set(v): noise_strength = v; _generate()

@export_group("Look")
@export var terrain_color: Color = Color(0.40, 0.55, 0.35, 1.0):
	set(v): terrain_color = v; _generate()


func _ready() -> void:
	_generate()


func _generate() -> void:
	if not is_inside_tree():
		return

	# Remove any previously generated children before rebuilding
	for child in get_children():
		remove_child(child)
		child.free()

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = noise_scale

	var array_mesh: ArrayMesh = _build_mesh(noise)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = terrain_color
	mat.roughness = 0.94
	mesh_instance.set_surface_override_material(0, mat)
	add_child(mesh_instance)
	# Owner must be set for @tool-generated children to appear properly in editor
	if Engine.is_editor_hint():
		mesh_instance.owner = get_tree().edited_scene_root

	var shape: ConcavePolygonShape3D = array_mesh.create_trimesh_shape()
	# Backface collision lets the plane escape if it enters from the wrong side
	shape.backface_collision = true
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	if Engine.is_editor_hint():
		col.owner = get_tree().edited_scene_root


func _build_mesh(noise: FastNoiseLite) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	var half: float = size * 0.5
	var step: float = size / float(resolution)

	# Build height grid first so normals can sample neighbours
	var heights: Array = []
	for row in range(resolution + 1):
		heights.append([])
		for col in range(resolution + 1):
			var wx: float = (-half + col * step) * stretch.x
			var wz: float = (-half + row * step) * stretch.y
			heights[row].append(_height_at(wx, wz, noise))

	# Vertices
	for row in range(resolution + 1):
		for col in range(resolution + 1):
			var wx: float = -half + col * step
			var wz: float = -half + row * step
			verts.append(Vector3(wx, heights[row][col], wz))

	# Smooth normals via finite differences across neighbours
	for row in range(resolution + 1):
		for col in range(resolution + 1):
			var h_l: float = heights[row][max(col - 1, 0)]
			var h_r: float = heights[row][min(col + 1, resolution)]
			var h_d: float = heights[max(row - 1, 0)][col]
			var h_u: float = heights[min(row + 1, resolution)][col]
			var n := Vector3(h_l - h_r, 2.0 * step, h_d - h_u).normalized()
			normals.append(n)

	# Indices — two triangles per quad, counter-clockwise from above so faces point up
	for row in range(resolution):
		for col in range(resolution):
			var tl: int = row * (resolution + 1) + col
			var tr: int = tl + 1
			var bl: int = tl + (resolution + 1)
			var br: int = bl + 1
			indices.append(tl)
			indices.append(tr)
			indices.append(bl)
			indices.append(tr)
			indices.append(br)
			indices.append(bl)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX]  = indices

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


func _height_at(wx: float, wz: float, noise: FastNoiseLite) -> float:
	var dx: float = wx / (size * 0.5 * stretch.x)
	var dz: float = wz / (size * 0.5 * stretch.y)
	var d: float = clampf(sqrt(dx * dx + dz * dz), 0.0, 1.0)

	var profile_h: float = _profile_value(d)

	var n: float = (noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var noised: float = profile_h * (1.0 + (n - 0.5) * 2.0 * noise_strength)
	return maxf(noised, 0.0) * max_height


func _profile_value(d: float) -> float:
	match profile:
		Profile.DOME:
			var raw: float = 1.0 - smoothstep(0.0, 1.0, d)
			return pow(raw, shore_falloff)

		Profile.PLATEAU:
			var flat: float = smoothstep(0.0, 0.35, 1.0 - d)
			var cliff: float = 1.0 - smoothstep(0.55, 1.0, d)
			return pow(minf(flat, cliff), shore_falloff)

		Profile.PEAK:
			return pow(clampf(1.0 - d, 0.0, 1.0), shore_falloff)

		Profile.ATOLL:
			var ring: float = exp(-pow((d - 0.55) / 0.22, 2.0))
			var edge_fade: float = clampf(1.0 - smoothstep(0.72, 1.0, d), 0.0, 1.0)
			return ring * edge_fade

		_:
			return 0.0
