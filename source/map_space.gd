extends RefCounted

# Campus interior 320 m x 360 m. Control points also align the track and pitch.
const PIXELS_PER_METER := 24.0
const SOURCE_X := [35.0, 88.0, 146.0, 391.0, 447.0, 1067.0]
const METERS_X := [0.0, 18.0, 33.0, 153.0, 168.0, 320.0]
const SOURCE_Y := [25.0, 223.0, 355.0, 805.0, 957.0, 1401.0]
const METERS_Y := [0.0, 45.0, 80.0, 260.0, 295.0, 360.0]

static func interpolate(value: float, source: Array, target: Array) -> float:
	var segment := source.size() - 2
	for index: int in range(source.size() - 1):
		if value <= float(source[index + 1]):
			segment = index
			break
	return lerpf(float(target[segment]), float(target[segment + 1]), (value - float(source[segment])) / (float(source[segment + 1]) - float(source[segment])))

static func project(at: Vector2) -> Vector2:
	return Vector2(interpolate(at.x, SOURCE_X, METERS_X), interpolate(at.y, SOURCE_Y, METERS_Y)) * PIXELS_PER_METER

static func unproject(at: Vector2) -> Vector2:
	var meters := at / PIXELS_PER_METER
	return Vector2(interpolate(meters.x, METERS_X, SOURCE_X), interpolate(meters.y, METERS_Y, SOURCE_Y))

static func box_to_world(box: Rect2) -> Rect2:
	return Rect2(project(box.position), project(box.end) - project(box.position))

static func region_at(at: Vector2) -> Vector2i:
	var meters := at / PIXELS_PER_METER
	return Vector2i(clampi(int(floor(meters.x / 80.0)), 0, 3), clampi(int(floor(meters.y / 90.0)), 0, 3))
