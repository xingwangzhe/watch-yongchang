shader_type canvas_item;

void vertex() {
	vec4 cell = INSTANCE_CUSTOM;
	if (cell.z > 0.0 && cell.w > 0.0) {
		UV = cell.xy + UV * cell.zw;
	}
}

void fragment() {
	COLOR *= texture(TEXTURE, UV);
}
