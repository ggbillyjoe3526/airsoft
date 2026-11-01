class_name CodeShaders
extends RefCounted
## Shaders written as code in a script (a night sky, dust, light pools, torch beams, the woods' tufts and air), each
## made once for the whole run and shared by every match (BP2): a fresh Shader per match had the renderer compile the
## same code again on every loading screen. A Shader holds no per-match state; each match makes its own materials.

static var _made: Dictionary[String, Shader] = {}


## The one Shader with `code`, made the first time it is asked for.
static func of(code: String) -> Shader:
	var shader: Shader = _made.get(code)
	if shader == null:
		shader = Shader.new()
		shader.code = code
		_made[code] = shader
	return shader
