class_name WorldGen
extends RefCounted
## Seeded terrain. Same seed + preset -> identical map. 1 cell = CELL metres.

const N := 256
const CELL := 200.0
const SIZE := N * CELL
enum Biome { SEA, PLAIN, FOREST, MOUNTAIN, VALLEY }
const BIOME_NAMES := ["Sea", "Plain", "Forest", "Mountain", "Valley"]
const TREES := [0.0, 0.05, 0.8, 0.35, 0.5]  # canopy density per biome
const PRESETS := {
	"Mixed": {"relief": 1600.0, "sea": 0.30, "ridge": 0.35, "tilt": 0.0, "freq": 1.0},
	"Highlands": {"relief": 2200.0, "sea": 0.12, "ridge": 0.6, "tilt": 0.0, "freq": 1.2},
	"Coastal": {"relief": 1200.0, "sea": 0.30, "ridge": 0.25, "tilt": 0.5, "freq": 0.9},
	"Plains": {"relief": 600.0, "sea": 0.18, "ridge": 0.1, "tilt": 0.0, "freq": 0.7},
}

var seed_value := 0
var heights := PackedFloat32Array()
var biomes := PackedByteArray()
var max_elev := 1.0


static func _noise(s: int, f: float, oct: int, ft: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = f
	n.fractal_type = ft
	n.fractal_octaves = oct
	return n


func generate(p_seed: int, preset: String) -> void:
	seed_value = p_seed
	var cfg: Dictionary = PRESETS[preset]
	var relief: float = cfg.relief
	var sea: float = cfg.sea
	var ridge_w: float = cfg.ridge
	var tilt: float = cfg.tilt
	var base := _noise(p_seed, 0.010 * float(cfg.freq), 5, FastNoiseLite.FRACTAL_FBM)
	var ridge := _noise(p_seed + 1, 0.018, 3, FastNoiseLite.FRACTAL_RIDGED)
	var moist := _noise(p_seed + 2, 0.02, 3, FastNoiseLite.FRACTAL_FBM)
	heights.resize(N * N)
	biomes.resize(N * N)
	max_elev = 1.0
	for y in N:
		for x in N:
			var b := clampf(base.get_noise_2d(x, y) * 0.9 + 0.5, 0.0, 1.0)
			var r := clampf(ridge.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)
			var h := clampf(b + (r - 0.5) * ridge_w - tilt * float(x) / N * 0.6, 0.0, 1.0)
			var i := y * N + x
			if h <= sea:
				heights[i] = 0.0
				biomes[i] = Biome.SEA
				continue
			var e := (h - sea) / (1.0 - sea) * relief
			heights[i] = e
			max_elev = maxf(max_elev, e)
			var bm := Biome.PLAIN
			if e > relief * 0.55:
				bm = Biome.MOUNTAIN
			elif r < 0.32 and e < relief * 0.4:
				bm = Biome.VALLEY
			elif moist.get_noise_2d(x, y) > 0.0:
				bm = Biome.FOREST
			biomes[i] = bm


func elev_at(p: Vector2) -> float:
	var fx := clampf(p.x / CELL, 0.0, N - 1.001)
	var fy := clampf(p.y / CELL, 0.0, N - 1.001)
	var x0 := int(fx)
	var y0 := int(fy)
	var i := y0 * N + x0
	var a := lerpf(heights[i], heights[i + 1], fx - x0)
	var b := lerpf(heights[i + N], heights[i + N + 1], fx - x0)
	return lerpf(a, b, fy - y0)


func biome_at(p: Vector2) -> int:
	var x := clampi(int(p.x / CELL), 0, N - 1)
	var y := clampi(int(p.y / CELL), 0, N - 1)
	return biomes[y * N + x]


func tree_density(p: Vector2) -> float:
	var b := biome_at(p)
	if b == Biome.MOUNTAIN and elev_at(p) > max_elev * 0.75:
		return 0.0  # above the tree line
	return TREES[b]


## Radio/optical line of sight over terrain, with 4/3-earth curvature bulge.
func los(a: Vector2, a_alt: float, b: Vector2, b_alt: float, earth_r := 8.5e6) -> bool:
	var d := a.distance_to(b)
	var steps := int(d / 250.0)
	for s in range(1, steps):
		var f := float(s) / steps
		var bulge := f * (1.0 - f) * d * d / (2.0 * earth_r)
		if elev_at(a.lerp(b, f)) + bulge > lerpf(a_alt, b_alt, f):
			return false
	return true


## Hypsometric tint + 100 m contours (500 m index contours darker).
func topo_image() -> Image:
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var i := y * N + x
			var e := heights[i]
			var c := Color(0.08, 0.2, 0.35)
			if biomes[i] != Biome.SEA:
				var f := e / max_elev
				c = Color(0.35, 0.55, 0.3).lerp(Color(0.6, 0.5, 0.3), clampf(f * 2.0, 0.0, 1.0))
				c = c.lerp(Color(0.95, 0.95, 0.95), clampf(f * 2.0 - 1.0, 0.0, 1.0))
				if biomes[i] == Biome.FOREST:
					c = c.darkened(0.2)
				if x + 1 < N and y + 1 < N:
					var e2 := heights[i + 1]
					var e3 := heights[i + N]
					if int(e / 500.0) != int(e2 / 500.0) or int(e / 500.0) != int(e3 / 500.0):
						c = c.darkened(0.7)
					elif int(e / 100.0) != int(e2 / 100.0) or int(e / 100.0) != int(e3 / 100.0):
						c = c.darkened(0.4)
			img.set_pixel(x, y, c)
	return img
