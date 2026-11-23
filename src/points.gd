@tool
extends RefCounted
## World points for brush commands: "x,z" or "x,y,z" tokens (args or stdin lines, space or
## newline separated), or a Path3D's curve. y is NAN when not given (brush.gd fills in the ground).


## Parses tokens into points; bad tokens go to errors.
static func parse_tokens(tokens: Array, errors: PackedStringArray) -> PackedVector3Array:
	var out := PackedVector3Array()
	for tok in tokens:
		var s := str(tok).strip_edges()
		if s == "":
			continue
		var p := s.split(",")
		var ok := p.size() == 2 or p.size() == 3
		for c in p:
			ok = ok and c.strip_edges().is_valid_float()
		if not ok:
			errors.append("bad point '%s' (want x,z or x,y,z)" % s)
			continue
		if p.size() == 2:
			out.append(Vector3(float(p[0]), NAN, float(p[1])))
		else:
			out.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	return out


## Whitespace/newline separated tokens of text.
static func tokens_of(text: String) -> Array:
	var out := []
	for line in text.split("\n", false):
		for t in line.strip_edges().split(" ", false):
			out.append(t)
	return out


## A Path3D's curve in world space, sampled every `step` m (0: the curve's baked points).
static func from_path(node: Node, step := 0.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not node is Path3D or (node as Path3D).curve == null:
		return out
	var path := node as Path3D
	var curve := path.curve
	var xf := path.global_transform
	if step <= 0.0:
		for p in curve.get_baked_points():
			out.append(xf * p)
		return out
	var length := curve.get_baked_length()
	var n := maxi(int(ceil(length / step)), 1)
	for i in n + 1:
		out.append(xf * curve.sample_baked(length * i / n))
	return out


## Points from (in order of preference) --path node, positional args, stdin. Returns the points;
## errors collects problems. NP is gdsh_lib/level's node_paths.gd.
static func gather(args: Array, stdin: String, path_flag: String, NP, errors: PackedStringArray, path_step := 0.0) -> PackedVector3Array:
	if path_flag != "":
		var n = NP.resolve(path_flag)
		if not n is Path3D:
			errors.append("--path: not a Path3D with a curve: " + path_flag)
			return PackedVector3Array()
		return from_path(n, path_step)
	if not args.is_empty():
		return parse_tokens(args, errors)
	return parse_tokens(tokens_of(stdin), errors)
