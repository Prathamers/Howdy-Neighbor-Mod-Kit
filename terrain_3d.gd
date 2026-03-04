extends Node3D

# Manual settings in case the inspector is buggy
@export var force_enabled: bool = true
@export var force_mode: int = 3 # 3 is "Full / Editor" for maximum collision

func _ready() -> void:
	# Wait 2 frames to ensure the GDExtension is fully registered in the engine
	await get_tree().process_frame
	await get_tree().process_frame
	force_collision_update()

func force_collision_update():
	print("Force-starting collision on node: ", self.name)
	
	# We use set() directly. If the property exists in the C++ code, 
	# it will work even if GDScript doesn't 'see' it yet.
	self.set("collision_enabled", force_enabled)
	self.set("collision_mode", force_mode)
	
	# If you are using a Player, let's try to find them automatically
	var camera = get_viewport().get_camera_3d()
	if camera:
		self.set("collision_target", camera)
		print("Target found and set to camera.")
	
	# This part is critical for 4.6
	# It tells the plugin to rebuild the physics body immediately
	if self.has_method("build_collision"):
		self.call("build_collision")
		print("Manual build_collision called.")
